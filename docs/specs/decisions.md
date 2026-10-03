# Decision log

Newest first. **Proposed** = awaiting the user's approval; becomes **Decided** once approved.
## 2026-10-03 — Reader text size on the Document Box, not the Gesture Pad
- Asked to make two-finger swipe up/down the text-size gesture. That would have removed
  previous/next paragraph from the pad, so the user chose instead: **pinch to zoom in the
  Document Box**, plus A−/A+ buttons and voice — the pad's gestures stay unchanged.
  Profiling Step 2 is unchanged too (single-finger swipes + voice).
- Voice listening loop: sessions are logged (`[Voice …]` in logcat); restarts wait for the
  previous session to finish, back off (0.4 s → 5 s) after instant failures, step down
  through on-device → online → the phone's default locale, and after 3 identical failures
  stop and say so (`voiceRepeatedError`). Sessions are now `listenFor` 30 s,
  `pauseFor` 4 s (5 s for dictation).


## 2026-10-01 — Review: no overlaps, no page scrolling
- Review finding: screens overlapped or needed scrolling when the text got bigger.
- **The text size setting now enlarges only the reading text** (Reader's Document Box,
  setup preview), at exactly 18–48 sp, inside its box, which scrolls. Buttons, fields
  and all other boxes keep their design size; replaces proposed decision 4 ("all other
  UI text scales by size / 18").
- Text never grows a box: longer text shrinks to fit (Speaking Zone subtitle 3 lines,
  2 on forms; button labels 1 line). Android's own font size applies to UI text up to
  1.3×.
- Long lists (security questions, setup summary, old accounts) scroll inside a fixed
  box; the main button stays visible.
- Setup Steps 2, 3 and 7 follow their mockup: logo, preview box, Speaking Zone,
  Gesture Pad (no value line or Okay button; confirm by double-tap / "okay").
- Capture: Kasaysayan and Mga Setting side by side.
- Login: extra links (fingerprint, forgot password, old account) two per row.
- Fix: "Ulitin ang setup" now gives guests the full setup (was their short one).

## 2026-10-01 — Phase 6B implementation notes
- Step 1 wording follows the mockup ("Paano mo gustong mag-navigate sa app?"), not the
  prompt text; its layout is the `how_do_they_want_to_use` mockup (no Gesture Pad).
- The "can you see text?" question shares number 2 with Text size ("Hakbang 2 ng 10").
  Guests' short setup is numbered 1–4. A registered ex-guest's setup is numbered over
  the steps still to do.
- Dictated passwords are lowercased with spaces removed (recognizers capitalize and
  space words unpredictably); typed passwords are kept exactly.
- A dictated value fills the focused field unless it is *exactly* a command phrase
  ("tapos na", "bumalik", …), so names are never mistaken for commands.
- Lockout also applies to security-answer guesses (own counter per email). Submitting
  while locked clears the password and asks for it again when time is up.
- Skip on Step 1 sets gestures (long-press still opens voice).
- Back on the first setup step offers to log out and return to Welcome; in "Ulitin ang
  setup" it returns to Settings.
- Logout keeps the user's look and voice on the device (low-vision users shouldn't lose
  their text size on the login screen).
- Legacy PIN accounts lose their (unverified) email in the migration and set one when
  upgrading; they then set a security question and do the setup.
- Saying a Settings row's name opens it only for rows that open something (Logout,
  Ulitin ang setup, Fingerprint); values change only by swipe/double-tap.
- ~~UI text scaling is capped at 2× (36 sp); document text goes to 48 sp.~~
  Superseded by the review entry above.
- Tests: one in-memory database per test; `tool/test_each.sh` runs each file and retries
  `flutter_tester` crashes (the overscroll crash above was one real cause).

## 2026-10-01 — Phase 6B planning

**Decided**
- Phase 6 approved and done. Phases 7–8 postponed. Current phase: **6B (Registration,
  Login, Profiling)**.
