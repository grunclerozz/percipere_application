-- =====================================================================
-- Percipere - PROPOSED database changes.  *** NOT EXECUTED. DO NOT RUN AS ONE SCRIPT. ***
-- Written during a read-only analysis; nothing here has been applied to any database,
-- and no source file or migration was modified.
--
-- PART A is MariaDB 10.4 (the dashboard, database percipere_dashboard, schema 12).
-- PART B is SQLite (the Android app, percipere.db, currently v7) and is meant to become
--         a NEW migration `_v8` in lib/core/db/migrations.dart (never edit shipped ones).
-- Every statement is commented out and names the issue it fixes.
-- See database-masterlist.md sections 5.3 and 7.
-- Take a backup first (mysqldump -u root percipere_dashboard > backup.sql).
-- =====================================================================


-- =====================================================================
-- PART A - SERVER (MariaDB)
-- =====================================================================

-- ---------------------------------------------------------------------
-- A1. [Decision 1] Remove the 7 legacy personal columns from `members`.
--     Issue: live `members` still has 13 columns; database.sql v12 has 6. The columns may
--     hold real personal data and nothing in the dashboard reads them.
--     This is EXACTLY docs/migrations/v12_remove_personal_columns.sql (percipere_web,
--     branch fix/webapp-api). DESTRUCTIVE, no undo - back up first. The to-be ERD assumes it.
-- ---------------------------------------------------------------------
-- ALTER TABLE members
--     DROP COLUMN IF EXISTS member_age,
--     DROP COLUMN IF EXISTS member_sex,
--     DROP COLUMN IF EXISTS member_address,
--     DROP COLUMN IF EXISTS member_photo,
--     DROP COLUMN IF EXISTS member_bio,
--     DROP COLUMN IF EXISTS member_experiences,
--     DROP COLUMN IF EXISTS member_contribution;


-- ---------------------------------------------------------------------
-- A2. [Decision 1] The three admin foreign keys that database.sql has but the live DB lacks.
--     Issue: feedback / notes / audit rows can point at a deleted admin (orphan *_admin_id).
--     Same as docs/migrations/v3_admin_fks.sql. That file warns: on MariaDB 10.4 run it after
--     the schema upgrade AND after restarting MySQL (it crashed the server once).
--     Pre-checks - each must return 0 rows or the ALTER fails:
--       SELECT feedback_id FROM feedback       WHERE feedback_admin_id IS NOT NULL AND feedback_admin_id NOT IN (SELECT admin_id FROM admins);
--       SELECT note_id     FROM feedback_notes WHERE note_admin_id     IS NOT NULL AND note_admin_id     NOT IN (SELECT admin_id FROM admins);
--       SELECT log_id      FROM audit_log      WHERE log_admin_id      IS NOT NULL AND log_admin_id      NOT IN (SELECT admin_id FROM admins);
-- ---------------------------------------------------------------------
-- ALTER TABLE feedback
--     ADD CONSTRAINT fk_feedback_admin
--     FOREIGN KEY (feedback_admin_id) REFERENCES admins(admin_id) ON DELETE SET NULL;
--
-- ALTER TABLE feedback_notes
--     ADD CONSTRAINT fk_feedback_notes_admin
--     FOREIGN KEY (note_admin_id) REFERENCES admins(admin_id) ON DELETE SET NULL;
--
-- ALTER TABLE audit_log
--     ADD CONSTRAINT fk_audit_admin
--     FOREIGN KEY (log_admin_id) REFERENCES admins(admin_id) ON DELETE SET NULL;


-- ---------------------------------------------------------------------
-- A3. [Decision 3 - FLAGGED ISSUE] audit_log.log_member_id is ON DELETE CASCADE.
--     Issue: deleting a team member silently deletes every audit entry that member made,
--     which defeats an audit log. log_member_id is already nullable, so SET NULL is safe:
--     the row keeps log_action, log_created_at and (after A2) log_admin_id.
--     Live constraint name: fk_audit_member (members.member_id, ON UPDATE RESTRICT).
-- ---------------------------------------------------------------------
-- ALTER TABLE audit_log DROP FOREIGN KEY fk_audit_member;
-- ALTER TABLE audit_log
--     ADD CONSTRAINT fk_audit_member
--     FOREIGN KEY (log_member_id) REFERENCES members(member_id) ON DELETE SET NULL;
--
-- NOTE: database.sql (fix/webapp-api) also declares ON DELETE CASCADE here. Change it there
-- (and in includes/schema.php if it creates the constraint), or fresh installs will bring the
-- cascade back.


