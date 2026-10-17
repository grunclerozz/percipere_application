# Percipere - Database Masterlist

_Generated 2026-10-13 by read-only analysis. Nothing in source, migrations or databases was modified._

## 0. Sources, scope and baselines

| System | Engine | Baseline used | Source |
|---|---|---|---|
| Android app (`percipere_app`) | SQLite via `sqflite`, file `percipere.db`, schema **v7** | migrations v1-v7 | `lib/core/db/migrations.dart` (+ `app_database.dart`, DAOs in `lib/core/db/daos/`) |
| Web dashboard + REST API (`percipere_web/percipere_dashboard`, PHP) | MariaDB 10.4.32 (XAMPP), DB `percipere_dashboard`, `schema_version` = **12** | **LIVE DB** (read with SHOW/SELECT on information_schema only) | live DB; cross-checked against `database.sql` + `docs/migrations/*` on branch `origin/fix/webapp-api` |

- Web and Android do **not** share a database. Android keeps its own SQLite; it talks to the server only through `/api/v1` (accounts, reports, book catalog). Server and Android keys are of different types (INT vs TEXT UUID).
- Excluded: `percipere_app/percipere/` (stale nested project), `assistant/` (no database). `main` / `claude/intelligent-bardeen-062ngh` on the web repo were ignored.
- `ui/rounded-no-shadow` was checked: it does not touch `database.sql`, `schema.php` or `docs/migrations`.
- (inferred) = deduced from code/comments/naming, not an explicit definition. Server data rows were **not** read (structure only).

## 1. Summary of all tables

**27 tables** (13 server, 14 Android) - **19 foreign keys defined** (10 server live + 9 Android), plus 5 server relationships with no FK.

| # | Table | Module | Location | Cols | PK | Related tables | Counterpart on other side |
|---|---|---|---|---|---|---|---|
| 1 | `members` | Team & Staff | Server DB | 13 | member_id | admins, audit_log, feedback, feedback_notes | none |
| 2 | `roles` | Team & Staff | Server DB | 3 | role_id | admins* | none |
| 3 | `admins` | Team & Staff | Server DB | 14 | admin_id | app_settings*, audit_log*, books, feedback*, feedback_notes*, members, roles* | none |
| 4 | `app_users` | App Users & Auth | Server DB | 14 | user_id | app_tokens, feedback | users |
| 5 | `app_tokens` | App Users & Auth | Server DB | 7 | token_id | app_users | none |
| 6 | `api_limits` | App Users & Auth | Server DB | 4 | limit_key | - | login_attempts (inferred) |
| 7 | `feedback` | Feedback & Reports | Server DB | 27 | feedback_id | admins*, app_users, feedback_notes, members | issue_reports |
| 8 | `feedback_notes` | Feedback & Reports | Server DB | 7 | note_id | admins*, feedback, members | none |
| 9 | `audit_log` | Audit & Settings | Server DB | 5 | log_id | admins*, members | none |
| 10 | `app_settings` | Audit & Settings | Server DB | 4 | setting_key | admins* | none |
| 11 | `categories` | Library Catalog | Server DB | 5 | category_id | books | none |
| 12 | `languages` | Library Catalog | Server DB | 6 | language_id | books | none |
| 13 | `books` | Library Catalog | Server DB | 18 | book_id | admins, categories, languages | library_items (source='book') |
| 14 | `users` | Users & Auth | Android local DB | 20 | id | documents_legacy, issue_reports, library_collections, library_items, percy_turns, sus_responses | app_users (partly; account created via POST /auth/register) |
| 15 | `preferences` | Settings | Android local DB | 4 | user_id, key | - | none |
| 16 | `documents_legacy` (deprecated) | Library (legacy) | Android local DB | 11 | id | users | none |
| 17 | `usage_logs` (deprecated) | Telemetry & Evaluation | Android local DB | 8 | id | - | none yet (server has no usage table; outbox type 'usage_logs' planned) |
| 18 | `outbox` (deprecated) | Sync | Android local DB | 9 | id | - | none |
| 19 | `sus_responses` | Telemetry & Evaluation | Android local DB | 7 | id | users | none (server has no SUS table) |
| 20 | `wer_results` | Telemetry & Evaluation | Android local DB | 12 | id | - | none |
| 21 | `login_attempts` | Users & Auth | Android local DB | 4 | key | - | api_limits (different mechanism; inferred) |
| 22 | `library_items` | Library | Android local DB | 35 | id | library_collection_items, library_favorites, users | books (rows with source='book' only, inferred); user documents have no server table |
| 23 | `library_favorites` | Library | Android local DB | 8 | id | library_items | none (planned sync, no server table) |
| 24 | `library_collections` | Library | Android local DB | 6 | id | library_collection_items, users | none (planned sync, no server table) |
| 25 | `library_collection_items` | Library | Android local DB | 4 | collection_id, item_id | library_collections, library_items | none |
| 26 | `percy_turns` | Percy (voice assistant) | Android local DB | 9 | id | users | none |
| 27 | `issue_reports` | Reports | Android local DB | 18 | id | users | feedback (sent via POST /api/v1/reports; status via GET /reports/{ticket_no}) |

`*` = relationship exists in the data but has no FK constraint in the live DB.

## 2. Server database (MariaDB `percipere_dashboard`) - data dictionary

Charset utf8mb4 / utf8mb4_unicode_ci, InnoDB. All FK update rules are RESTRICT (default). Row counts at analysis time: admins 4, members 4, roles 3, languages 2, audit_log 2, all others 0 (no books, app users or feedback yet).

### `members`

- **Module:** Team & Staff
- **Purpose:** Team members (the 4 project members) shown in Settings -> Team; target of audit/feedback attribution.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 16 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** member_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `member_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `member_name` | varchar | 150 | N |  | N | N |  |  |
| `member_role` | varchar | 150 | N |  | N | N |  |  |
| `member_school` | varchar | 200 | N | `''` | N | N |  | school / course, edited in Settings -> Team |
| `member_email` | varchar | 191 | N |  | Y | N | UK |  |
| `member_bio` | varchar | 400 | N | `''` | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_photo` | varchar | 255 | N | `''` | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_age` | varchar | 20 | N | `''` | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_sex` | varchar | 50 | N | `''` | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_address` | varchar | 255 | N | `''` | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_experiences` | text |  | Y |  | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_contribution` | text |  | Y |  | N | N |  | Legacy personal column; NOT in database.sql v12 - to be dropped by v12_remove_personal_columns.sql |
| `member_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |

**Foreign keys:** none

**Indexes:** `UNIQUE email (member_email)`; `UNIQUE PRIMARY (member_id)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** member_created_at; **soft delete:** none

**Relationships:**
- members 1:N admins via `admins.admin_member_id` (child optional)
- members 1:N feedback via `feedback.feedback_member_id` (child optional)
- members 1:N feedback_notes via `feedback_notes.note_member_id` (child optional)
- members 1:N audit_log via `audit_log.log_member_id` (child optional)

---

### `roles`

- **Module:** Team & Staff
- **Purpose:** Dashboard staff roles: super_admin, support_staff, analyst.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 42 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** role_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `role_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `role_name` | varchar | 50 | N |  | Y | N | UK |  |
| `role_description` | varchar | 255 | Y |  | N | N |  |  |

**Foreign keys:** none

**Indexes:** `UNIQUE PRIMARY (role_id)`; `UNIQUE role_name (role_name)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** none; **soft delete:** none

**Relationships:**
- roles 1:N admins via `admins.admin_role_id` (optional) - **no FK**

---

### `admins`

- **Module:** Team & Staff
- **Purpose:** Staff accounts that can log into the dashboard (separate from app users).
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 58 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** admin_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `admin_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `admin_email` | varchar | 191 | N |  | Y | N | UK |  |
| `admin_full_name` | varchar | 150 | N | `''` | N | N |  |  |
| `admin_password_hash` | varchar | 255 | N |  | N | N |  |  |
| `admin_member_id` | int unsigned |  | Y |  | N | N | FK | -> members.member_id |
| `admin_role_id` | int unsigned |  | Y |  | N | N |  | -> roles.role_id |
| `admin_status` | enum('active','suspended') |  | N | `'active'` | N | N |  |  |
| `admin_failed_login_attempts` | int |  | N | `0` | N | N |  |  |
| `admin_locked_until` | datetime |  | Y |  | N | N |  |  |
| `admin_last_login_at` | datetime |  | Y |  | N | N |  | Last successful login |
| `admin_preferences` | text |  | Y |  | N | N |  | Settings -> Preferences (JSON) |
| `admin_session_version` | int unsigned |  | N | `1` | N | N |  | bumped by "Sign out other devices" |
| `admin_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `admin_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** `admin_member_id` -> `members.member_id` (ON DELETE SET NULL, ON UPDATE RESTRICT)
- **Missing FK:** `admin_role_id` -> `roles.role_id` - comment only in every schema file; no FK anywhere

