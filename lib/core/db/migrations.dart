import 'package:sqflite/sqflite.dart';

/// One schema step. [version] N upgrades a database from N-1 to N.
class Migration {
  /// Creates a migration.
  const Migration(this.version, this.description, this.statements);

  /// Target schema version after this step.
  final int version;

  /// Human-readable summary, for logs and review.
  final String description;

  /// SQL statements, executed in order inside the open/upgrade transaction.
  final List<String> statements;
}

/// Versioned schema migrations.
///
/// Rules:
/// - **Never edit a migration that has shipped.** Append a new one instead.
/// - Versions must be contiguous, starting at 1.
/// - Timestamps are INTEGER milliseconds since epoch (UTC).
/// - JSON is stored as TEXT.
abstract final class Migrations {
  /// All migrations, oldest first.
  static const List<Migration> all = [_v1, _v2, _v3];

  /// Schema version of a fully migrated database.
  static int get latestVersion => all.last.version;

  /// Applies every migration with `from < version <= to`.
  static Future<void> migrate(DatabaseExecutor db, int from, int to) async {
    for (final m in all) {
      if (m.version > from && m.version <= to) {
        for (final sql in m.statements) {
          await db.execute(sql);
        }
      }
    }
  }
}

const Migration _v1 = Migration(1, 'Initial schema', [
  // Local accounts. PIN/password is stored only as a salted hash.
  '''
  CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    display_name  TEXT NOT NULL,
    email         TEXT,
    secret_hash   TEXT NOT NULL,
    secret_salt   TEXT NOT NULL,
    remote_id     TEXT,
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL,
    last_login_at INTEGER
  )
  ''',

  // Key/value preferences. user_id is a users.id, or 'device' for settings
  // chosen before any account exists (e.g. navigation mode on Welcome).
  // Values are JSON-encoded so new settings never need a migration.
  '''
  CREATE TABLE preferences (
    user_id    TEXT NOT NULL,
    key        TEXT NOT NULL,
    value      TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, key)
  )
  ''',

  // Reading history.
  '''
  CREATE TABLE documents (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        TEXT REFERENCES users(id) ON DELETE CASCADE,
    title          TEXT NOT NULL,
    full_text      TEXT NOT NULL,
    source_type    TEXT NOT NULL
                   CHECK (source_type IN ('camera', 'image', 'pdf', 'docx')),
    language       TEXT NOT NULL DEFAULT 'fil',
    created_at     INTEGER NOT NULL,
    updated_at     INTEGER NOT NULL,
    last_opened_at INTEGER,
    last_position  INTEGER NOT NULL DEFAULT 0
  )
  ''',
  'CREATE INDEX idx_documents_user_created ON documents (user_id, created_at DESC)',

  // Anonymized usage events: no user id, only a random per-install/session id.
  '''
  CREATE TABLE usage_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id  TEXT NOT NULL,
    event_type  TEXT NOT NULL,
    screen      TEXT,
    input_mode  TEXT
                CHECK (input_mode IS NULL OR
                       input_mode IN ('gesture', 'voice', 'touch', 'talkback')),
    payload     TEXT,
    created_at  INTEGER NOT NULL,
    uploaded_at INTEGER
  )
  ''',
  'CREATE INDEX idx_usage_logs_uploaded ON usage_logs (uploaded_at)',

  // Offline queue for everything that goes to the web admin app.
  '''
  CREATE TABLE outbox (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    type            TEXT NOT NULL
                    CHECK (type IN ('report', 'feedback', 'sus',
                                    'usage_logs', 'account_sync')),
    payload         TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'sending', 'sent', 'failed')),
    attempts        INTEGER NOT NULL DEFAULT 0,
    last_error      TEXT,
    next_attempt_at INTEGER,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_outbox_due ON outbox (status, next_attempt_at)',

  // System Usability Scale results. answers = JSON array of ten 1..5 ints.
  '''
  CREATE TABLE sus_responses (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
    answers    TEXT NOT NULL,
    score      REAL NOT NULL CHECK (score BETWEEN 0 AND 100),
    language   TEXT NOT NULL,
    input_mode TEXT,
    created_at INTEGER NOT NULL
  )
  ''',

  // Word Error Rate evaluation runs.
  '''
  CREATE TABLE wer_results (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT NOT NULL,
    locale          TEXT NOT NULL,
    on_device       INTEGER NOT NULL CHECK (on_device IN (0, 1)),
    reference       TEXT NOT NULL,
    hypothesis      TEXT NOT NULL,
    substitutions   INTEGER NOT NULL,
    deletions       INTEGER NOT NULL,
    insertions      INTEGER NOT NULL,
    reference_words INTEGER NOT NULL,
    wer             REAL NOT NULL,
    created_at      INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_wer_results_session ON wer_results (session_id)',
]);

const Migration _v2 = Migration(2, 'Email + password accounts (Phase 6B)', [
  // Names, profile flags and sync bookkeeping. `secret_hash`/`secret_salt`
  // now hold the password hash; `secret_kind` says how it was made:
  // 'pin' (legacy 4-digit PIN, SHA-256 x 10 000), 'pbkdf2-sha256:<n>'
  // (password, PBKDF2 with n iterations) or 'none' (guest).
  'ALTER TABLE users ADD COLUMN first_name TEXT',
  'ALTER TABLE users ADD COLUMN last_name TEXT',
  "ALTER TABLE users ADD COLUMN secret_kind TEXT NOT NULL DEFAULT 'pin'",
  // Security question id + hashed, normalized answer (forgot password).
  'ALTER TABLE users ADD COLUMN security_question TEXT',
  'ALTER TABLE users ADD COLUMN security_answer_hash TEXT',
  'ALTER TABLE users ADD COLUMN security_answer_salt TEXT',
  'ALTER TABLE users ADD COLUMN is_guest INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE users ADD COLUMN profiling_completed INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE users ADD COLUMN fingerprint_enabled INTEGER NOT NULL DEFAULT 0',
  // Web app sync (Phase 7): synced = 1 once the server has this version.
  'ALTER TABLE users ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE users ADD COLUMN server_id TEXT',
  'UPDATE users SET first_name = display_name, server_id = remote_id',
  // Legacy PIN accounts set a (verified-unique) email when they upgrade.
  "UPDATE users SET email = NULL WHERE secret_kind = 'pin'",
  // The email is the username: unique, case-insensitive.
  'CREATE UNIQUE INDEX idx_users_email ON users (email COLLATE NOCASE) '
      'WHERE email IS NOT NULL',

  // Failed logins per email (lockout survives restarts). `key` is the
  // lowercased email, prefixed with the kind of check ('login:', 'reset:').
  '''
  CREATE TABLE login_attempts (
    key          TEXT PRIMARY KEY,
    failures     INTEGER NOT NULL DEFAULT 0,
    locked_until INTEGER,
    updated_at   INTEGER NOT NULL
  )
  ''',

  // Reading history becomes per user: documents read so far belong to the
  // profile that was logged in (if any).
  '''
  UPDATE documents SET user_id = (
    SELECT u.id FROM preferences p JOIN users u ON u.id = trim(p.value, '"')
    WHERE p.user_id = 'device' AND p.key = 'account.currentUser'
  ) WHERE user_id IS NULL
  ''',
]);

const Migration _v3 = Migration(3, 'Image descriptions in history (Phase 6C)', [
  // SQLite can't change a CHECK in place: rebuild `documents` with
  // 'description' as a source type, plus the thumbnail of a described image.
  '''
  CREATE TABLE documents_v3 (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        TEXT REFERENCES users(id) ON DELETE CASCADE,
    title          TEXT NOT NULL,
    full_text      TEXT NOT NULL,
    source_type    TEXT NOT NULL
                   CHECK (source_type IN
                          ('camera', 'image', 'pdf', 'docx', 'description')),
    language       TEXT NOT NULL DEFAULT 'fil',
    created_at     INTEGER NOT NULL,
    updated_at     INTEGER NOT NULL,
    last_opened_at INTEGER,
    last_position  INTEGER NOT NULL DEFAULT 0,
    thumbnail_path TEXT
  )
  ''',
  '''
  INSERT INTO documents_v3 (id, user_id, title, full_text, source_type,
    language, created_at, updated_at, last_opened_at, last_position)
  SELECT id, user_id, title, full_text, source_type, language, created_at,
    updated_at, last_opened_at, last_position FROM documents
  ''',
  'DROP TABLE documents',
  'ALTER TABLE documents_v3 RENAME TO documents',
  'CREATE INDEX idx_documents_user_created ON documents (user_id, created_at DESC)',
]);
