# Demo script (10 minutes)

Presenters: **A** = talks and explains, **B** = holds the tablet and does the demo. Swap roles
for Part 5 if you like. Do not say the sentences word for word; keep the order and the points.
Before starting, finish `docs/defense-checklist.md`. Algorithm details: `docs/thesis/algorithms.md`.

| Min | Who | Feature | Say / do | Algorithm to mention |
|---|---|---|---|---|
| 0:00–0:45 | A | Problem | Visually impaired readers in Bataan, printed and digital text, used **without seeing the screen**. Offline-first, Filipino first. | — |
| 0:45–2:30 | B | **Voice + gestures** (Home) | Eyes off the screen. Hold to listen; say a command ("Basahin", "Aklatan"). Then show a swipe (next), double tap (select), two-finger double tap (stop speech). Say a command slightly wrong. | **Levenshtein distance**: fuzzy matching accepts a near miss. |
| 2:30–4:30 | B | **Reader: scan and read aloud** | Take a photo of a printed page. First show a **blurry or dark photo**: the app warns and offers a retake. Retake a good one; it reads aloud. Change speed with a swipe up/down. | **Laplacian variance + brightness** (photo quality); **Otsu thresholding** (OCR fallback when the first reading is empty or poor). |
| 4:30–5:30 | A + B | **Offline** | Turn on airplane mode on the tablet. Read the page again, use a gesture and a voice command. "Nothing here needs the internet." | Offline voice (sherpa-onnx Whisper tiny Filipino, Silero VAD): a tool we used, not developed by us. |
| 5:30–6:45 | B | **Percy** (two-finger swipe left or say "Percy") | Ask: "Ano ang magagawa mo?", then "Ilarawan ang larawan" or "Paano gamitin?". Show that it asks back when something is missing. | **TF-IDF + Logistic Regression** (intent classification), with rule-based slots. |
| 6:45–7:45 | B | **Maglarawan** | Point the camera at a picture; offline label first; then (online, after consent) the longer description. Say "Ilarawan pa" for more detail. Mention consent (RA 10173). | Image quality check before describing. |
| 7:45–8:45 | B | **Aklatan** (needs the server) | Show the connected message, list of admin books, download one, read it, show progress and a favorite. | — |
| 8:45–9:15 | B | **Mag-report ng problema** | "Mag-report"; answer a question or two; ticket number PRC-… ; sent to the dashboard (retried when offline). Mention: documents, images and recordings are never sent. | — |
| 9:15–9:45 | A | **Dashboard** (MacBook) | Show the report arriving and the books list. | — |
| 9:45–10:00 | A | **Results + close** | Evaluation results if ready: Percy accuracy/F1 on the team test set (`docs/thesis/percy-evaluation.md`, **provisional until a6 is done**), WER from the voice study. Limits and future work. Thank the panel. | Word Error Rate (Levenshtein on words). |

## If something fails
- Voice not heard: use the gesture or a tap for the same action ("everything works three ways").
- Server down: skip Aklatan and the dashboard, say why, and go on offline (`docs/defense-checklist.md`).
- Any crash: reopen the app; show the recording of that feature from the flash drive.

## Results slide (fill in before the defense)
- Percy: accuracy ___ , macro-F1 ___ (test set: ___ team sentences) — official numbers only after a6.
- WER (offline voice, quiet / noisy): ___ / ___ (from the study).
- Photo quality check: thresholds in `lib/config/image_quality_config.dart` (tablet-tuned).
- SUS / usability: not collected yet (future work if not done).
