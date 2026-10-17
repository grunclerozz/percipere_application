# 09 — Environment

Names of settings only. **Never put real passwords, keys, tokens, SMTP credentials or personal
data in code or docs.**

## Tools (dev PC, Windows)
| Tool | Version / location |
|---|---|
| Flutter | 3.47.5 stable, Dart 3.13.4 |
| Android SDK | platform android-37, build-tools 37.0.0 (`%LOCALAPPDATA%\Android\sdk`) |
| JDK | OpenJDK 25 bundled with Android Studio (from `flutter doctor -v`); `java` is not on PATH |
| Gradle | 9.3.1 wrapper; heap 4 GB (`android/gradle.properties`, keep it) |
| Python | 3.12 at `%LOCALAPPDATA%\Programs\Python\Python312\python.exe` (on 2026-10-16 `python` resolved to it in Git Bash; use the full path if not found). Percy venv `scripts/percy/.venv`; model-conversion scripts `tool/voice_models/` (own venv, see its README) |
| XAMPP | Apache + MySQL for the dashboard (`C:\xampp\htdocs\website\percipere_web\percipere_dashboard`); the user starts/stops it |
| Git Bash | used for `tool/test_each.sh` |

## Project paths
- App repo: `D:\Development\Flutter Projects\percipere_app` — **the path has a space; always quote it**.
- Dashboard (separate repo, XAMPP): `C:\xampp\htdocs\website\percipere_web\percipere_dashboard`.
- `percipere/` inside the app repo = stray old project, excluded from analysis — ignore it.
- Old prototype backup (outside the repo): `..\percipere_app_prototype_backup\`.

## Running commands on Windows (both agents)
- PowerShell 5.1 and Git Bash are both installed. `tool/test_each.sh` needs **bash**
  (`bash tool/test_each.sh`). In PowerShell 5.1 chain commands with `;`, not `&&`.
- `flutter`, `dart` and `git` are on PATH; `adb` and `java` may not be (full paths below and in
  `flutter doctor -v`).
- The full test suite takes about 1–1.5 h and a release build several minutes: run them in the
  background or with a long timeout.
- Don't run `flutter test` and `flutter build` at the same time.

## Devices
- **Tablet:** Samsung Galaxy Tab S10 Lite (named in decision log 2026-10-14). The user installs
  and tests; agents never run the app on it.
- **Emulator:** AVD `Percipere_Light` (Android 14, Google TTS + speech, host GPU). Other AVDs
  present: `Light_AVD`, `Pixel_7_API_34`.

## Build flags (`--dart-define`, defined in `lib/config/env.dart`)
| Name | Meaning |
|---|---|
| `API_BASE_URL` | dashboard folder URL (`http://<PC_LAN_IP>/website/percipere_web/percipere_dashboard`); http also enables cleartext to that host |
| `API_CLEARTEXT_HOSTS` | extra comma-separated hosts allowed over http |
| `USE_ACCOUNT_SERVER` | `false` = phone-only accounts |
| `USE_MOCK_API` | default `true`: image description uses the mock |
| `PERCIPERE_DEV` | developer build: server address, ElevenLabs switch, Percy analysis panel, log export |
| `ELEVENLABS_AGENT_ID`, `ELEVENLABS_VOICE_ID`, `ELEVENLABS_USE_OVERRIDES`, `ELEVENLABS_TOKEN_URL`, `ELEVENLABS_APP_KEY` | developer-only ElevenLabs Percy; `ELEVENLABS_APP_KEY` is a secret — pass at build time, never commit |

## Environment variables
| Name | Used for |
|---|---|
| `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=D:\tmp\jdk` | fixes Gradle "Unable to establish loopback connection" |
| `PERCIPERE_LIVE_API`, `PERCIPERE_LIVE_HIDDEN_ID`, `PERCIPERE_MAIL_LOG` | live dashboard tests (`test_live/`) |
| `PERCIPERE_MODELS`, `SHERPA_DLL_DIR` | real offline-model test |
| `PERCIPERE_APP_KEY` | server side of the optional ElevenLabs token service (`assistant/server/`) |
Dashboard secrets (database, SMTP and any AI-service key; exact set unverified) live only in the dashboard's own config; this
repo does not need them.

## adb tips (`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`)
- App logs: `adb logcat -s flutter`. Useful prefixes: `[CAPTURE]` (build stamp, inputs),
  `[VOICE]` (listening plan, sessions), `[VOICE TIMING]` (debug builds), `[OFFLINE VOICE]`
  (model download/load, what the recognizer heard), `[TTS]`, `[PERCY]`, `[VOICE CHECK]`.
- Native model warnings: `adb logcat | grep sherpa-onnx`.
- Install: `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (keeps data).
- Start: `adb shell am start -n ph.bataan.percipere.app/ph.bataan.percipere.MainActivity`.
- Emulator reaches the PC as `10.0.2.2` (e.g. `API_BASE_URL=http://10.0.2.2:<port>` for a local server).
- In Git Bash, prefix `adb shell` commands with absolute device paths by `MSYS_NO_PATHCONV=1`.
