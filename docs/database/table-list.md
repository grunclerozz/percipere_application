# Table list

## Web (MySQL / MariaDB)

### members
Team members (the 4 project members) shown in Settings -> Team; target of audit/feedback attribution.

| Column | Type |
|---|---|
| member_id | int unsigned |
| member_name | varchar(150) |
| member_role | varchar(150) |
| member_school | varchar(200) |
| member_email | varchar(191) |
| member_bio | varchar(400) |
| member_photo | varchar(255) |
| member_age | varchar(20) |
| member_sex | varchar(50) |
| member_address | varchar(255) |
| member_experiences | text |
| member_contribution | text |
| member_created_at | timestamp |

### roles
Dashboard staff roles: super_admin, support_staff, analyst.

| Column | Type |
|---|---|
| role_id | int unsigned |
| role_name | varchar(50) |
| role_description | varchar(255) |

### admins
Staff accounts that can log into the dashboard (separate from app users).

| Column | Type |
|---|---|
| admin_id | int unsigned |
| admin_email | varchar(191) |
| admin_full_name | varchar(150) |
| admin_password_hash | varchar(255) |
| admin_member_id | int unsigned |
| admin_role_id | int unsigned |
| admin_status | enum('active','suspended') |
| admin_failed_login_attempts | int |
| admin_locked_until | datetime |
| admin_last_login_at | datetime |
| admin_preferences | text |
| admin_session_version | int unsigned |
| admin_created_at | timestamp |
| admin_updated_at | timestamp |

### app_users
End users of the Android app (registered through POST /api/v1/auth/register, emailed one-time code).

| Column | Type |
|---|---|
| user_id | int unsigned |
| user_full_name | varchar(100) |
| user_email | varchar(150) |
| user_phone_number | varchar(20) |
| user_password_hash | varchar(255) |
| user_status | enum('pending_verification','pending_approval','active','suspended') |
| user_email_verified_at | datetime |
| user_otp_hash | varchar(255) |
| user_otp_expires_at | datetime |
| user_otp_sent_at | datetime |
| user_position | varchar(100) |
| user_phone_verified_at | datetime |
| user_created_at | datetime |
| user_last_login_at | datetime |

### app_tokens
Bearer sign-in tokens for the app API; only SHA-256 of each token stored; one row per device.

| Column | Type |
|---|---|
| token_id | int unsigned |
| token_user_id | int unsigned |
| token_hash | char(64) |
| token_device | varchar(100) |
| token_created_at | datetime |
| token_last_used_at | datetime |
| token_expires_at | datetime |

### api_limits
Rate-limit and lockout counters for the app API; key = SHA-256 of e.g.

| Column | Type |
|---|---|
| limit_key | char(64) |
| limit_count | int unsigned |
| limit_window_start | datetime |
| limit_locked_until | datetime |

### feedback
Concerns and bug reports from the app's 'Report an issue' (+ seed rows); the dashboard's Feedback & Bugs page.

| Column | Type |
|---|---|
| feedback_id | int unsigned |
| feedback_category | varchar(60) |
| feedback_type_code | varchar(40) |
| feedback_module | varchar(60) |
| feedback_module_code | varchar(40) |
| feedback_severity | varchar(40) |
| feedback_severity_code | varchar(40) |
| feedback_description | text |
| feedback_email | varchar(191) |
| feedback_user_id | int unsigned |
| feedback_app_version | varchar(20) |
| feedback_device | varchar(100) |
| feedback_os_version | varchar(40) |
| feedback_ticket_no | varchar(20) |
| feedback_source_screen | varchar(50) |
| feedback_reporter_kind | enum('account','guest') |
| feedback_reporter_name | varchar(100) |
| feedback_app_created_at | datetime |
| feedback_status | enum('Open','In Progress','Resolved') |
| feedback_source | enum('app','seed') |
| feedback_submitted_at | date |
| feedback_resolved_at | date |
| feedback_archived_at | datetime |
| feedback_member_id | int unsigned |
| feedback_admin_id | int unsigned |
| feedback_created_at | timestamp |
| feedback_updated_at | timestamp |