- Mockups in `docs/ui/` win over prompt wording.
- Name + 4-digit PIN accounts are replaced by email + password.
- Text colors per theme as listed in `profiling.md`; all verified ≥ 7:1 (lowest: Asul
  #0D47A1 on cream, 7.87).

**Decided** — proposed in the 6B plan, all 14 approved by the user on 2026-10-01
1. **Paragraph gestures in the Reader.** Two-finger swipe right becomes "back" everywhere,
   so the Reader's paragraph gestures move: **two-finger swipe down = next paragraph,
   two-finger swipe up = previous paragraph** (two-finger swipe down is no longer "back").
   Two-finger swipe left: unassigned. Voice "susunod/nakaraang talata" unchanged.
2. **Reader taps.** Auto-read off says "Mag-double-tap para simulan ang pagbasa", but today
   double-tap = repeat sentence and tap = play/pause. Proposal: **double-tap = read /
   pause**, **single tap = repeat the current sentence**. (Alternative: double-tap starts
   reading only before the first play, then keeps "repeat".)
3. **Themes: 3 instead of 4.** Cream & Navy, Dark mode with yellow text, Dark mode with
   white text (backgrounds: cream #F8F4EC, black #000000, black #000000). The old
   "Black on white" palette is dropped; saved settings using it fall back to Cream & Navy.
   Text color becomes its own setting (per-theme list); headings, body and document text
   use it.
4. **Text size in sp.** Stored as an absolute size **18–48 sp, step 2**, default 18.
   Document text uses it directly; all other UI text scales by size / 18 (so the default
   looks like today). Replaces the 80–200 % multiplier.
5. **Speed and pitch steps of 0.25** everywhere (profiling, Settings, Reader swipes) —
   was 0.1.
6. **Step 4 "boses sa Ingles o Tagalog" = the app's spoken language** (prompts + UI text,
   like today's "Wika"). The document voice stays automatic (per-document detection),
   still overridable in Settings.
7. **Microphone on Welcome.** Voice must work on Welcome before any mode is chosen, so on
   first launch the app explains, then asks for microphone permission right after the
   Welcome intro. If refused, gestures work and the intro says so.
8. **Mockup screens `login_confirmation` / `register_confirmation`** ("Nais mo bang mag
   login sa iyong account?" with Login + Register buttons). Where they appear in the flow
   isn't stated. Shown **after logging out** (and when the session expires), so the user
   can log back in or register another account.
9. **Register prompt wording.** The mockup's Speaking Zone says "Ano ang iyong palayaw or
   last name?" while the fields are First Name / Last Name. Per-field prompts are used:
   "Ano ang iyong pangalan (first name)?" / "Ano ang iyong apelyido (last name)?" /
   "Ano ang iyong email address?" / "Gumawa ng password na hindi bababa sa 8 titik."
10. **PIN-account migration.** On first launch after the update, a *logged-in* legacy PIN
    account is asked (by voice) to set an email and password, keeping its settings and
    history. Logged-out legacy accounts appear on Login as "Lumang account" and can be
    claimed once with their old PIN, then must set email + password. After claiming, all
    PIN code is removed. (No real users have PIN accounts yet, so a simpler "drop legacy
    accounts" is also acceptable.)
11. **Password hash:** PBKDF2-HMAC-SHA256, 100 000 iterations, 16-byte random salt
    (stronger than the old PIN's SHA-256 × 10 000), run in an isolate.
12. **Security questions** (spoken list, pick by swipe/voice): first pet's name; town of
    birth; mother's maiden name; first school; favorite food.
13. **New packages:** `flutter_secure_storage`, `local_auth`. `local_auth` needs
    `MainActivity` to extend `FlutterFragmentActivity`.
14. **Git:** initialize the repository with a baseline commit of Phases 1–6 *before*
    6B work starts, so 6B is reviewable as a diff; commit again at the end of 6B.

## 2026-09-30 — Phase 6
- Settings are one `AppSettings` model persisted per scope (user id or `device`), one
  preference key per field; theme/locale/mode/speed/haptics providers are views of it.
- Verbosity levels: brief / normal / detailed.
- History options via swipe up; search via "hanapin X".
- Capture got two extra options (Kasaysayan, Mga Setting) as stacked outlined links.
- Test DB: one shared in-memory SQLite per test process, wiped per test.
- Windows `flutter_tester` crashes randomly (0xC0000005) in any file; not our code.

## 2026-09-30 — Phase 5
- Reader reads with TTS directly, one sentence per call; token tells own pause/skip from
  external interruption. Documents auto-saved to history; resume by sentence index.
- Reading waits for a tap / "basahin" after load (no auto-start) — superseded by 6B's
  auto-read setting.
- Taglish documents use the Filipino voice.

## 2026-09-30 — Phase 4
- PDF via `pdfrx` (MIT) instead of Syncfusion (license key).
- Camera auto-capture after 4 clear frames; photos deleted after extraction.
- Filipino ARB strings avoid ICU plural (Filipino "one" covers 2, 3, 5…).

## 2026-09-30 — Phases 1–3
- Riverpod 3 with hand-written providers (no codegen); `go_router`; `sqflite`.
- Fonts bundled (no `google_fonts`). App id `ph.bataan.percipere`, minSdk 24,
  compileSdk 37.0.
- Speaking Zone = the prompt's "InteractionPanel".
- Voice: on-device first, online fallback; mic permission only after a spoken explanation;
  auto-listen pauses after 60 s idle.
- Our navigation-mode enum is `NavMode` (Flutter has `NavigationMode`).