**Indexes:** `UNIQUE email (admin_email)`; `fk_admins_member (admin_member_id)`; `UNIQUE PRIMARY (admin_id)`

**Check constraints:** none (ENUM columns act as checks)

**Enum / lookup values:** `admin_status`: active | suspended

**Audit columns:** admin_last_login_at, admin_created_at, admin_updated_at; **soft delete:** admin_status = suspended

**Relationships:**
- members 1:N admins via `admin_member_id` (optional)
- admins 1:N books via `books.book_admin_id` (child optional)
- admins 1:N feedback via `feedback.feedback_admin_id` (optional) - **no FK**
- admins 1:N feedback_notes via `feedback_notes.note_admin_id` (optional) - **no FK**
- admins 1:N audit_log via `audit_log.log_admin_id` (optional) - **no FK**
- roles 1:N admins via `admin_role_id` (optional) - **no FK**
- admins 1:N app_settings via `app_settings.setting_admin_id` (optional) - **no FK**

---

### `app_users`

- **Module:** App Users & Auth
- **Purpose:** End users of the Android app (registered through POST /api/v1/auth/register, emailed one-time code).
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 117 on `origin/fix/webapp-api`
- **Counterpart:** users
- **Primary key:** user_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `user_id` | int unsigned |  | N |  | N | Y | PK |  |
| `user_full_name` | varchar | 100 | N |  | N | N |  |  |
| `user_email` | varchar | 150 | N |  | Y | N | UK |  |
| `user_phone_number` | varchar | 20 | Y |  | N | N |  |  |
| `user_password_hash` | varchar | 255 | N |  | N | N |  |  |
| `user_status` | enum('pending_verification','pending_approval','active','suspended') |  | N | `'active'` | N | N |  |  |
| `user_email_verified_at` | datetime |  | Y |  | N | N |  |  |
| `user_otp_hash` | varchar | 255 | Y |  | N | N |  |  |
| `user_otp_expires_at` | datetime |  | Y |  | N | N |  |  |
| `user_otp_sent_at` | datetime |  | Y |  | N | N |  |  |
| `user_position` | varchar | 100 | Y |  | N | N |  |  |
| `user_phone_verified_at` | datetime |  | Y |  | N | N |  |  |
| `user_created_at` | datetime |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `user_last_login_at` | datetime |  | Y |  | N | N |  | Last successful login |

**Foreign keys:** none

**Indexes:** `UNIQUE PRIMARY (user_id)`; `UNIQUE user_email (user_email)`

**Check constraints:** none (ENUM columns act as checks)

**Enum / lookup values:** `user_status`: pending_verification | pending_approval | active | suspended

**Audit columns:** user_created_at, user_last_login_at; **soft delete:** user_status = suspended

**Relationships:**
- app_users 1:N app_tokens via `app_tokens.token_user_id` (child mandatory)
- app_users 1:N feedback via `feedback.feedback_user_id` (child optional)

---

### `app_tokens`

- **Module:** App Users & Auth
- **Purpose:** Bearer sign-in tokens for the app API; only SHA-256 of each token stored; one row per device.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 139 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** token_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `token_id` | int unsigned |  | N |  | N | Y | PK |  |
| `token_user_id` | int unsigned |  | N |  | N | N | FK | -> app_users.user_id |
| `token_hash` | char | 64 | N |  | Y | N | UK |  |
| `token_device` | varchar | 100 | N | `''` | N | N |  |  |
| `token_created_at` | datetime |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `token_last_used_at` | datetime |  | N | `current_timestamp()` | N | N |  |  |
| `token_expires_at` | datetime |  | N |  | N | N |  | 30 days after last use |

**Foreign keys:** `token_user_id` -> `app_users.user_id` (ON DELETE CASCADE, ON UPDATE RESTRICT)

**Indexes:** `idx_app_tokens_user (token_user_id)`; `UNIQUE PRIMARY (token_id)`; `UNIQUE token_hash (token_hash)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** token_created_at; **soft delete:** none

**Relationships:**
- app_users 1:N app_tokens via `token_user_id` (mandatory)

---

### `api_limits`

- **Module:** App Users & Auth
- **Purpose:** Rate-limit and lockout counters for the app API; key = SHA-256 of e.g. 'login:ip:1.2.3.4'.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 158 on `origin/fix/webapp-api`
- **Counterpart:** login_attempts (inferred)
- **Primary key:** limit_key

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `limit_key` | char | 64 | N |  | N | N | PK |  |
| `limit_count` | int unsigned |  | N | `0` | N | N |  |  |
| `limit_window_start` | datetime |  | N |  | N | N |  |  |
| `limit_locked_until` | datetime |  | Y |  | N | N |  |  |

**Foreign keys:** none

**Indexes:** `UNIQUE PRIMARY (limit_key)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** none; **soft delete:** none

**Relationships:**
- none

---

### `feedback`

