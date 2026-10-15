# 02 — Features

Status words: **Done** = built, automated tests pass · **Done, not tablet-tested** = built and
tested on PC/emulator, waiting for the user's tablet test · **Partial** · **Mocked** ·
**Postponed** · **Broken**. Sources: `docs/features-summary.md` (13 Oct),
`docs/thesis/objectives-and-scope-draft.md` §1.1 (6 Oct, some statuses outdated),
`docs/specs/decisions.md`, `CLAUDE.md`. Almost everything after 7 Oct still waits for the first
full tablet test, so "tablet-tested" is never claimed below.

## Accounts and onboarding
| Feature | What it does | Code | Status |
|---|---|---|---|
| Welcome | Login / Register / "Subukan muna" (guest); asks for the mic once | `lib/features/welcome/welcome_screen.dart` | Done |
| First-launch voice download | Downloads offline voices + command model before Welcome, spoken progress | `lib/features/offline_voice/`, `lib/core/offline_voice/` | Done, not tablet-tested (models not yet uploaded) |
| Registration (server) | Name, email, password (≥ 8), 6-digit emailed code (dictated or typed) | `features/auth/register_screen.dart`, `verify_email_screen.dart`, `core/auth/account_service.dart` | Done, not tablet-tested |
| Registration (phone-only mode) | Local account + security question (when no server) | `features/auth/security_question_screen.dart` | Done |
| Login | Email + password, stay logged in, fingerprint, lockout 30 s doubling to 1 h | `features/auth/login_screen.dart`, `core/auth/login_throttle.dart`, `biometrics.dart` | Done |
| Offline login | Accounts already used on the tablet log in without internet | `core/auth/account_service.dart` | Done |
| Password reset | Emailed code (server) or security question (phone-only) | `features/auth/reset_password_screen.dart`, `forgot_password_screen.dart` | Done |
| Suspension check | Asks the server at start/login/resume; suspended → logged out with reason | `core/auth/session_guard.dart` | Done, not tablet-tested |
| Visible password + hide toggle | Visible by default (adviser), eye button; never spoken | `features/auth/voice_form.dart` | Done |
| Guest mode + upgrade | Full use without account; data moves to a new account | `core/auth/guest_reminders.dart`, `account_repository.dart` | Done |
| Old name+PIN accounts | Upgrade to email/password | `features/auth/legacy_account_screen.dart`, `upgrade_account_screen.dart` | Done |
| Account sync (old design) | Upload of local accounts | `core/auth/account_sync_repository.dart` | Mocked (superseded by server accounts) |
| Profiling (setup) | Spoken step-by-step setup: mode, speed (Mabagal/Katamtaman/Mabilis), pitch, text size, color, font, theme…; redo from Settings | `features/setup/` | Done |
| Tutorial | Starts with Percy's intro; once per account (guests once per device); replay by voice/Settings | `features/tutorial/tutorial_screen.dart` | Done, not tablet-tested |

## Navigation and accessibility
| Feature | Code | Status |
|---|---|---|
| Gesture Pad (swipes, double tap, long press, multi-finger) | `lib/core/gestures/`, `core/widgets/gesture_pad*.dart` | Done |
| Voice commands (≈35 app-wide + per-screen phrases, yes/no) | `lib/core/voice/`, `core/accessibility/command_bus.dart` | Done; offline engine new (see 03) |
| Voice / gesture mode ("pa-boses" / "pa-galaw") | `core/accessibility/navigation_mode.dart` | Done |
| Screen announcements, focus, help (three-finger tap / "tulong") | `core/accessibility/announcer.dart`, `focus_controller.dart` | Done |
| Back navigation (two-finger swipe right, "bumalik", Android back) | `app/router.dart`, `command_bus.dart` | Done |
| Speed strip beside the Gesture Pad | `core/widgets/speed_strip.dart` | Done, not tablet-tested |
| TalkBack support (announcements go to TalkBack) | `core/accessibility/announcer.dart` | Done |
| Themes (3 high-contrast), fonts (3 bundled), text size/color | `lib/app/theme/`, `config/palette.dart` | Done |

