# Percy's intent classifier: training

Percy (Phase 9) understands sentences with an intent classifier the team trains here, on
`data/percy/intents.csv`. The app runs the exported model offline in pure Dart
(`lib/core/percy/`). Spec: `docs/specs/percy-local.md`.

## One-time setup (Windows, PowerShell, from the project folder)

Python 3.12 is installed on this PC but not on PATH, so call it by its full path:

```powershell
& "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe" -m venv scripts\percy\.venv
scripts\percy\.venv\Scripts\python -m pip install -r scripts\percy\requirements.txt
```

(On a PC where `python` or `py` works, use that instead of the full path.)

## Every time the dataset changes

```powershell
scripts\percy\.venv\Scripts\python scripts\percy\validate_dataset.py
scripts\percy\.venv\Scripts\python scripts\percy\train.py
```

`train.py` writes:

| File | What |
|---|---|
| `assets/percy/model.json` | The chosen model (the app uses this) |
| `assets/percy/model_alt.json` | The other model, for comparison |
| `data/percy/reports/report-<date>.md` | Metrics, tuning, examples, top words, mistakes |
| `data/percy/reports/confusion-<date>.png` | Confusion matrix of the test set |
| `scripts/percy/test_vectors.json` | 30 sentences the Dart test checks against |

`train.py` scores on the fixed team-written test set `data/percy/test_team.csv` (primary), then on an
all-data 70/15/15 split and 5-fold CV (secondary). It refuses to train (exit 2) until that file has
8+ team phrases for each new intent (`describe_image`, `more_detail`, `read_image_text`, `tutorial`,
`set_speed`). `--dry-run` evaluates only: nothing in `assets/percy/` is touched.
Training rows that match a test phrase after preprocessing must be removed (`validate_dataset.py`
reports them as leakage).

Then run the Dart check that the app reads the new model exactly like Python:

```powershell
flutter test test/core/percy/intent_classifier_test.dart
```

## The dataset

`data/percy/intents.csv` — columns `text, intent, author, source, notes`.

- `source = Starter (Claude)`: generated starter sentences. Anything else (e.g. `Team`) is
  written by the team; `STT log` rows come from the app's Percy log export.
- Intents (27, `report_issue` since Phase 10): open_home, open_library, open_settings, back, next_option, previous_option,
  select, cancel, help, where_am_i, read, pause, resume, stop, repeat, faster, slower,
  bigger_text, smaller_text, open_item, greeting, thanks, goodbye, yes, no, out_of_scope,
  report_issue.
- Rules: "bumalik" alone is `back`; "bumalik sa home/library/settings" is `open_home` /
  `open_library` / `open_settings`. "wag na" / "huwag na" is `cancel`; plain "hindi" /
  "ayoko" is `no`.
- Aim for 30+ sentences per intent, mostly written by the team; the validator warns below 30.
- Sentences that become the same after preprocessing (e.g. "salamat percy" and "salamat")
  count once.

## How it works (for the report)

1. Preprocessing (`percy_text.py`, mirrored in `lib/core/percy/percy_text.dart`): lowercase,
   fold accents, delete hyphens/apostrophes, other punctuation → space, drop the wake word
   "percy". Negation words (hindi, huwag, wag, ayoko, no, not) are kept.
2. Features: TF-IDF of word 1–2-grams and of character 3–5-grams inside each word
   (" basahen " shares most 3–5-grams with " basahin "), each block L2-normalized.
3. Models: Multinomial Naive Bayes and Logistic Regression, hyperparameters tuned by
   stratified 5-fold cross-validation on train + validation (mean macro F1); the better one
   is exported.
4. Split 70/15/15, stratified, seed 42. Exported models are trained on train + validation;
   the test set is only used for the report.