- **Module:** Feedback & Reports
- **Purpose:** Concerns and bug reports from the app's 'Report an issue' (+ seed rows); the dashboard's Feedback & Bugs page.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 169 on `origin/fix/webapp-api`
- **Counterpart:** issue_reports
- **Primary key:** feedback_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `feedback_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `feedback_category` | varchar | 60 | N | `'General Feedback'` | N | N |  | the report's type, as the app labelled it |
| `feedback_type_code` | varchar | 40 | Y |  | N | N |  | the app's code for it (bug, feature, feedback, ...) |
| `feedback_module` | varchar | 60 | N |  | N | N |  | as the app labelled it: the dashboard filters come from these |
| `feedback_module_code` | varchar | 40 | Y |  | N | N |  |  |
| `feedback_severity` | varchar | 40 | N | `''` | N | N |  | '' when the app sent none (not a bug) |
| `feedback_severity_code` | varchar | 40 | Y |  | N | N |  |  |
| `feedback_description` | text |  | N |  | N | N |  |  |
| `feedback_email` | varchar | 191 | N | `''` | N | N |  |  |
| `feedback_user_id` | int unsigned |  | Y |  | N | N | FK | -> app_users.user_id (signed-in app user who sent it) |
| `feedback_app_version` | varchar | 20 | N | `''` | N | N |  |  |
| `feedback_device` | varchar | 100 | N | `''` | N | N |  |  |
| `feedback_os_version` | varchar | 40 | N | `''` | N | N |  |  |
| `feedback_ticket_no` | varchar | 20 | Y |  | Y | N | UK | PRC-YYYYMMDD-XXXX from the app's "Report an issue" |
| `feedback_source_screen` | varchar | 50 | N | `''` | N | N |  | app screen the report was opened from |
| `feedback_reporter_kind` | enum('account','guest') |  | Y |  | N | N |  |  |
| `feedback_reporter_name` | varchar | 100 | Y |  | N | N |  | display name the app sent (null for guests) |
| `feedback_app_created_at` | datetime |  | Y |  | N | N |  | when the app wrote it (it may arrive later, offline) |
| `feedback_status` | enum('Open','In Progress','Resolved') |  | N | `'Open'` | N | N |  |  |
| `feedback_source` | enum('app','seed') |  | N | `'app'` | N | N |  |  |
| `feedback_submitted_at` | date |  | N |  | N | N |  |  |
| `feedback_resolved_at` | date |  | Y |  | N | N |  |  |
| `feedback_archived_at` | datetime |  | Y |  | N | N |  |  |
| `feedback_member_id` | int unsigned |  | Y |  | N | N | FK | -> members.member_id (team member who last changed it) |
| `feedback_admin_id` | int unsigned |  | Y |  | N | N |  | -> admins.admin_id (staff account who last changed it) |
| `feedback_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | when the server received it |
| `feedback_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** `feedback_member_id` -> `members.member_id` (ON DELETE SET NULL, ON UPDATE RESTRICT); `feedback_user_id` -> `app_users.user_id` (ON DELETE SET NULL, ON UPDATE RESTRICT)
- **Missing FK:** `feedback_admin_id` -> `admins.admin_id` - in database.sql v12; NOT in live DB (v3_admin_fks.sql not applied)

**Indexes:** `fk_feedback_member (feedback_member_id)`; `fk_feedback_user (feedback_user_id)`; `idx_feedback_archived_at (feedback_archived_at)`; `UNIQUE PRIMARY (feedback_id)`; `UNIQUE uq_feedback_ticket_no (feedback_ticket_no)`

**Check constraints:** none (ENUM columns act as checks)

**Enum / lookup values:** `feedback_reporter_kind`: account | guest; `feedback_status`: Open | In Progress | Resolved; `feedback_source`: app | seed

**Audit columns:** feedback_app_created_at, feedback_archived_at, feedback_admin_id, feedback_created_at, feedback_updated_at; **soft delete:** feedback_archived_at (archived = 'closed')

**Relationships:**
- members 1:N feedback via `feedback_member_id` (optional)
- app_users 1:N feedback via `feedback_user_id` (optional)
- feedback 1:N feedback_notes via `feedback_notes.note_feedback_id` (child mandatory)
- admins 1:N feedback via `feedback_admin_id` (optional) - **no FK**

---

### `feedback_notes`

- **Module:** Feedback & Reports
- **Purpose:** Internal staff notes on a feedback item.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 213 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** note_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `note_id` | int unsigned |  | N |  | N | Y | PK |  |
| `note_feedback_id` | int unsigned |  | N |  | N | N | FK | -> feedback.feedback_id |
| `note_member_id` | int unsigned |  | Y |  | N | N | FK | -> members.member_id |
| `note_admin_id` | int unsigned |  | Y |  | N | N |  | -> admins.admin_id |
| `note_text` | text |  | N |  | N | N |  |  |
| `note_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `note_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** `note_feedback_id` -> `feedback.feedback_id` (ON DELETE CASCADE, ON UPDATE RESTRICT); `note_member_id` -> `members.member_id` (ON DELETE CASCADE, ON UPDATE RESTRICT)
- **Missing FK:** `note_admin_id` -> `admins.admin_id` - in database.sql v12; NOT in live DB (v3_admin_fks.sql not applied)

**Indexes:** `fk_feedback_notes_feedback (note_feedback_id)`; `fk_feedback_notes_member (note_member_id)`; `UNIQUE PRIMARY (note_id)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** note_admin_id, note_created_at, note_updated_at; **soft delete:** none

**Relationships:**
- feedback 1:N feedback_notes via `note_feedback_id` (mandatory)
- members 1:N feedback_notes via `note_member_id` (optional)
- admins 1:N feedback_notes via `note_admin_id` (optional) - **no FK**

---

### `audit_log`

- **Module:** Audit & Settings
- **Purpose:** Every change made in the dashboard (Reports -> Audit Log).
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 232 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** log_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `log_id` | int unsigned |  | N |  | N | Y | PK |  |
| `log_member_id` | int unsigned |  | Y |  | N | N | FK | -> members.member_id |
| `log_admin_id` | int unsigned |  | Y |  | N | N |  | -> admins.admin_id |
| `log_action` | varchar | 255 | N |  | N | N |  |  |
| `log_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |

**Foreign keys:** `log_member_id` -> `members.member_id` (ON DELETE CASCADE, ON UPDATE RESTRICT)
- **Missing FK:** `log_admin_id` -> `admins.admin_id` - in database.sql v12; NOT in live DB (v3_admin_fks.sql not applied)

**Indexes:** `fk_audit_member (log_member_id)`; `UNIQUE PRIMARY (log_id)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** log_admin_id, log_created_at; **soft delete:** none

**Relationships:**
- members 1:N audit_log via `log_member_id` (optional)
- admins 1:N audit_log via `log_admin_id` (optional) - **no FK**

---

### `app_settings`

- **Module:** Audit & Settings
- **Purpose:** System-wide key/value rules (Settings -> System); also stores schema_version.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 251 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** setting_key

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `setting_key` | varchar | 64 | N |  | N | N | PK |  |
| `setting_value` | varchar | 255 | N |  | N | N |  |  |
| `setting_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |
| `setting_admin_id` | int unsigned |  | Y |  | N | N |  | -> admins.admin_id: who last changed it (kept by the code, no FK constraint) |

**Foreign keys:** none
- **Missing FK:** `setting_admin_id` -> `admins.admin_id` - by design 'kept by the code, no FK constraint'

**Indexes:** `UNIQUE PRIMARY (setting_key)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** setting_updated_at, setting_admin_id; **soft delete:** none

**Relationships:**
- admins 1:N app_settings via `setting_admin_id` (optional) - **no FK**

---

### `categories`

- **Module:** Library Catalog
- **Purpose:** Library categories managed by admins.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 264 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** category_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `category_id` | int unsigned |  | N |  | N | Y | PK |  |
| `category_name` | varchar | 80 | N |  | Y | N | UK |  |
| `category_is_active` | tinyint |  | N | `1` | N | N |  |  |
| `category_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `category_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** none

**Indexes:** `UNIQUE PRIMARY (category_id)`; `UNIQUE uq_categories_name (category_name)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** category_created_at, category_updated_at; **soft delete:** category_is_active

**Relationships:**
- categories 1:N books via `books.book_category_id` (child mandatory)

---

### `languages`

- **Module:** Library Catalog
- **Purpose:** Book languages (fil, en); language_code lets the app pick the reading voice.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 273 on `origin/fix/webapp-api`
- **Counterpart:** none
- **Primary key:** language_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `language_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `language_name` | varchar | 40 | N |  | Y | N | UK |  |
| `language_code` | varchar | 10 | Y |  | N | N |  | e.g. fil, en: lets the app pick the reading voice |
| `language_is_active` | tinyint |  | N | `1` | N | N |  |  |
| `language_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `language_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** none

**Indexes:** `UNIQUE PRIMARY (language_id)`; `UNIQUE uq_languages_name (language_name)`

**Check constraints:** none (ENUM columns act as checks)

**Audit columns:** language_created_at, language_updated_at; **soft delete:** language_is_active

**Relationships:**
- languages 1:N books via `books.book_language_id` (child mandatory)

---

### `books`

