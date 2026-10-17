# Percy smarter — handoff to Claude Code

**Status: paused 2026-10-16.** Branch: `feat/percy-smarter`. Codex stopped before
training, model export, or any change to `assets/percy/model.json`.

## Goal

Make Percy's self-built TF-IDF + Naive Bayes / Logistic Regression classifier and
Levenshtein matcher understand more Filipino, English, and Taglish app requests. Add
training coverage, safe normalization, intents that use existing app actions, and an
honest fixed team-only evaluation before exporting a new model.

## Done

- Routing foundation:
  - `describe_image` and `tutorial` route through existing `NavIntent`s and existing
    routes/actions in `lib/core/accessibility/command_bus.dart`.
  - `more_detail` and `read_image_text` invoke existing Maglarawan action IDs
    (`Ids.describeMore`, `Ids.describeReadText`) through `RunAction`; no screen or UI
    was added. See `lib/core/percy/dialogue_manager.dart`,
    `lib/core/percy/percy_controller.dart`, and `lib/core/percy/percy_intent.dart`.
  - `kasaysayan` / `history` remains mapped to `NavIntent.library`, the existing
    Aklatan route and its recent/history shelf; no Reading History screen exists.
- Exact named speed foundation:
  - `SpeechSpeed.slow`/`medium`/`fast` reuse setup's existing rates (0.75/1.0/1.5).
  - `mabagal`, `katamtaman`, `mabilis` and English equivalents are exact presets;
    `bagalan`/`mas mabagal`/`slower` and `bilisan`/`mas mabilis`/`faster` remain
    relative actions. The CommandBus persists the existing `readingRate` setting and
    speaks `setupSpeedChosen` at the new rate. See
    `lib/core/accessibility/command_bus.dart`, `lib/core/voice/voice_commands.dart`,
    and `lib/core/tts/reading_rate.dart`.
- Normalization foundation in both mirrored implementations:
  - lowercases and folds accents; corrects common STT spellings; removes `po`, `opo`,
    `pakisuyo`, `pakiusap`, `please`, `nga`, and `naman`.
  - never removes `hindi`, `huwag`, `wag`, `wag na`, `ayoko`, `no`, or `not`; preserves
    meaningful `ano` questions such as `ano ang kaya mo`; if removal empties the text,
    keeps the original normalized words.
  - files: `scripts/percy/percy_text.py`, `lib/core/percy/percy_text.dart`; tests in
    `test/core/percy/intent_classifier_test.dart`.
- Context handling: on `Ids.describe`, `read` resolves to the existing
  `describe.readText` action; away from Maglarawan, `read_image_text` resolves to
  document `read`. Tests are in `test/core/percy/dialogue_manager_test.dart`.
- Review-only data exists and has not been merged into training:
  - `data/percy/review/generated_for_review.csv`: 570 rows, `text,intent,note`.
    The approved allocation caps `open_library` and `open_settings` at 45 each;
    all other previously under-30 intents reach 30; each of the five new intents
    has 41 rows so the reviewed batch remains 570 rows.
  - `data/percy/test_team.csv`: 58 existing team rows plus empty comment sections for
    `describe_image`, `more_detail`, `read_image_text`, `tutorial`, `set_speed`.
    It is **not complete** despite an earlier claim in chat: inspect it before training.
- Conflict check on the review batch: 0 exact normalized cross-intent duplicates.
  138 near-pair candidates were found by a conservative string/token heuristic. Most
  are intentional opposites or adjacent controls (`palakihin`/`paliitin`,
  `bilisan`/`bagalan`, `ituloy`/`itigil`, `basahin`/`buksan`). Image-text phrases use
  image words; document reading uses document/file/book words. The team must remove
  unnatural rows during review; do not silently copy all rows.
- Training already uses Logistic Regression `class_weight=balanced`; retain that
  comparison and report the selected model from measured 5-fold CV.

## Checks at handoff

- `flutter analyze` was started twice but did not return within the tool window; Dart
  analyzer processes were still running. No final analyzer result is available.
- Percy-related tests were not started because the analyzer had not completed. Do not
  claim a passing quality check.
- No release build was run: this is an unfinished intermediate phase and no native plugin
  changed.

## Not done — resume in this order

1. Team adds about 10 natural, team-written phrases each to
   `data/percy/test_team.csv` for `describe_image`, `more_detail`,
   `read_image_text`, `tutorial`, and `set_speed`. It is currently empty for them.
2. Team finishes reviewing `data/percy/review/generated_for_review.csv`.
3. Leakage check: remove from training any row that matches a `test_team.csv` row after
   `preprocess`; report the count removed.
4. Copy only accepted generated rows into `data/percy/intents.csv`, with source
   `Generated (Codex)`.
5. Update `scripts/percy/validate_dataset.py` and `scripts/percy/train.py`:
   fixed team-only test set is the primary evaluation (accuracy, macro F1, per-intent
   scores, confusion matrix); all-data result is secondary; retain 5-fold CV; report
   team/generated/starter share per intent and flag team-written share below two-thirds.
   Generated rows are training-only and must never enter the held-out test set.
6. Retrain; export `assets/percy/model.json` and `model_alt.json`; run tests; document
   before/after results in `docs/handoff/03-voice-and-percy.md`; update status/issues/
   decisions/worklog; commit.