### feedback_notes
Internal staff notes on a feedback item.

| Column | Type |
|---|---|
| note_id | int unsigned |
| note_feedback_id | int unsigned |
| note_member_id | int unsigned |
| note_admin_id | int unsigned |
| note_text | text |
| note_created_at | timestamp |
| note_updated_at | timestamp |

### audit_log
Every change made in the dashboard (Reports -> Audit Log).

| Column | Type |
|---|---|
| log_id | int unsigned |
| log_member_id | int unsigned |
| log_admin_id | int unsigned |
| log_action | varchar(255) |
| log_created_at | timestamp |

### app_settings
System-wide key/value rules (Settings -> System); also stores schema_version.

| Column | Type |
|---|---|
| setting_key | varchar(64) |
| setting_value | varchar(255) |
| setting_updated_at | timestamp |
| setting_admin_id | int unsigned |

### categories
Library categories managed by admins.

| Column | Type |
|---|---|
| category_id | int unsigned |
| category_name | varchar(80) |
| category_is_active | tinyint |
| category_created_at | timestamp |
| category_updated_at | timestamp |

### languages
Book languages (fil, en); language_code lets the app pick the reading voice.

| Column | Type |
|---|---|
| language_id | int unsigned |
| language_name | varchar(40) |
| language_code | varchar(10) |
| language_is_active | tinyint |
| language_created_at | timestamp |
| language_updated_at | timestamp |

### books
Admin-managed library catalog; files in storage/books and storage/covers; is_active=0 hides a book from the app.

| Column | Type |
|---|---|
| book_id | int unsigned |
| book_title | varchar(200) |
| book_author | varchar(150) |
| book_description | text |
| book_category_id | int unsigned |
| book_language_id | int unsigned |
| book_format | enum('pdf','epub') |
| book_file_path | varchar(80) |
| book_file_name | varchar(255) |
| book_file_size | int unsigned |
| book_file_hash | char(64) |
| book_cover_path | varchar(80) |
| book_cover_mime | varchar(20) |
| book_is_active | tinyint |
| book_version | int unsigned |
| book_admin_id | int unsigned |
| book_created_at | timestamp |
| book_updated_at | timestamp |

## Android (SQLite)

### users
Local accounts (email+password, or guest).

| Column | Type |
|---|---|
| id | TEXT |
| display_name | TEXT |
| email | TEXT |
| secret_hash | TEXT |
| secret_salt | TEXT |
| remote_id | TEXT |
| created_at | INTEGER |
| updated_at | INTEGER |
| last_login_at | INTEGER |
| first_name | TEXT |
| last_name | TEXT |
| secret_kind | TEXT |
| security_question | TEXT |
| security_answer_hash | TEXT |
| security_answer_salt | TEXT |
| is_guest | INTEGER |
| profiling_completed | INTEGER |
| fingerprint_enabled | INTEGER |
| synced | INTEGER |
| server_id | TEXT |

### preferences
Key/value settings per user; user_id='device' for settings chosen before any account.

| Column | Type |
|---|---|
| user_id | TEXT |
| key | TEXT |
| value | TEXT |
| updated_at | INTEGER |

### documents_legacy
Old Reading History.

| Column | Type |
|---|---|
| id | INTEGER |
| user_id | TEXT |
| title | TEXT |
| full_text | TEXT |
| source_type | TEXT |
| language | TEXT |
| created_at | INTEGER |
| updated_at | INTEGER |
| last_opened_at | INTEGER |
| last_position | INTEGER |
| thumbnail_path | TEXT |

### usage_logs
Anonymized usage events (no user id) with a random per-install session id; uploaded_at marks upload.

| Column | Type |
|---|---|
| id | INTEGER |
| session_id | TEXT |
| event_type | TEXT |
| screen | TEXT |
| input_mode | TEXT |
| payload | TEXT |
| created_at | INTEGER |
| uploaded_at | INTEGER |

### outbox
Generic offline upload queue (report, feedback, sus, usage_logs, account_sync).