- **Module:** Library Catalog
- **Purpose:** Admin-managed library catalog; files in storage/books and storage/covers; is_active=0 hides a book from the app.
- **Location:** Server DB
- **Source:** live DB (`information_schema`); `database.sql` line 283 on `origin/fix/webapp-api`
- **Counterpart:** library_items (source='book')
- **Primary key:** book_id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `book_id` | int unsigned |  | N |  | N | Y | PK | Primary key |
| `book_title` | varchar | 200 | N |  | N | N |  |  |
| `book_author` | varchar | 150 | N | `''` | N | N |  |  |
| `book_description` | text |  | Y |  | N | N |  |  |
| `book_category_id` | int unsigned |  | N |  | N | N | FK | -> categories.category_id |
| `book_language_id` | int unsigned |  | N |  | N | N | FK | -> languages.language_id |
| `book_format` | enum('pdf','epub') |  | N |  | N | N |  |  |
| `book_file_path` | varchar | 80 | N |  | N | N |  | random name inside storage/books/ |
| `book_file_name` | varchar | 255 | N |  | N | N |  | the name it was uploaded with, for display |
| `book_file_size` | int unsigned |  | N |  | N | N |  |  |
| `book_file_hash` | char | 64 | N |  | N | N |  | SHA-256 of the file: lets the app check its copy |
| `book_cover_path` | varchar | 80 | Y |  | N | N |  | random name inside storage/covers/ |
| `book_cover_mime` | varchar | 20 | Y |  | N | N |  |  |
| `book_is_active` | tinyint |  | N | `1` | N | N |  | 0 = hidden from the app (never deleted by accident) |
| `book_version` | int unsigned |  | N | `1` | N | N |  | +1 whenever the file or the details change |
| `book_admin_id` | int unsigned |  | Y |  | N | N | FK | -> admins.admin_id: who last saved it |
| `book_created_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Row creation time |
| `book_updated_at` | timestamp |  | N | `current_timestamp()` | N | N |  | Last update time (auto) [on update current_timestamp()] |

**Foreign keys:** `book_admin_id` -> `admins.admin_id` (ON DELETE SET NULL, ON UPDATE RESTRICT); `book_category_id` -> `categories.category_id` (ON DELETE RESTRICT, ON UPDATE RESTRICT); `book_language_id` -> `languages.language_id` (ON DELETE RESTRICT, ON UPDATE RESTRICT)

**Indexes:** `fk_books_admin (book_admin_id)`; `idx_books_active_updated (book_is_active, book_updated_at)`; `idx_books_category (book_category_id)`; `idx_books_language (book_language_id)`; `UNIQUE PRIMARY (book_id)`

**Check constraints:** none (ENUM columns act as checks)

**Enum / lookup values:** `book_format`: pdf | epub

**Audit columns:** book_admin_id, book_created_at, book_updated_at; **soft delete:** book_is_active (0 hides), no deleted_at

**Relationships:**
- admins 1:N books via `book_admin_id` (optional)
- categories 1:N books via `book_category_id` (mandatory)
- languages 1:N books via `book_language_id` (mandatory)

---

## 3. Android local database (SQLite `percipere.db`, v7) - data dictionary

PRAGMA foreign_keys = ON is set on open. Timestamps are INTEGER epoch ms UTC; booleans are INTEGER 0/1 (mostly without CHECK); JSON is TEXT. SQLite has no lengths; 'ON UPDATE' is NO ACTION. `documents` was renamed `documents_legacy` in v4.

### `users`

- **Module:** Users & Auth
- **Purpose:** Local accounts (email+password, or guest). Source of truth for offline login; mirrors the server account. Password/PIN stored only as salted hash.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:47 (v1); ALTERs 165-177 (v2)`
- **Sync:** Partially synced: register/login/verify/reset go through the REST API (HttpAccountApi); `synced`/`server_id` flag the link. Not via outbox.
- **Counterpart:** app_users (partly; account created via POST /auth/register)
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | TEXT |  | N |  | N | N | PK | Local UUID, primary key |
| `display_name` | TEXT |  | N |  | N | N |  | Display name (legacy; copied to first_name in v2) |
| `email` | TEXT |  | Y |  | Y | N | UK | Login name; unique case-insensitive via partial index idx_users_email; NULL for guests/legacy PIN accounts |
| `secret_hash` | TEXT |  | N |  | N | N |  | Password/PIN hash (name kept from v1) |
| `secret_salt` | TEXT |  | N |  | N | N |  | Salt for secret_hash |
| `remote_id` | TEXT |  | Y |  | N | N |  | Server user id from v1; duplicate of server_id (v2 copied remote_id into server_id) |
| `created_at` | INTEGER |  | N |  | N | N |  | Epoch ms UTC |
| `updated_at` | INTEGER |  | N |  | N | N |  | Epoch ms UTC |
| `last_login_at` | INTEGER |  | Y |  | N | N |  | Epoch ms UTC |
| `first_name` | TEXT |  | Y |  | N | N |  | Added v2 |
| `last_name` | TEXT |  | Y |  | N | N |  | Added v2 |
| `secret_kind` | TEXT |  | N | `'pin'` | N | N |  | How secret_hash was made: 'pin' / 'pbkdf2-sha256:<n>' / 'none' (guest). No CHECK constraint |
| `security_question` | TEXT |  | Y |  | N | N |  | Question id for forgot-password |
| `security_answer_hash` | TEXT |  | Y |  | N | N |  | Hashed normalized answer |
| `security_answer_salt` | TEXT |  | Y |  | N | N |  | Salt for answer hash |
| `is_guest` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 (no CHECK) |
| `profiling_completed` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 (no CHECK) |
| `fingerprint_enabled` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 (no CHECK) |
| `synced` | INTEGER |  | N | `0` | N | N |  | 1 once the server has this version |
| `server_id` | TEXT |  | Y |  | N | N |  | Server app_users.user_id as text (server key is INT) |

**Foreign keys:** none

**Indexes:** `UNIQUE idx_users_email (email COLLATE NOCASE) WHERE email IS NOT NULL`

**Check constraints:** none

**Enum / lookup values:** `secret_kind`: pin | pbkdf2-sha256:<n> | none (inferred from comment, not enforced)

**Audit columns:** created_at, updated_at, last_login_at; **soft delete:** none

**Relationships:**
- users 1:N documents_legacy via `documents_legacy.user_id` (child optional)
- users 1:N sus_responses via `sus_responses.user_id` (child optional)
- users 1:N library_items via `library_items.user_id` (child optional)
- users 1:N library_collections via `library_collections.user_id` (child optional)
- users 1:N percy_turns via `percy_turns.user_id` (child optional)
- users 1:N issue_reports via `issue_reports.user_id` (child optional)

---

### `preferences`

- **Module:** Settings
- **Purpose:** Key/value settings per user; user_id='device' for settings chosen before any account. Values JSON-encoded.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:64 (v1)`
- **Sync:** Local only
- **Counterpart:** none
- **Primary key:** user_id, key (composite)

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `user_id` | TEXT |  | N |  | N | N | PK | users.id or the literal 'device' - NO foreign key (intentional) |
| `key` | TEXT |  | N |  | N | N | PK | Setting name |
| `value` | TEXT |  | N |  | N | N |  | JSON text |
| `updated_at` | INTEGER |  | N |  | N | N |  | Epoch ms |

**Foreign keys:** none

**Indexes:** none (besides PK)

**Check constraints:** none

**Audit columns:** updated_at; **soft delete:** none

**Relationships:**
- none

---

### `documents_legacy`

- **Module:** Library (legacy)
- **Purpose:** Old Reading History. Replaced by library_items in v4; renamed documents_legacy 'until the user confirms nothing was lost'.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:75 (v1), rebuilt 210 (v3), renamed 354 (v4)`
- **Sync:** Local only; kept as safety copy after v4 (not referenced by app code)
- **Counterpart:** none
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK | Autoincrement |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `title` | TEXT |  | N |  | N | N |  |  |
| `full_text` | TEXT |  | N |  | N | N |  | Extracted text |
| `source_type` | TEXT |  | N |  | N | N |  | CHECK in list below |
| `language` | TEXT |  | N | `'fil'` | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  | Epoch ms |
| `updated_at` | INTEGER |  | N |  | N | N |  | Epoch ms |
| `last_opened_at` | INTEGER |  | Y |  | N | N |  |  |
| `last_position` | INTEGER |  | N | `0` | N | N |  | Sentence/char position |
| `thumbnail_path` | TEXT |  | Y |  | N | N |  | Added v3 |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** `idx_documents_user_created (user_id, created_at DESC) - name kept after rename`

**Check constraints:** `source_type IN ('camera','image','pdf','docx','description')`

**Enum / lookup values:** `source_type`: camera | image | pdf | docx | description

**Audit columns:** created_at, updated_at; **soft delete:** none

**Relationships:**
- users 1:N documents_legacy via `user_id` (optional)

---

### `usage_logs`