## User-approved conditions (verbatim)

> SCOPE: Only touch files needed for THIS task. Before editing anything else (other features,
> dependencies, schema, build settings, docs rules, the other repo, formatting of unrelated
> files, deleting files), stop and ask me with the file names and the reason, and wait for my
> answer. Note unrelated problems in docs/handoff/06-known-issues-and-todo.md instead of
> fixing them.

> Intent routing: extend the mapping so intents can invoke EXISTING routes and screen
> action IDs only. No new screens, no UI changes, no changes to unrelated features. If
> something needs a change outside this, ask me first.

> "kasaysayan" / "history": Reading History was merged into the Library (Aklatan), so map
> it to the Aklatan's recent/reading-history section, not a separate screen.

> Normalization: never remove negations ("hindi", "huwag", "wag", "wag na", "ayoko") and
> don't remove a filler if it's the meaningful part of the sentence (e.g. "ano ang kaya
> mo?"). If removing fillers leaves nothing, keep the original text. Add tests for these
> cases.

> Speed by name: support "mabagal", "katamtaman", "mabilis" (and English) as a slot for
> change_speed, plus the existing "faster/slower".

> Add short confirmations in English and Filipino ("yes", "yeah", "oo", "opo", "sige",
> "no", "hindi", "ayoko") with enough examples.

> Generated phrases ("Generated (Codex)") are used for TRAINING only.

> The held-out test set stays team-written phrases only, fixed and never used for
> training. Don't regenerate or reshuffle it between runs.

> Report accuracy/macro F1 on the team-only test set as the main score, and separately
> on all data.

> Report the data source share per intent (team vs generated vs starter) and flag
> intents where team-written phrases are below 2/3.

> Keep the current confidence thresholds unless you show a measured reason to change them.

> Add a set_speed action that sets the EXISTING reading-speed setting to an exact preset:
> Mabagal / Katamtaman / Mabilis — the same three values used in the registration/profiling
> speed step. Reuse that same setting and provider; don't create a new setting.

> Exact vs relative:
> - "mabagal", "katamtaman", "mabilis", "gawing mabagal", "normal na bilis", "slow",
>   "medium", "fast" → set_speed with the exact preset.
> - "mas mabagal", "bagalan", "dahan-dahan", "slower", "mas mabilis", "bilisan", "faster"
>   → the existing relative slower/faster actions.

> Register set_speed through the existing ActionRegistry/CommandBus like other actions
> (not a Percy-only special case), but don't add any screen, button, or gesture.

> Apply immediately to all TTS, save it to the profile, and confirm aloud in the new
> speed, e.g. "Katamtaman na ang bilis ng pagbasa."

> Add tests: each preset, relative changes at the min/max limits, and that the setting
> persists after restart.

> Overlaps: open_settings must only mean "go to the Settings screen". Move phrases about
> making text bigger/smaller or changing speed to bigger_text/smaller_text/faster/slower/
> set_speed. Run a conflict check: no normalized phrase may appear in two intents; list any
> near-duplicates across intents (e.g. read vs read_image_text) and how you resolved them.

> read vs read_image_text, describe_image vs open Maglarawan: let the dialogue manager use
> the current screen as context (in Maglarawan → image actions; elsewhere → document
> reading), not the classifier alone. Add tests for both screens.

> Balance: cap open_library and open_settings at 45 phrases each (keep the most varied,
> remove near-duplicates), or use class weighting in training. Say which you chose.

> Before adding them to intents.csv, write all 570 generated rows to
> data/percy/review/generated_for_review.csv (text, intent, note) so my team can delete
> unnatural phrases. Wait for my OK after our review.

> Test set: create data/percy/test_team.csv (fixed, team-written only) with the existing
> team rows that belong there, and empty sections for the 5 new intents. My team will add
> ~10 phrases each. Don't retrain until I say the test file is complete.

> The final report must show: team-only test accuracy and macro F1 (primary), all-data
> results (secondary), per-intent results, the confusion matrix, and the team/generated/
> starter share per intent.

> Don't retrain, don't change the model, and don't start anything new.

## Risks and open questions

- The review batch has not been merged; current `assets/percy/model.json` does not contain
  the five added enum labels. Therefore the classifier test will fail until the approved
  training/data phase completes.
- `test_team.csv` has comment lines. Update CSV loading to ignore `#` comments before it is
  used by the trainer, and reject blank/template rows.
- The new exact speed action has persistence coverage, but the requested dedicated
  min/max relative-action test and all preset CommandBus action tests still need to be run
  or completed.
- The review file's 138 heuristic near pairs need human judgement; only exact normalized
  duplicates were automatically excluded.

## How to resume

```powershell
git switch feat/percy-smarter
flutter analyze
flutter test test/core/percy test/core/settings/settings_controller_test.dart test/core/accessibility/command_bus_test.dart
scripts\percy\.venv\Scripts\python scripts\percy\validate_dataset.py
scripts\percy\.venv\Scripts\python scripts\percy\train.py
flutter test test/core/percy/intent_classifier_test.dart
```

Do not run training until the team data and review acceptance are actually present on disk.