-- ---------------------------------------------------------------------
-- A4. [DECIDED: RESTRICT] admins.admin_role_id has NO foreign key in any schema file (only a
--     comment).
--     Issue: an admin can reference a role that does not exist.
--     RESTRICT because the dashboard never deletes roles (three fixed seed roles), permissions and
--     the "last super_admin" guard depend on the role, and an admin with a NULL role would be
--     silently powerless. Deleting a role still in use is therefore refused.
--     Pre-check (must return 0 rows):
--       SELECT admin_id FROM admins WHERE admin_role_id IS NOT NULL AND admin_role_id NOT IN (SELECT role_id FROM roles);
-- ---------------------------------------------------------------------
-- ALTER TABLE admins
--     ADD CONSTRAINT fk_admins_role
--     FOREIGN KEY (admin_role_id) REFERENCES roles(role_id) ON DELETE RESTRICT;


-- ---------------------------------------------------------------------
-- A5. [DECIDED: SET NULL, same issue as A3] feedback_notes.note_member_id is ON DELETE CASCADE:
--     settings.php (action delete_member) deletes a team member with no cleanup, which silently
--     deletes every internal note they wrote. The note text is the record of why a report was
--     handled, so keep it and lose only the attribution. Column is nullable.
--     Live constraint name: fk_feedback_notes_member.
--     Also change it in database.sql / includes/schema.php of the web repo (see A3 note).
-- ---------------------------------------------------------------------
-- ALTER TABLE feedback_notes DROP FOREIGN KEY fk_feedback_notes_member;
-- ALTER TABLE feedback_notes
--     ADD CONSTRAINT fk_feedback_notes_member
--     FOREIGN KEY (note_member_id) REFERENCES members(member_id) ON DELETE SET NULL;


-- =====================================================================
-- PART B - ANDROID (SQLite) - proposed migration `_v8`, "Remove deprecated tables"
-- Not valid MariaDB. Each statement would be one entry in Migration(8, ..., [ ... ]).
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1. [Decision 2] outbox is deprecated.
--     Issue: designed as the offline upload queue, but no code reads or writes it;
--     issue_reports has its own retry columns (sync_status, attempts, last_error).
--     Dropping the table also drops idx_outbox_due.
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS outbox;

-- ---------------------------------------------------------------------
-- B2. [Decision 2] usage_logs is deprecated.
--     Issue: never read or written by app code; the server has no usage table.
--     Dropping the table also drops idx_usage_logs_uploaded.
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS usage_logs;

-- ---------------------------------------------------------------------
-- B3. [Decision 2] documents_legacy is deprecated.
--     Issue: safety copy of the old Reading History left by migration v4 ("a later migration
--     drops it"); its rows were copied into library_items. IRREVERSIBLE on a device that still
--     needs the safety copy - confirm the Library tablet test passed first.
--     Dropping the table also drops its FK to users and idx_documents_user_created.
-- ---------------------------------------------------------------------
-- DROP TABLE IF EXISTS documents_legacy;

-- ---------------------------------------------------------------------
-- B4. [OPTIONAL, follows B3] library_items.legacy_id points at documents_legacy.id with no FK;
--     it is a dead column once B3 runs.
--     DROP COLUMN needs SQLite >= 3.35, which older Android versions do not ship; the safe route
--     is the table-rebuild pattern used by migration v3.
-- ---------------------------------------------------------------------
-- ALTER TABLE library_items DROP COLUMN legacy_id;

-- ---------------------------------------------------------------------
-- Kept per decision 2 (no change): sus_responses, wer_results.
-- Not proposed (undecided): users.remote_id vs server_id duplicate; CHECK constraints on
-- secret_kind / sync_status / server_status; library_items.chapters as a child table.
-- ---------------------------------------------------------------------