- **Module:** Telemetry & Evaluation
- **Purpose:** Anonymized usage events (no user id) with a random per-install session id; uploaded_at marks upload.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:93 (v1)`
- **Sync:** Not synced; table is never read or written by app code (only created)
- **Counterpart:** none yet (server has no usage table; outbox type 'usage_logs' planned)
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK |  |
| `session_id` | TEXT |  | N |  | N | N |  | Random per-install/session id |
| `event_type` | TEXT |  | N |  | N | N |  |  |
| `screen` | TEXT |  | Y |  | N | N |  |  |
| `input_mode` | TEXT |  | Y |  | N | N |  | CHECK list below |
| `payload` | TEXT |  | Y |  | N | N |  | JSON text |
| `created_at` | INTEGER |  | N |  | N | N |  | Epoch ms |
| `uploaded_at` | INTEGER |  | Y |  | N | N |  | NULL = not uploaded |

**Foreign keys:** none

**Indexes:** `idx_usage_logs_uploaded (uploaded_at)`

**Check constraints:** `input_mode IS NULL OR input_mode IN ('gesture','voice','touch','talkback')`

**Enum / lookup values:** `input_mode`: gesture | voice | touch | talkback

**Audit columns:** created_at; **soft delete:** none

**Relationships:**
- none

---

### `outbox`

- **Module:** Sync
- **Purpose:** Generic offline upload queue (report, feedback, sus, usage_logs, account_sync).
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:110 (v1)`
- **Sync:** Designed as the offline queue for all server-bound data; currently UNUSED (no code references it)
- **Counterpart:** none
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK |  |
| `type` | TEXT |  | N |  | N | N |  | CHECK list below |
| `payload` | TEXT |  | N |  | N | N |  | JSON text |
| `status` | TEXT |  | N | `'pending'` | N | N |  | CHECK list below |
| `attempts` | INTEGER |  | N | `0` | N | N |  |  |
| `last_error` | TEXT |  | Y |  | N | N |  |  |
| `next_attempt_at` | INTEGER |  | Y |  | N | N |  | Epoch ms |
| `created_at` | INTEGER |  | N |  | N | N |  |  |
| `updated_at` | INTEGER |  | N |  | N | N |  |  |

**Foreign keys:** none

**Indexes:** `idx_outbox_due (status, next_attempt_at)`

**Check constraints:** `type IN ('report','feedback','sus','usage_logs','account_sync')`; `status IN ('pending','sending','sent','failed')`

**Enum / lookup values:** `type`: report | feedback | sus | usage_logs | account_sync; `status`: pending | sending | sent | failed

**Audit columns:** created_at, updated_at; **soft delete:** none

**Relationships:**
- none

---

### `sus_responses`

- **Module:** Telemetry & Evaluation
- **Purpose:** System Usability Scale results; answers = JSON array of ten 1..5 ints.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:129 (v1)`
- **Sync:** Not synced; table never read or written by app code
- **Counterpart:** none (server has no SUS table)
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK |  |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `answers` | TEXT |  | N |  | N | N |  | JSON array (10 ints) - candidate for normalization |
| `score` | REAL |  | N |  | N | N |  | CHECK 0..100 |
| `language` | TEXT |  | N |  | N | N |  |  |
| `input_mode` | TEXT |  | Y |  | N | N |  | No CHECK here, unlike usage_logs |
| `created_at` | INTEGER |  | N |  | N | N |  |  |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE SET NULL, ON UPDATE NO ACTION)

**Indexes:** none (besides PK)

**Check constraints:** `score BETWEEN 0 AND 100`

**Audit columns:** created_at; **soft delete:** none

**Relationships:**
- users 1:N sus_responses via `user_id` (optional)

---

### `wer_results`

- **Module:** Telemetry & Evaluation
- **Purpose:** Word Error Rate evaluation runs for speech recognition.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:142 (v1)`
- **Sync:** Not synced; table never read or written by app code
- **Counterpart:** none
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK |  |
| `session_id` | TEXT |  | N |  | N | N |  | Logical grouping, no FK |
| `locale` | TEXT |  | N |  | N | N |  |  |
| `on_device` | INTEGER |  | N |  | N | N |  | CHECK 0/1 |
| `reference` | TEXT |  | N |  | N | N |  | Reference text |
| `hypothesis` | TEXT |  | N |  | N | N |  | Recognized text |
| `substitutions` | INTEGER |  | N |  | N | N |  |  |
| `deletions` | INTEGER |  | N |  | N | N |  |  |
| `insertions` | INTEGER |  | N |  | N | N |  |  |
| `reference_words` | INTEGER |  | N |  | N | N |  |  |
| `wer` | REAL |  | N |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  |  |

**Foreign keys:** none

**Indexes:** `idx_wer_results_session (session_id)`

**Check constraints:** `on_device IN (0,1)`

**Audit columns:** created_at; **soft delete:** none

**Relationships:**
- none

---

### `login_attempts`

