# Percy (self-built) — Phase 9

Status: **building (2026-10-10).** Requirements from the user (Intelligent Systems class):
replace the ElevenLabs Percy with **our own trained intent classifier**, fully offline, no
external AI API. Decisions: `decisions.md` (2026-10-10). Earlier ElevenLabs design:
`assistant.md` (kept, now a hidden developer option).

## Pipeline
speech-to-text (existing `speech_to_text`) → preprocessing → intent classifier → slot
extraction → dialogue manager → existing **CommandBus** action → response template → the
phone's TTS (the user's voice, speed and pitch, through the `Announcer`).

## 1. Dataset
- `data/percy/intents.csv`, columns `text, intent, author, source, notes`. 26 intents:
  open_home, open_library, open_settings, back, next_option, previous_option, select, cancel,
  help, where_am_i, read, pause, resume, stop, repeat, faster, slower, bigger_text,
  smaller_text, open_item, greeting, thanks, goodbye, yes, no, out_of_scope.
- Rows with `source = Starter (Claude)` are generated; the rest are the team's. The team keeps
  expanding the file: everything must work with the current file and improve when it is
  replaced (retrain with one command).
- Intent rules: "bumalik" alone = `back`; "bumalik sa home/library/settings" =
  `open_home` / `open_library` / `open_settings`. "wag na" / "huwag na" = `cancel`; plain
  "hindi" / "ayoko" = `no`. When Percy has asked a question, `no` and `cancel` are the same.
  On the Reader, `next_option` / `previous_option` = next / previous sentence (the Reader
  already maps `NavIntent.next/previous` to sentences).
- `scripts/percy/validate_dataset.py`: unknown intents, empty text, duplicates; counts per
  intent (team vs Starter), warning under 30.

## 2. Training (Python, scikit-learn) — `scripts/percy/train.py`
1. Load and validate the CSV.
2. Preprocess (`percy_text.py`, mirrored exactly in Dart): lowercase; fold accents
   (á→a, ñ→n…); delete hyphens and apostrophes ("i-cancel" → "icancel"); every other
   non-letter/digit → space; collapse whitespace; drop the wake word "percy" (and "hey"
   right before it). **Negation words are kept** (hindi, huwag, wag, ayoko, no, not).
3. Split 70/15/15 train/validation/test, stratified, seed 42.
4. Features: TF-IDF of word unigrams + bigrams, and TF-IDF of character 3–5-grams inside
   each word padded with spaces (catches "basahen"). Each block L2-normalized, then joined.
   The analyzers are our own functions (not scikit-learn's built-in tokenizers) so the Dart
   copy is exact.
5. Multinomial Naive Bayes vs Logistic Regression; NB `alpha`/`fit_prior` and LR
   `C`/`class_weight` tuned by stratified 5-fold cross-validation on train + validation
   (mean macro F1; the features are refit in every fold). Until 2026-10-11 they were tuned
   on the 15% validation set alone, but with ~77 sentences its winner changed by noise
   (decision log 2026-10-11 (2)).
6. Test-set evaluation: accuracy, per-intent precision/recall/F1, macro F1, confusion matrix
   (PNG), the cross-validation mean ± SD of the chosen settings, and test accuracy on team-written
   sentences only.
7. Report `data/percy/reports/report-<date>.md`: all metrics, examples per intent (team vs
   Starter), chosen model and why, top 10 informative features per intent, misclassified
   test sentences.
8. Export the chosen model to `assets/percy/model.json` (type, version, date, vocabulary,
   IDF, n-gram settings, labels, weights + bias, or log-probabilities + priors) and the other
   to `assets/percy/model_alt.json`.
9. `scripts/percy/test_vectors.json`: 30 sentences with preprocessed text, expected top
   intent and probabilities.
- `scripts/percy/requirements.txt`, `scripts/percy/README.md` (Windows commands).

## 3. On-device inference — `lib/core/percy/intent_classifier.dart`
Loads `model.json`, applies the same preprocessing and features, returns the top intents with
probabilities. Pure Dart. A unit test checks Dart against `test_vectors.json` (same top
intent, probabilities within 0.01). Prediction < 20 ms; logged with `[PERCY]`.

## 4. Confidence and hybrid matching
- Exact short commands keep using the existing matcher first (a verbatim command phrase in an
  utterance of at most 3 words).
- Otherwise the classifier: ≥ 0.60 act; 0.30–0.60 ask "Ang ibig mo bang sabihin ay
  [action]?"; < 0.30 or `out_of_scope` → "Hindi ko pa kaya iyan. Pwede mong sabihin…" with
  2–3 suggestions for the current screen. Thresholds in `lib/config/percy_config.dart`.
- If an intent's action isn't available on the current screen, Percy says so.

## 5. Slot extraction (rule-based) — `open_item`
Title words (after the verb) fuzzy-matched against the user's Library titles with the existing
`LibraryView.titleScore`: one match ≥ 0.7 → open; several → ask which (up to 3); none → say
so and offer the Library search. Ordinals: una/pangalawa/pangatlo/huli, first/second/third/
last, digits; "huli/last" alone = most recently opened.

## 6. Dialogue manager — `lib/core/percy/dialogue_manager.dart`
Frame-based. State: current screen, open document, last intent, pending question (yes/no or
choice), last 3 turns. Missing slot → ask (≤ 3 options), fill from the next answer ("yung
pangalawa"). Pending yes/no → the next yes/no/cancel answers it. Questions the app itself asks
(e.g. delete or logout confirmations) are spoken normally during Percy and answered the same
way: destructive actions are always confirmed. Every action goes through the CommandBus.

## 7. Responses and persona
`assets/percy/persona.json` (name, default politeness "po"/casual, talkativeness, greeting)
and `assets/percy/responses.json` (templates per intent, po and casual, Filipino and English,
2–3 variations). Settings: Percy's politeness (po / casual) and talkativeness (maikli /
katamtaman / madaldal). Spoken through the Announcer with the phone's TTS.
(Exception to the "all strings in ARB" rule, as specified: Percy's lines live in
`responses.json` so the team can edit them without touching code.)

## 8. Calling Percy; ElevenLabs
- Start: two-finger swipe left or "Percy" (also "Percy, buksan ang library" in one breath).
  End: `goodbye`, any gesture or tap (which does nothing else), or 60 s without speech.
  While Percy is on, the app listens after each reply, also in gesture mode. One voice only:
  Percy speaks through the app's own speech queue.
- Local Percy is the default and works offline. ElevenLabs is a hidden developer setting
  (shown only in builds made with `--dart-define=PERCIPERE_DEV=true`), off by default;
  nothing is sent to ElevenLabs unless it is turned on. The ElevenLabs consent text says it
  is the online developer option.

## 9. Logging for retraining
Each Percy turn is stored locally (Settings, on by default): sentence, predicted intent,
confidence, outcome (acted / confirmed / corrected / declined / asked / fallback), screen,
timestamp. No document content. A hidden evaluator action (developer builds) exports the
log as CSV in the dataset format with `source = STT log`, through the share sheet.

## 10. Tests
Preprocessing parity, test vectors, thresholds, slot matching, dialogue (missing slot,
yes/no, destructive confirm), out-of-scope, ElevenLabs off by default.

## Later (not this phase)
"Turuan si Percy", learning from corrections, TextRank summaries, BM25 document questions,
neural network. Designed for it: the classifier sits behind an interface (`IntentModel`),
the model file carries its type, and logged turns are already in the dataset format.