| Column | Type |
|---|---|
| id | INTEGER |
| type | TEXT |
| payload | TEXT |
| status | TEXT |
| attempts | INTEGER |
| last_error | TEXT |
| next_attempt_at | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |

### sus_responses
System Usability Scale results; answers = JSON array of ten 1..5 ints.

| Column | Type |
|---|---|
| id | INTEGER |
| user_id | TEXT |
| answers | TEXT |
| score | REAL |
| language | TEXT |
| input_mode | TEXT |
| created_at | INTEGER |

### wer_results
Word Error Rate evaluation runs for speech recognition.

| Column | Type |
|---|---|
| id | INTEGER |
| session_id | TEXT |
| locale | TEXT |
| on_device | INTEGER |
| reference | TEXT |
| hypothesis | TEXT |
| substitutions | INTEGER |
| deletions | INTEGER |
| insertions | INTEGER |
| reference_words | INTEGER |
| wer | REAL |
| created_at | INTEGER |

### login_attempts
Failed-login counters so the lockout survives restarts.

| Column | Type |
|---|---|
| key | TEXT |
| failures | INTEGER |
| locked_until | INTEGER |
| updated_at | INTEGER |

### library_items
One row per thing on the shelves: the user's own documents and, per user, each downloaded/catalog admin book (progress is per user).

| Column | Type |
|---|---|
| id | TEXT |
| user_id | TEXT |
| source | TEXT |
| format | TEXT |
| language | TEXT |
| title | TEXT |
| author | TEXT |
| cover_path | TEXT |
| file_path | TEXT |
| text_ref | TEXT |
| full_text | TEXT |
| text_path | TEXT |
| chapters | TEXT |
| total_sentences | INTEGER |
| word_count | INTEGER |
| chapter_index | INTEGER |
| sentence_index | INTEGER |
| percent | REAL |
| finished | INTEGER |
| last_opened_at | INTEGER |
| created_at | INTEGER |
| updated_at | INTEGER |
| book_id | TEXT |
| book_version | INTEGER |
| remote_version | INTEGER |
| category | TEXT |
| description | TEXT |
| cover_url | TEXT |
| file_size | INTEGER |
| downloaded | INTEGER |
| is_new | INTEGER |
| unavailable | INTEGER |
| local_only | INTEGER |
| synced | INTEGER |
| legacy_id | INTEGER |

### library_favorites
Saved spots (bookmarks) inside a library item.

| Column | Type |
|---|---|
| id | TEXT |
| item_id | TEXT |
| chapter_index | INTEGER |
| sentence_index | INTEGER |
| label | TEXT |
| created_at | INTEGER |
| updated_at | INTEGER |
| synced | INTEGER |

### library_collections
The user's own named groups of library items.

| Column | Type |
|---|---|
| id | TEXT |
| user_id | TEXT |
| name | TEXT |
| created_at | INTEGER |
| updated_at | INTEGER |
| synced | INTEGER |

### library_collection_items
Junction table: M:N between library_collections and library_items.

| Column | Type |
|---|---|
| collection_id | TEXT |
| item_id | TEXT |
| added_at | INTEGER |
| synced | INTEGER |

### percy_turns
One row per sentence said to Percy, with predicted intent, for retraining the classifier.

| Column | Type |
|---|---|
| id | INTEGER |
| user_id | TEXT |
| text | TEXT |
| intent | TEXT |
| confidence | REAL |
| outcome | TEXT |
| screen | TEXT |
| model_version | TEXT |
| created_at | INTEGER |

### issue_reports
Every 'Mag-report ng problema' is saved here first, then sent to the dashboard.

| Column | Type |
|---|---|
| id | TEXT |
| ticket_no | TEXT |
| user_id | TEXT |
| type | TEXT |
| module | TEXT |
| severity | TEXT |
| description | TEXT |
| email | TEXT |
| app_version | TEXT |
| os_version | TEXT |
| device_model | TEXT |
| source_screen | TEXT |
| created_at | INTEGER |
| sync_status | TEXT |
| server_id | TEXT |
| attempts | INTEGER |
| last_error | TEXT |
| server_status | TEXT |