- **Module:** Users & Auth
- **Purpose:** Failed-login counters so the lockout survives restarts. key = 'login:'/'reset:' + lowercased email.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:188 (v2)`
- **Sync:** Local only
- **Counterpart:** api_limits (different mechanism; inferred)
- **Primary key:** key

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `key` | TEXT |  | N |  | N | N | PK | Prefix + lowercased email |
| `failures` | INTEGER |  | N | `0` | N | N |  |  |
| `locked_until` | INTEGER |  | Y |  | N | N |  | Epoch ms |
| `updated_at` | INTEGER |  | N |  | N | N |  |  |

**Foreign keys:** none

**Indexes:** none (besides PK)

**Check constraints:** none

**Audit columns:** updated_at; **soft delete:** none

**Relationships:**
- none

---

### `library_items`

- **Module:** Library
- **Purpose:** One row per thing on the shelves: the user's own documents and, per user, each downloaded/catalog admin book (progress is per user).
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:253 (v4)`
- **Sync:** Admin-book rows are fetched from GET /api/v1/books; user's own documents are local_only=1 and never leave the phone. `synced` flag for planned Phase 7 progress sync (not built).
- **Counterpart:** books (rows with source='book' only, inferred); user documents have no server table
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | TEXT |  | N |  | N | N | PK | UUID v4 |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `source` | TEXT |  | N |  | N | N |  | CHECK list |
| `format` | TEXT |  | N |  | N | N |  | CHECK list |
| `language` | TEXT |  | N | `'fil'` | N | N |  | Language code (server: languages.language_code) |
| `title` | TEXT |  | N |  | N | N |  |  |
| `author` | TEXT |  | Y |  | N | N |  |  |
| `cover_path` | TEXT |  | Y |  | N | N |  | Local file path |
| `file_path` | TEXT |  | Y |  | N | N |  | Local file path |
| `text_ref` | TEXT |  | N | `'db'` | N | N |  | Where text lives: 'db' or file |
| `full_text` | TEXT |  | Y |  | N | N |  |  |
| `text_path` | TEXT |  | Y |  | N | N |  |  |
| `chapters` | TEXT |  | Y |  | N | N |  | JSON text - candidate for child table |
| `total_sentences` | INTEGER |  | Y |  | N | N |  |  |
| `word_count` | INTEGER |  | Y |  | N | N |  |  |
| `chapter_index` | INTEGER |  | N | `0` | N | N |  | Reading position |
| `sentence_index` | INTEGER |  | N | `0` | N | N |  | Reading position |
| `percent` | REAL |  | N | `0` | N | N |  |  |
| `finished` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 |
| `last_opened_at` | INTEGER |  | Y |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  |  |
| `updated_at` | INTEGER |  | N |  | N | N |  |  |
| `book_id` | TEXT |  | Y |  | N | N |  | Catalog book id from server (books.book_id, INT on server) - logical link, no FK possible |
| `book_version` | INTEGER |  | Y |  | N | N |  | Version downloaded (books.book_version) |
| `remote_version` | INTEGER |  | Y |  | N | N |  | Latest version known on server |
| `category` | TEXT |  | Y |  | N | N |  | Category NAME text (server: categories.category_id) |
| `description` | TEXT |  | Y |  | N | N |  | books.book_description |
| `cover_url` | TEXT |  | Y |  | N | N |  | Server cover URL |
| `file_size` | INTEGER |  | Y |  | N | N |  | books.book_file_size |
| `downloaded` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 |
| `is_new` | INTEGER |  | N | `0` | N | N |  | Boolean 0/1 |
| `unavailable` | INTEGER |  | N | `0` | N | N |  | Boolean; book removed/hidden on server (soft state) |
| `local_only` | INTEGER |  | N | `0` | N | N |  | 1 = never synced (user's own documents) |
| `synced` | INTEGER |  | N | `0` | N | N |  |  |
| `legacy_id` | INTEGER |  | Y |  | N | N |  | documents_legacy.id this row was migrated from - no FK |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** `idx_library_items_user (user_id, last_opened_at DESC)`; `UNIQUE idx_library_items_book (user_id, book_id) WHERE book_id IS NOT NULL`

**Check constraints:** `source IN ('camera','upload','description','book')`; `format IN ('image','pdf','docx','epub')`

**Enum / lookup values:** `source`: camera | upload | description | book; `format`: image | pdf | docx | epub

**Audit columns:** created_at, updated_at; **soft delete:** unavailable (book removed on server)

**Relationships:**
- users 1:N library_items via `user_id` (optional)
- library_items 1:N library_favorites via `library_favorites.item_id` (child mandatory)
- library_items 1:N library_collection_items via `library_collection_items.item_id` (child mandatory)
- library_items M:N library_collections via library_collection_items

---

### `library_favorites`

- **Module:** Library
- **Purpose:** Saved spots (bookmarks) inside a library item.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:299 (v4)`
- **Sync:** Local only for now (synced flag reserved for Phase 7)
- **Counterpart:** none (planned sync, no server table)
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | TEXT |  | N |  | N | N | PK | UUID |
| `item_id` | TEXT |  | N |  | N | N | FK | FK library_items.id |
| `chapter_index` | INTEGER |  | N | `0` | N | N |  |  |
| `sentence_index` | INTEGER |  | N |  | N | N |  |  |
| `label` | TEXT |  | N |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  |  |
| `updated_at` | INTEGER |  | N |  | N | N |  |  |
| `synced` | INTEGER |  | N | `0` | N | N |  |  |

**Foreign keys:** `item_id` -> `library_items.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** `idx_library_favorites_item (item_id)`

**Check constraints:** none

**Audit columns:** created_at, updated_at; **soft delete:** none

**Relationships:**
- library_items 1:N library_favorites via `item_id` (mandatory)

---

### `library_collections`

- **Module:** Library
- **Purpose:** The user's own named groups of library items.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:314 (v4)`
- **Sync:** Local only for now
- **Counterpart:** none (planned sync, no server table)
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | TEXT |  | N |  | N | N | PK | UUID |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `name` | TEXT |  | N |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  |  |
| `updated_at` | INTEGER |  | N |  | N | N |  |  |
| `synced` | INTEGER |  | N | `0` | N | N |  |  |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** none (besides PK)

**Check constraints:** none

**Audit columns:** created_at, updated_at; **soft delete:** none

**Relationships:**
- users 1:N library_collections via `user_id` (optional)
- library_collections 1:N library_collection_items via `library_collection_items.collection_id` (child mandatory)
- library_collections M:N library_items via library_collection_items

---

### `library_collection_items`

- **Module:** Library
- **Purpose:** Junction table: M:N between library_collections and library_items.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:324 (v4)`
- **Sync:** Local only for now
- **Counterpart:** none
- **Primary key:** collection_id, item_id (composite)

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `collection_id` | TEXT |  | N |  | N | N | PK/FK | FK library_collections.id |
| `item_id` | TEXT |  | N |  | N | N | PK/FK | FK library_items.id |
| `added_at` | INTEGER |  | N |  | N | N |  |  |
| `synced` | INTEGER |  | N | `0` | N | N |  |  |

**Foreign keys:** `collection_id` -> `library_collections.id` (ON DELETE CASCADE, ON UPDATE NO ACTION); `item_id` -> `library_items.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** none (besides PK)

**Check constraints:** none

**Audit columns:** none; **soft delete:** none

**Relationships:**
- library_collections 1:N library_collection_items via `collection_id` (mandatory)
- library_items 1:N library_collection_items via `item_id` (mandatory)
- **Junction table**: library_collections M:N library_items

---

### `percy_turns`

- **Module:** Percy (voice assistant)
- **Purpose:** One row per sentence said to Percy, with predicted intent, for retraining the classifier.
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:364 (v5)`
- **Sync:** Local only (kept on the phone for retraining; no document content)
- **Counterpart:** none
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | INTEGER |  | N |  | N | Y | PK |  |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `text` | TEXT |  | N |  | N | N |  | User utterance |
| `intent` | TEXT |  | Y |  | N | N |  |  |
| `confidence` | REAL |  | Y |  | N | N |  |  |
| `outcome` | TEXT |  | N |  | N | N |  | acted, confirmed, corrected, declined, asked, fallback, chat, answered, notAvailable, matcher (comment only, no CHECK) |
| `screen` | TEXT |  | Y |  | N | N |  |  |
| `model_version` | TEXT |  | Y |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  |  |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE CASCADE, ON UPDATE NO ACTION)

**Indexes:** `idx_percy_turns_user (user_id, created_at)`

**Check constraints:** none

**Enum / lookup values:** `outcome`: acted | confirmed | corrected | declined | asked | fallback | chat | answered | notAvailable | matcher (not enforced)

**Audit columns:** created_at; **soft delete:** none

**Relationships:**
- users 1:N percy_turns via `user_id` (optional)

---

### `issue_reports`

- **Module:** Reports
- **Purpose:** Every 'Mag-report ng problema' is saved here first, then sent to the dashboard. Outlives the account (user_id -> NULL).
- **Location:** Android local DB
- **Source:** `lib/core/db/migrations.dart:392 (v6); server_status ALTER 383 (v7)`
- **Sync:** Synced directly through REST with its own retry columns (sync_status/attempts/last_error), NOT via outbox
- **Counterpart:** feedback (sent via POST /api/v1/reports; status via GET /reports/{ticket_no})
- **Primary key:** id

| Column | Type | Len | Null | Default | Unique | Auto-inc | Key | Description |
|---|---|---|---|---|---|---|---|---|
| `id` | TEXT |  | N |  | N | N | PK | UUID |
| `ticket_no` | TEXT |  | N |  | Y | N | UK | PRC-YYYYMMDD-XXXX |
| `user_id` | TEXT |  | Y |  | N | N | FK | FK users.id |
| `type` | TEXT |  | N |  | N | N |  | Report type code |
| `module` | TEXT |  | N |  | N | N |  | Module code |
| `severity` | TEXT |  | Y |  | N | N |  | Only for bugs |
| `description` | TEXT |  | N |  | N | N |  |  |
| `email` | TEXT |  | Y |  | N | N |  | Reply email |
| `app_version` | TEXT |  | N |  | N | N |  |  |
| `os_version` | TEXT |  | N |  | N | N |  |  |
| `device_model` | TEXT |  | N |  | N | N |  |  |
| `source_screen` | TEXT |  | N |  | N | N |  |  |
| `created_at` | INTEGER |  | N |  | N | N |  | Epoch ms |
| `sync_status` | TEXT |  | N | `'pending'` | N | N |  | pending / sent / failed (comment only, no CHECK) |
| `server_id` | TEXT |  | Y |  | N | N |  | feedback.feedback_id as text |
| `attempts` | INTEGER |  | N | `0` | N | N |  |  |
| `last_error` | TEXT |  | Y |  | N | N |  |  |
| `server_status` | TEXT |  | Y |  | N | N |  | Added v7: open / in_progress / resolved / closed; NULL = not asked yet |

**Foreign keys:** `user_id` -> `users.id` (ON DELETE SET NULL, ON UPDATE NO ACTION)

**Indexes:** `idx_issue_reports_sync (sync_status, created_at)`; `idx_issue_reports_user (user_id, created_at)`; `UNIQUE (ticket_no) - implicit`

**Check constraints:** none

**Enum / lookup values:** `sync_status`: pending | sent | failed (not enforced); `server_status`: open | in_progress | resolved | closed (not enforced)

**Audit columns:** created_at; **soft delete:** none

**Relationships:**
- users 1:N issue_reports via `user_id` (optional)

---

## 4. Pending changes: live DB vs `fix/webapp-api` (schema v12)

**Live `schema_version` = 12, equal to the branch's `SCHEMA_VERSION`/`database.sql`.** All 13 tables exist and every column of the branch's `database.sql` exists in the live DB with matching type/null/default. Differences are only the two optional scripts below that have not been run. (`ui/rounded-no-shadow` has no schema change.)

### 4.1 Tables added / removed / altered by the branch
None: no table is added, removed or altered beyond what the live DB already has.

### 4.2 `v12_remove_personal_columns.sql` (OPTIONAL, destructive, no down script) - NOT applied in live DB

It would run `ALTER TABLE members DROP COLUMN IF EXISTS` on these 7 columns, which **still exist in the live DB**:

| Table | Column | Live type | In database.sql v12 | After script |
|---|---|---|---|---|
| members | `member_address` | varchar | no | **dropped** |
| members | `member_age` | varchar | no | **dropped** |
| members | `member_bio` | varchar | no | **dropped** |
| members | `member_contribution` | text | no | **dropped** |
| members | `member_experiences` | text | no | **dropped** |
| members | `member_photo` | varchar | no | **dropped** |
| members | `member_sex` | varchar | no | **dropped** |

Columns the branch adds that live lacks: none. Effect: `members` goes from 13 columns to 6 (`member_id, member_name, member_role, member_school, member_email, member_created_at`). Nothing references the dropped columns (no FK, no index), so the ERD files (keys only) are unaffected; the to-be ERD assumes this script is applied. The columns may hold real personal data (age, sex, address, photo, bio); values were deliberately not read.

### 4.3 `v3_admin_fks.sql` (optional) - NOT applied in live DB

| Table | Column | References | ON DELETE | Status |
|---|---|---|---|---|
| feedback | `feedback_admin_id` | admins.admin_id | SET NULL | in `database.sql`, absent in live |
| feedback_notes | `note_admin_id` | admins.admin_id | SET NULL | in `database.sql`, absent in live |
| audit_log | `log_admin_id` | admins.admin_id | SET NULL | in `database.sql`, absent in live |
| admins | `admin_role_id` | roles.role_id | (none) | comment only in every schema file; no FK anywhere |
| app_settings | `setting_admin_id` | admins.admin_id | (none) | by design 'kept by the code, no FK constraint' |

### 4.4 Other differences
- Index/constraint names for unique keys differ cosmetically (live: `email`, `user_email`, `token_hash`, `role_name`; branch: implicit). No functional difference.
- v8-v11 migrations (tokens/limits/feedback linking, ticket numbers, library, report codes) are all reflected in the live DB.

## 5. Android vs server comparison

### 5.1 Table presence

| Android table | Server counterpart | Sync path | Status |
|---|---|---|---|
| users | app_users | REST: POST /auth/register, /auth/login, verify, resend, password reset, GET /auth/me. `users.server_id`=app_users.user_id, `synced` flag | **Synced (account); Android has more local-only columns** |
| issue_reports | feedback | REST: POST /reports, GET /reports/{ticket_no}; own retry columns | **Synced** |
| library_items (source='book') | books (+categories, languages) | REST: GET /books, /books/{id}/file, /cover, /categories - one-way download | **Synced read-only** (inferred mapping) |
| library_items (user documents) | - | never leaves the phone (`local_only=1`) | Local only by design |
| login_attempts | api_limits | none - separate lockouts (client vs server) | Local only; server counterpart is functionally similar (inferred) |
| preferences, percy_turns, library_favorites, library_collections, library_collection_items | - | none (Phase 7 sync designed, not built; `synced` columns reserved) | Local only |
| outbox | - | none - table exists but no code uses it | **Unused** |
| usage_logs, sus_responses, wer_results | - | none - no server tables, no code uses them | **Unused / reserved** |
| documents_legacy | - | none | Legacy safety copy, unused |
| - | members, roles, admins, audit_log, app_settings, app_tokens, feedback_notes | dashboard-only | Server only (staff/admin/infrastructure) |

**Outbox answer:** no Android table currently syncs through `outbox`. `issue_reports` carries its own `sync_status/attempts/last_error`; accounts sync inline via HTTP; the book catalog is pulled on demand.

### 5.2 Column differences for mapped pairs

**users <-> app_users**

| Android `users` | Server `app_users` | Difference |
|---|---|---|
| `id` TEXT UUID (PK) | `user_id` INT UNSIGNED AI (PK) | different key type; link is `server_id` TEXT (stores the INT as text) |
| `email` TEXT null (unique NOCASE) | `user_email` VARCHAR(150) NOT NULL UNIQUE | nullability differs (guest/legacy accounts have no email); server collation is case-insensitive |
| `first_name`+`last_name` (+ `display_name`) | `user_full_name` VARCHAR(100) | split vs single column (inferred: register sends `full_name`) |
| `secret_hash`/`secret_salt`/`secret_kind` | `user_password_hash` VARCHAR(255) | different hash scheme (PBKDF2 local vs server hash - inferred); salt separate vs embedded |
| `created_at` INTEGER ms | `user_created_at` DATETIME | type/units differ |
| `last_login_at` INTEGER | `user_last_login_at` DATETIME | type differs; independent values |
| `remote_id` and `server_id` | - | duplicate columns on Android |
| `security_question/_answer_hash/_salt`, `is_guest`, `profiling_completed`, `fingerprint_enabled`, `synced`, `updated_at`, `display_name` | - | Android only (server has no security question; reset is by emailed code) |
| - | `user_phone_number`, `user_status`, `user_email_verified_at`, `user_otp_*`, `user_position`, `user_phone_verified_at` | server only; Android has no status/suspension column (suspension checked online) |

**issue_reports <-> feedback**

| Android | Server | Difference |
|---|---|---|
| `id` TEXT UUID | `feedback_id` INT | different key; link `server_id` TEXT |
| `ticket_no` TEXT UNIQUE | `feedback_ticket_no` VARCHAR(20) NULL UNIQUE | nullability differs (server NULL for seed rows) |
| `type`, `module`, `severity` (codes) | `feedback_type_code`, `_module_code`, `_severity_code` (VARCHAR(40) NULL) + label columns `feedback_category`, `feedback_module`, `feedback_severity` | Android stores codes only; server also stores labels |
| `description` TEXT | `feedback_description` TEXT | same |
| `email` TEXT null | `feedback_email` VARCHAR(191) NOT NULL DEFAULT '' | null vs empty string |
| `app_version`, `os_version`, `device_model`, `source_screen` | `feedback_app_version` VARCHAR(20), `_os_version` VARCHAR(40), `_device` VARCHAR(100), `_source_screen` VARCHAR(50) | name differs (`device_model`/`_device`); server lengths could truncate |
| `created_at` INTEGER ms | `feedback_app_created_at` DATETIME NULL (+ `feedback_created_at` server receive time) | type/name differ |
| `server_status` open/in_progress/resolved/closed | `feedback_status` ENUM('Open','In Progress','Resolved') + `feedback_archived_at` | values differ in case/spaces; 'closed' = archived (feedback_api_status) |
| `user_id` | `feedback_user_id` | UUID vs INT; server resolves it from the bearer token |
| `sync_status`, `attempts`, `last_error` | - | Android only |
| - | `feedback_reporter_kind/_name`, status/source/dates, member/admin ids | server only (reporter kind derived from login state) |

**library_items <-> books (inferred)**

| Android | Server | Difference |
|---|---|---|
| `book_id` TEXT | `book_id` INT | type differs |
| `title`, `author`, `description` | `book_title` VARCHAR(200), `book_author` VARCHAR(150) NOT NULL default '', `book_description` TEXT | author nullable on Android |
| `category` TEXT (name) | `book_category_id` INT FK -> categories | denormalised name vs FK; a renamed category won't match |
| `language` TEXT (code) | `book_language_id` INT FK -> languages(language_code) | code vs id |
| `format` image/pdf/docx/epub | `book_format` ENUM('pdf','epub') | Android superset (user documents) |
| `book_version`, `remote_version` | `book_version` | ok |
| `file_size` | `book_file_size` | ok; `book_file_hash` (SHA-256) not stored on Android (verified at download) |
| `cover_url`, `cover_path` | `book_cover_path`, `book_cover_mime` | server stores a storage name, API exposes URL |
| `unavailable` | `book_is_active` | inverse semantics (inferred) |

### 5.3 Missing foreign keys, orphan columns, denormalised data

| Where | Issue | Suggestion (not applied) |
|---|---|---|
| server `admins.admin_role_id` | `*_id` with no FK in any schema file, live or branch | DECIDED: add `FOREIGN KEY (admin_role_id) REFERENCES roles(role_id) ON DELETE RESTRICT` (A4) |
| server `feedback.feedback_admin_id`, `feedback_notes.note_admin_id`, `audit_log.log_admin_id` | FKs in `database.sql` but missing live (`v3_admin_fks.sql` not applied) | Run v3_admin_fks.sql after a MySQL restart (see its header: crashed MariaDB once) |
| server `app_settings.setting_admin_id` | Intentionally no FK | Optional FK ON DELETE SET NULL |
| server `audit_log.log_member_id` ON DELETE CASCADE (FLAGGED), `feedback_notes.note_member_id` ON DELETE CASCADE | Deleting a team member deletes audit history and notes | Both FLAGGED: fix = SET NULL (section 7.5, A3 and A5) |
| server `admins.admin_preferences` TEXT (JSON) | JSON in a column | Acceptable; document keys, or a key/value table if queried |
| server `feedback` | Denormalised labels (`feedback_category`, `_module`, `_severity`) beside `*_code` columns; `feedback_member_id` and `feedback_admin_id` both attribute the same action | Lookup tables for type/module/severity; keep only admin_id |
| server `feedback.feedback_reporter_name`/`feedback_email` | Copies of user data instead of FK-only | Fine for guests; consider nulling when `feedback_user_id` set |
| server `app_users.user_otp_hash` etc. | One-time-code state stored on user row | Acceptable; separate table only if multiple concurrent codes are needed |
| server DATE/TIMESTAMP/DATETIME mixing | `feedback_submitted_at` DATE, `app_users.*_at` DATETIME, others TIMESTAMP | Standardise (UTC) when convenient |
| Android `preferences.user_id` | Holds users.id or 'device', no FK | Keep (documented) or insert a 'device' pseudo-user |
| Android `library_items.book_id` | Logical link to server books.book_id (INT vs TEXT), no FK possible across DBs | Document as a logical key; store as INTEGER if the server key stays numeric |
| Android `library_items.category`/`language` | Names/codes instead of ids | Store server category_id / language_code consistently |
| Android `library_items.chapters`, `sus_responses.answers`, `usage_logs.payload`, `outbox.payload`, `preferences.value` | JSON stored as TEXT | `chapters` -> `library_chapters` table if queried; `answers` -> 10 rows/columns if SUS analysed in SQL |
| Android `library_items.legacy_id` | Orphan id to documents_legacy, no FK | Drop with documents_legacy once migration is confirmed |
| Android `users.remote_id` vs `server_id` | Duplicate columns | Keep one (v2 copied remote_id -> server_id) |
| Android `outbox`, `usage_logs`, `sus_responses`, `wer_results`, `documents_legacy` | Tables never read/written by app code | Confirm intent; drop or wire up |
| Android boolean/status columns (`is_guest`, `secret_kind`, `sync_status`, `server_status`, `outcome`, ...) | No CHECK constraints | Add CHECKs in a new migration (SQLite needs table rebuild) |
| Android `users.email` NULLable + partial unique | Guests/legacy PIN accounts have no email | OK; document |

_All entries in the last column are suggestions only._

## 6. Cross-checks and assumptions
- Column counts and types of server tables come from the live `information_schema`; descriptions come from comments in `database.sql` where present, otherwise (inferred) from names.
- Seed/lookup data in live DB: roles (3: super_admin, support_staff, analyst), languages (2: Filipino/fil, English/en); categories and books are empty. `app_settings` holds `schema_version`=12 (only key found).
- Check constraints: none exist on the server (MariaDB `information_schema.check_constraints` is empty).

## 7. As-is vs To-be

**As-is** = what exists today (live DB at schema 12 + Android migrations v1-v7; sections 1-6 above). **To-be** = the target the ERD files describe. Nothing below was executed; the statements are in `proposed-changes.sql`.

### 7.1 Decisions applied
| # | Decision | Effect |
|---|---|---|
| 1 | ERD target is the to-be schema: `v12_remove_personal_columns.sql` and `v3_admin_fks.sql` are assumed applied (neither was run) | `members` drops 7 columns; 3 admin FKs added |
| 2 | `outbox`, `usage_logs`, `documents_legacy` are **deprecated**; `sus_responses` and `wer_results` are **kept** | The 3 deprecated tables stay in this masterlist and CSV (tagged) but are **excluded from `erd-android.mmd`** |
| 3 | `audit_log.log_member_id` ON DELETE CASCADE is a **flagged issue**; proposed fix ON DELETE SET NULL | Flagged in `erd-server.mmd`; statement in `proposed-changes.sql` (A3; extended to `feedback_notes.note_member_id`, A5) |

### 7.2 Server (MariaDB)

| Item | As-is (live) | To-be | Source of change |
|---|---|---|---|
| `members` columns | 13 | 6 (`member_id, member_name, member_role, member_school, member_email, member_created_at`) | v12_remove_personal_columns.sql (not run) |
| `feedback.feedback_admin_id` -> `admins.admin_id` | no FK | FK, ON DELETE SET NULL | v3_admin_fks.sql (not run) |
| `feedback_notes.note_admin_id` -> `admins.admin_id` | no FK | FK, ON DELETE SET NULL | v3_admin_fks.sql (not run) |
| `audit_log.log_admin_id` -> `admins.admin_id` | no FK | FK, ON DELETE SET NULL | v3_admin_fks.sql (not run) |
| `audit_log.log_member_id` -> `members.member_id` | ON DELETE **CASCADE** (flagged) | proposed ON DELETE SET NULL (column already nullable) | proposed-changes.sql A3 |
| `admins.admin_role_id` -> `roles.role_id` | no FK anywhere | proposed FK, **ON DELETE RESTRICT** (roles are never deleted by the code and permissions depend on the role) | proposed-changes.sql A4 |
| `app_settings.setting_admin_id` | no FK by design | unchanged (dotted) | - |
| `feedback_notes.note_member_id` -> `members.member_id` | ON DELETE **CASCADE** (flagged) | proposed ON DELETE SET NULL (removing a team member would delete their internal notes) | proposed-changes.sql A5 |

Server totals: 13 tables in both states. Enforced FKs: **10 as-is -> 13 to-be** (+3 from v3_admin_fks). Including the proposed A4: **14** enforced FKs. Relationships with no FK: 5 -> 1 (`app_settings.setting_admin_id`, by design).

### 7.3 Android (SQLite)

| Table | As-is | To-be |
|---|---|---|
| `outbox` | table, unused by code | **deprecated**: drop (proposed v8 migration); excluded from erd-android |
| `usage_logs` | table, unused by code | **deprecated**: drop; excluded from erd-android |
| `documents_legacy` | renamed safety copy, FK to users | **deprecated**: drop; excluded from erd-android. Its FK disappears |
| `library_items.legacy_id` | orphan id pointing at documents_legacy | becomes dead once documents_legacy is dropped; optional drop (commented in proposed-changes.sql) |
| `sus_responses`, `wer_results` | tables, unused by code | **kept** as-is (decision 2) |
| `users.remote_id` vs `server_id` | duplicate columns | unchanged (still open) |

Android totals: 14 tables as-is -> **11** in the to-be ERD. FKs: 9 -> **8**. Migration `_v8` is only *proposed*; the app's `lib/core/db/migrations.dart` was not touched (project rule: new migration, never edit shipped ones).

### 7.4 To-be totals
- Tables in ERD files: **24** (13 server + 11 Android) vs 27 as-is; 3 deprecated tables kept only in this masterlist.
- Enforced FKs: **22** (14 server incl. proposed A4 + 8 Android) vs 19 as-is.
- Cross-database mappings: 3 (`erd-sync.mmd`).

### 7.5 Flagged issues: cascade on `audit_log` and `feedback_notes`
`audit_log.log_member_id` is `ON DELETE CASCADE` to `members`. Removing a team member would silently delete every audit entry they made, defeating the purpose of an audit log. The column is nullable, so `ON DELETE SET NULL` is safe (the row keeps `log_action`, `log_created_at` and, if set, `log_admin_id`). Caveat: after v3 + this fix, an entry may lose both attributions if the member and admin are both deleted. The same reasoning applies to `feedback_notes.note_member_id` (note text stays, only attribution is lost; A5).

