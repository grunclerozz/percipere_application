# Open questions - not determinable from the code

Updated after your decisions of 2026-10-13. Resolved items are in the table at the bottom and removed from the lists.

## Server (MariaDB)
1. **Update the schema sources too:** `database.sql` (and possibly `includes/schema.php`) on `fix/webapp-api` still declare `audit_log.log_member_id ... ON DELETE CASCADE`; without a change there, fresh installs bring the cascade back. Who updates the web repo?
2. **`feedback_member_id` vs `feedback_admin_id`:** both record who last changed a report. Is `feedback_member_id` legacy and to be retired?
3. **Status vocabulary:** server `feedback_status` is ENUM('Open','In Progress','Resolved'); the app sees open/in_progress/resolved/closed ('closed' = archived). Is a real 'Closed' status wanted?
4. **Password hash on `app_users.user_password_hash`:** algorithm not read (inferred bcrypt, like admins). Confirm.
5. **`feedback_source = 'seed'`:** still used? Should seed rows exist in production?
6. **When will `v12_remove_personal_columns.sql` and `v3_admin_fks.sql` actually be applied?** The ERD assumes them. Also open from CLAUDE.md: git history still holds the old personal data.

## Android (SQLite)
7. **Confirm the placeholders I filled in for decision 2:** `outbox`, `usage_logs`, `documents_legacy` are *excluded* from `erd-android.mmd` (kept, tagged "deprecated", in the masterlist and CSV); `sus_responses` and `wer_results` are *kept*. Say if you wanted the opposite.
8. **Is it safe to drop `documents_legacy` (B3)?** It is the "safety copy until the user confirms nothing was lost". Has the Library tablet test passed on every device in use?
9. **`users.remote_id` vs `users.server_id`:** duplicate columns; which stays?
10. **Planned Phase 7 sync** (`library_favorites`, `library_collections`, progress; `synced` columns): will it need new server tables? None exist, so they are Android-only in the ERD. `docs/api-contract.md` says only admin-book data syncs.
11. **`library_items.book_id`** is TEXT while `books.book_id` is INT. Change to INTEGER?
12. **Guests:** are guest accounts (`users.is_guest = 1`) ever sent to the server? `app_users` has no guest flag (`feedback.feedback_reporter_kind` does).
13. **Unconstrained value sets** (`secret_kind`, `sync_status`, `server_status`, `percy_turns.outcome`, report `type/module/severity` codes): authoritative lists live in app code. Add CHECKs?
14. **Room is not used** (the app uses `sqflite`); if Room is planned, entities would need to be created.

## Process
15. **The live DB analysed is the local XAMPP instance only** (no books, app users or feedback rows). Is production the same?

## Resolved by your answers (removed from the lists above)
| Was | Answer |
|---|---|
| Run `v12_remove_personal_columns.sql`? | ERD target assumes it is applied; **not run**. Still open: *when* (item 6) |
| Apply `v3_admin_fks.sql`? | ERD target assumes it is applied; **not run** |
| `audit_log` cascade on team-member deletion | Flagged; proposed fix `ON DELETE SET NULL` (A3). The same fix for `feedback_notes` is decided in the row below |
| Unused tables `outbox`, `usage_logs`, `documents_legacy` | Deprecated: excluded from the ERD, drops proposed in B1-B3. Whether the outbox is the intended sync mechanism is no longer open |
| `sus_responses`, `wer_results` | Kept |
| `admins.admin_role_id` has no FK | Decided: FK with **ON DELETE RESTRICT** (A4); shown as a solid line in `erd-server.mmd` |
| Same cascade on `feedback_notes.note_member_id` | Decided: fix to **ON DELETE SET NULL** (A5); flagged in `erd-server.mmd` like `audit_log` |
| Drop `library_items.legacy_id` | Follows `documents_legacy`; optional B4 |
