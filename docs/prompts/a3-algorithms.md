# A3 – Algorithms (Sonnet 5.5, new chat)

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/05-current-status.md and the latest
worklog. Create branch feat/algorithms from main. SCOPE rule applies. Don't run the app on
my device. Analyze + relevant tests only. Everything offline, written by us in Dart, no new
dependencies without asking, no AI APIs.

OUR FOUR MAIN ALGORITHMS
1. TF-IDF + Logistic Regression (compared with Multinomial Naive Bayes) – Percy intent
   classification. Already built: document only (use the provisional results).
2. Levenshtein Distance – fuzzy voice-command matching (already used). ADD a word-level WER
   calculator ((S+D+I)/N) for our evaluation: hidden developer screen that compares
   reference phrases with recognized text and exports a CSV.
3. Laplacian Variance + brightness check – on camera captures (Reader and Maglarawan): if
   blurry, too dark, or too bright, speak a short tip ("Pakihawakan nang mas matatag ang
   telepono.") and offer to retake. Thresholds in a config file; log values for tuning.
4. Otsu's Thresholding – OCR fallback: if the first OCR result is weak (low confidence or
   very short text), grayscale + Otsu binarization, re-run OCR, keep the better result.

PRIORITY if time runs short: (a) docs/thesis/algorithms.md for all four, (b) WER calculator,
(c) Laplacian check, (d) Otsu. Do Phase A (short plan) and Phase B (build) in one go; stop
only if something is risky.

Tests: synthetic sharp vs. blurred images, known histograms for Otsu, known WER examples.
New actions work by voice, gesture and tap; strings in ARB files (Filipino first).

docs/thesis/algorithms.md – one section per algorithm: objective, input/output, formula,
step-by-step pseudocode, why chosen (vs. alternatives), where in the code, how evaluated,
results if measured. Add a separate section "Tools used (not developed by us)": ML Kit
OCR/image labeling, sherpa-onnx speech, Gemini vision via the dashboard.

FINISH: analyze + tests for changed code; if all pass, merge feat/algorithms into main.
Update docs/handoff (05, 07, worklog), commit (don't push), list changed files.
