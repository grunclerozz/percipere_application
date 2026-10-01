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
  static const List<Migration> all = [_v1];

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