## Reading
| Feature | Code | Status |
|---|---|---|
| Capture menu (upload / camera / Maglarawan) | `features/capture/capture_screen.dart` | Done |
| Camera with spoken guidance + auto capture | `features/camera/` | Done |
| Upload JPG/PNG/PDF/DOCX (SAF, no storage permission) | `features/upload/document_picker.dart` | Done |
| OCR (ML Kit, on device) + cleanup | `core/ocr/` | Done |
| PDF text layer + OCR of scanned pages | `core/extraction/pdf_extractor.dart` | Done |
| DOCX extraction (no `.doc`) | `core/extraction/docx_extractor.dart` | Done |
| Reader: sentence highlight, play/pause, repeat, next/prev sentence and paragraph, from start, faster/slower, text size | `features/reader/` | Done |
| Language detection (fil/en/Taglish → reading voice) | `core/tts/language_detector.dart` | Done |
| Reading voice (female/male or by name), pitch | `core/tts/reading_voice.dart` | Done |
| Offline TTS voices (Tagalog, English) | `core/offline_voice/offline_speaker.dart` | Done, not tablet-tested |

## Aklatan (Library)
| Feature | Code | Status |
|---|---|---|
| Home (Magbasa ng bago / Aklatan) | `features/home/home_screen.dart` | Done, not tablet-tested |
| Shelves, search, filters, details, favorites, collections, chapters, progress | `features/library/`, `core/library/`, `core/db/daos/library_dao.dart` | Done, not tablet-tested |
| EPUB reading (images skipped) | `core/library/epub_parser.dart` | Done, not tablet-tested |
| Admin books from the dashboard (catalog, cover, read online, download with SHA-256, updates, removal) | `core/library/http_book_repository.dart`, `library_service.dart` | Done, not tablet-tested (dashboard DB has no books yet) |
| Library sync across devices (Phase 7) | `core/library/library_sync_repository.dart` | Mocked |
| Describing images inside EPUBs (Part B) | — | Postponed (wait for approval) |

## Maglarawan (image description)
| Feature | Code | Status |
|---|---|---|
| Offline labels → Filipino sentence, safety wording, read text found | `core/describe/`, `features/describe/` | Done |
| Consent before upload | `core/settings/app_settings.dart` (`DescribeConsent`) | Done |
| Detailed online description (Gemini via the dashboard) | `core/network/image_description_repository.dart` | Mocked (`USE_MOCK_API` default true; server endpoint not built) |
| Save a description to the Library | `features/describe/describe_controller.dart` | Done, not tablet-tested |

## Percy (assistant)
| Feature | Code | Status |
|---|---|---|
| Self-built intent classifier + dialogue manager, offline | `lib/core/percy/`, `assets/percy/` | Done, not tablet-tested |
| Stays in the conversation; 9 s reminder, 9 s more goodbye | `core/percy/percy_controller.dart` | Done, not tablet-tested |
| Percy analysis panel (developer builds) | `core/widgets/percy_analysis_panel.dart` | Done |
| Percy turn log + export | `core/db/daos/percy_log_dao.dart`, `core/percy/percy_log_export.dart` | Done |
| ElevenLabs Percy | `lib/core/assistant/`, `AssistantBridge.kt` | Developer-only, off by default |
| Percy offline listening (free speech) | — | Postponed ("Percy offline – later", `docs/todo.md`) |

## Reports and settings
| Feature | Code | Status |
|---|---|---|
| Report an Issue (one question per page, ticket `PRC-YYYYMMDD-XXXX`, retry offline) | `features/report/`, `core/report/` | Done, not tablet-tested |
| Aking mga report (ticket status from dashboard) | `features/report/my_reports_screen.dart` | Done, not tablet-tested |
| Settings (all rows, per account) | `features/settings/settings_screen.dart`, `setting_items.dart` | Done |
| Pagsusuri ng boses (Voice check, test, model status, re-download, delete) | `features/settings/voice_check_screen.dart` | Done, not tablet-tested |
| Server address (developer builds) | `features/settings/server_address_dialog.dart` | Done |

## Not built / postponed
| Item | Where planned | Status |
|---|---|---|
| Phase 6D algorithms: Laplacian blur check, Otsu, WER calculation | `docs/specs/algorithms.md` | Postponed |
| SUS questionnaire screen (`sus_responses` table exists) | Phase 7 | Postponed |
| Usage logs (`usage_logs` table exists, unused) | Phase 7 | Postponed |
| Phase 8 evaluation and polish | — | Postponed |
| "Turuan si Percy", document Q&A/summaries | `docs/features-summary.md` §5 | Planned |

No feature is currently known to be **Broken** in automated tests (all 81 test files pass,
2026-10-15). Tablet behaviour is unverified; see `06-known-issues-and-todo.md`.
