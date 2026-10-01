# Auth: Welcome, Register, Login (Phase 6B)

Mockups: `docs/ui/welcome screen.png`, `registration_form.png`, `register_confirmation.png`,
`login_form.png`, `login_confirmation.png`. **Mockup wording wins** over this file.

## Welcome
- Eye logo (reusable `EyeLogo` widget, top of every screen that shows it in the mockups),
  "Welcome to / Percipere", subtitle "An app built on your behalf".
- Speaking Zone: "Meron ka na bang account? Kung wala pa, mag-register ka." (mockup shows
  the first sentence; the full text is spoken).
- Buttons: **Login** (primary), **Register** (secondary), **Subukan muna (Try first)**
  (smaller, white).
- Navigation mode isn't chosen yet → **voice and gestures both active** on Welcome,
  Register and Login. Announcement explains both, e.g. "Sabihin ang 'login', 'register', o
  'subukan', o mag-swipe para pumili at mag-double-tap para pindutin."
- No Gesture Pad on Welcome: the whole screen is the gesture surface.
- The voice/gesture choice moves to profiling Step 1 (see `profiling.md`).

## Register
- Fields (mockup): **First Name, Last Name, Email Address, Password**, then **Submit**.
- Then: security question (chosen from a short spoken list, answered by voice or typing).
- Spoken prompts must match the fields exactly.

## Login
- Fields: **Email Address, Password**, then **Submit**.
- If fingerprint login is enabled for the remembered account: try fingerprint first, fall
  back to the password.

## Form behavior (every form screen)
- Each field can be filled by **voice dictation or typing**.
- Per field: speak the field name → listen (or wait for typing) → read back what was heard
  for confirmation. **Password: only the number of characters is confirmed, never the text.**
- Spelled emails by voice: "at" → `@`, "dot" → `.` (also "tuldok").
- Submit: **double-tap the Gesture Pad** or say **"submit" / "tapos na"** — shown as the
  hint "Pindutin ng dalawang beses ang gesture area o sabihin ang salitang submit or tapos
  na" (mockup), used on every form screen.
- Validation (spoken clearly): valid email format; password ≥ 8 characters; email not
  already used on this device.

## Storage
- `users` table (new migration): UUID id, first/last name, email (unique, used as the
  username — emails can't be verified offline), password hash + salt, security question
  id + answer hash (answer normalized: lowercase, no diacritics/punctuation, trimmed),
  `is_guest`, `profiling_completed`, `synced`, `server_id`, `created_at`, `updated_at`,
  `last_login_at`, lockout fields.
- Passwords: salted, slow hash (PBKDF2-HMAC-SHA256, per-user random salt). Never stored or
  logged in plain text.
- `AccountSyncRepository` interface + mocked implementation (no real sync until Phase 7).
- Remove the name + 4-digit PIN system and its code. Existing PIN accounts are migrated:
  they must set an email and password at their next login (see decisions.md for how).

## Session
- "Stay logged in" on by default; session (user id) stored with `flutter_secure_storage`.
- **Fingerprint (optional):** after registration, offer fingerprint login (`local_auth`).
  Not offered to guests.

## Forgot password
- Answer the security question set at registration → set a new password.
- Also say that the administrator can reset the account (built with the web app later).

## Lockout
- After **5** failed attempts: **30 s** wait, **doubling** on each further failure, with a
  spoken countdown. Stored per email so it survives an app restart.

## After auth
- After **registering** → profiling.
- After **logging in** → Capture, or profiling if this account never completed it.
