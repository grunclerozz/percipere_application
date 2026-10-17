# Percipere — algorithms (thesis methodology draft)

Four algorithms are written by us, in Dart (or, for training, Python), with no third-party
implementation of the algorithm itself. Everything runs **offline on the phone**; none calls an
AI service. Other parts of the app use ready-made tools; they are listed honestly in
[Tools used (not developed by us)](#tools-used-not-developed-by-us).

Numbers marked **unverified** have not been measured on a real phone yet. Thresholds live in
config files so they can be tuned after testing.

| # | Algorithm | Used for | Code |
|---|---|---|---|
| 1 | TF-IDF + Logistic Regression (compared with Multinomial Naive Bayes) | Percy: understanding what the user means | `scripts/percy/train.py`, `lib/core/percy/intent_classifier.dart` |
| 2 | Levenshtein distance (+ Word Error Rate) | Matching spoken commands; measuring speech recognition | `lib/core/voice/command_matcher.dart`, `lib/core/algorithms/wer.dart` |
| 3 | Laplacian variance + brightness check | Telling the user when a camera photo is blurry, dark or bright | `lib/core/algorithms/image_quality.dart` |
| 4 | Otsu's thresholding | Second try at reading text when OCR is weak | `lib/core/algorithms/otsu.dart`, `lib/core/ocr/ocr_fallback.dart` |

---

## 1. TF-IDF + Logistic Regression (and Multinomial Naive Bayes) — Percy intent classification

### Objective
Decide which *intent* a free sentence expresses ("pakibukas ang library", "can you read it
slower") so Percy can run the matching app action. 32 intents (e.g. `open_library`, `faster`,
`help`, `describe_image`). Sentences are Filipino, English or Taglish.

### Input / output
- **Input:** the sentence heard by speech recognition (after `percy_text.dart` normalizes it:
  lowercase, no diacritics or punctuation, common spelling variants folded).
- **Output:** a probability for each intent; the most likely one is the prediction.
  Percy acts at probability ≥ 0.60, asks "Ang ibig mo bang sabihin ay …?" from 0.30 to 0.60, and
  says it can't do that yet below 0.30 (`lib/config/percy_config.dart`).

### Formula
Features of a sentence *s* are word 1–2-grams and character 3–5-grams (inside words).

TF-IDF weight of feature *f*: `x_f = tf(f, s) · idf(f)`, with
`idf(f) = ln((1 + n) / (1 + df(f))) + 1` (n = training sentences, df = sentences containing
*f*). Word and character blocks are each scaled to unit length (L2), so neither dominates.

**Logistic Regression** (multinomial): `P(c | x) = softmax(W·x + b)_c`, where
`softmax(z)_c = e^{z_c} / Σ_k e^{z_k}`. Training minimizes the cross-entropy plus an L2 penalty
controlled by `C`.

**Multinomial Naive Bayes** (the comparison): `P(c | x) ∝ P(c) · Π_f P(f | c)^{x_f}`; in log
form `log P(c) + Σ_f x_f · log P(f | c)`, with Laplace smoothing `alpha`.

### Pseudocode
```
TRAIN (offline, Python, scripts/percy/train.py)
  read data/percy/intents.csv; normalize each sentence; drop repeats
  build vocabulary of word 1-2-grams and char 3-5-grams; compute idf
  tune C (LR) / alpha (NB) by stratified 5-fold cross-validation on the training data
  fit both models; keep the one with the higher CV macro F1
  export weights, bias, vocabulary, idf as assets/percy/model.json

PREDICT (on the phone, Dart, IntentClassifier.predict)
  clean = normalize(sentence)
  for each feature f of clean that is in the vocabulary: count[f] += 1
  for each block (words, chars): x_f = count[f] * idf[f]; divide the block by its L2 norm
  for each intent c: z_c = bias[c] + sum_f weights[c][f] * x_f
  probabilities = softmax(z)
  return intents sorted by probability
```

### Why chosen
- Small data (about 1000 sentences) and a need to run instantly on a low-end phone, offline:
  a sparse linear model predicts in microseconds and the model file is about 1 MB.
- Character n-grams survive speech-recognition spelling errors and Taglish word forms
  ("pakibasa", "basahin", "babasahin").
- The probability output gives the *act / ask / refuse* thresholds directly.
- Alternatives: neural networks and large language models need more data, more memory, usually
  a network, and cannot be inspected easily; a rule list cannot cover free sentences.
  Naive Bayes is kept as the baseline because it is the classic text-classification method.

### Where in the code
- Training: `scripts/percy/train.py` (with `validate_dataset.py`, `percy_text.py`).
- Prediction: `lib/core/percy/intent_classifier.dart`; text preprocessing
  `lib/core/percy/percy_text.dart`; use in `lib/core/percy/dialogue_manager.dart`.
- Model: `assets/percy/model.json` (chosen), `model_alt.json` (the other kind).

### How evaluated
Fixed team-written test set `data/percy/test_team.csv` (never trained on, never reshuffled);
settings chosen by 5-fold cross-validation on the training data only, so the test set does not
influence the choice. Metrics: accuracy, macro F1 (over intents that have test sentences),
per-intent precision/recall, confusion matrix, accuracy per confidence band.

### Results
**PROVISIONAL — not the official thesis result.**
(`data/percy/reports/report-2026-10-16.md`; 58 team test sentences covering 10 of the 32
intents; the 22 other intents, including the 5 newest, have no team test sentences yet.)

| Model | Test accuracy | Test macro F1 | 5-fold CV macro F1 |
|---|---|---|---|
| Multinomial Naive Bayes (alpha 0.03) | 0.897 | 0.932 | 0.860 ± 0.023 |
| **Logistic Regression** (C 30, balanced class weights) — chosen | **0.966** | **0.971** | **0.893 ± 0.028** |

Earlier, with the 2026-10-13 data (80 random test sentences, 27 intents): Logistic Regression
0.838 accuracy / 0.667 macro F1, Naive Bayes 0.812 / 0.649
(`data/percy/reports/report-2026-10-13.md`). At Percy's "act" threshold (≥ 0.60) the
predictions were 100 % correct on that set (56 sentences). The official evaluation will be
rerun when the team has written test sentences for every intent
(`docs/prompts/a6-percy-official-eval.md`).

---

## 2. Levenshtein distance — fuzzy voice-command matching (and Word Error Rate)

### Objective
- **Matching:** speech recognition often returns a near miss ("basahen" for "basahin"). Match
  what was heard to the closest known command instead of failing.
- **Evaluation:** measure how well the recognizer works with Word Error Rate (WER), which is a
  word-level Levenshtein distance.

### Input / output
- **Matching:** the heard text and the list of phrases that are valid on the current screen
  (plus the app-wide commands) → *Matched* (run it), *Ambiguous* (ask back) or *No match*.
- **WER:** a reference sentence and the recognized sentence → counts of substitutions *S*,
  deletions *D*, insertions *I* and the rate `(S + D + I) / N`.

### Formula
Edit distance between strings *a* and *b* (dynamic programming):

```
D[i][0] = i      D[0][j] = j
D[i][j] = min( D[i-1][j] + 1,                       -- delete
               D[i][j-1] + 1,                       -- insert
               D[i-1][j-1] + (a_i != b_j) )         -- substitute or keep
similarity(a, b) = 1 - D[|a|][|b|] / max(|a|, |b|)          (1 if both are empty)
```

WER uses the same table with **words** instead of characters:
`WER = (S + D + I) / N`, where *N* is the number of reference words. WER can exceed 1 when
there are many insertions.

### Pseudocode
```
MATCH (CommandMatcher.match)
  words = normalize(heard)                 -- lowercase, no diacritics/punctuation
  if some phrase occurs word for word in words: the one said first wins (longer on a tie)
  for each phrase p of every command:
      score(p) = best similarity between p and any run of words of about p's length
  best = command with the highest score; runnerUp = the best other command
  if best >= 0.80 and best is not tied with runnerUp: Matched
  else if best >= 0.60:                                  Ambiguous ("Ang ibig mo bang sabihin…")
  else:                                                  No match

WER (wordErrorRate)
  ref, hyp = words of the two texts (same normalization)
  fill table d[0..n][0..m] as above, on words
  i = n; j = m
  while i > 0 or j > 0:                    -- backtrack from the corner
      if match or substitution is optimal:  count a substitution if the words differ; i--, j--
      else if deletion is optimal:          D++, i--
      else:                                 I++, j--
  return (S, D, I, n, (S + D + I) / n)
```

### Why chosen
- Exact string matching fails on every small recognition error; the blind user would have to
  repeat commands. Edit distance is the standard, explainable measure of "how close are these
  two words", needs no training data and runs instantly.
- Compared with phonetic codes (Soundex/Metaphone, made for English names) it works for Filipino
  spelling and for short phrases; compared with a trained classifier it is predictable, which
  matters for commands that change what the app does.
- WER is the standard measure for speech recognition, so results can be compared with the
  literature.

### Where in the code
- `lib/core/voice/command_matcher.dart` — `CommandMatcher.levenshtein`, `.similarity`, `.match`
  (thresholds 0.80 accept / 0.60 ask in the constructor; used by `CommandBus`).
- `lib/core/algorithms/wer.dart` — `wordErrorRate` (new).
- Hidden developer screen `lib/features/settings/wer_test_screen.dart` (developer builds,
  `--dart-define=PERCIPERE_DEV=true`, Settings → "Pagsubok ng pagkilala sa boses"): shows a
  reference sentence from `lib/config/wer_phrases.dart`, listens once, scores it, saves it in the
  `wer_results` table (`lib/core/db/daos/wer_dao.dart`) and exports **CSV** through the share
  sheet, with a total row (pooled WER = all errors / all reference words).

### How evaluated
- Unit tests with known pairs: `basahen`→`basahin` = 1; exact S/D/I counts for example
  sentences (`test/core/algorithms/wer_test.dart`, `test/core/voice/`).
- Study: testers read the reference sentences on the tablet; WER is computed per sentence and
  pooled, per language and per recognizer (online / on the phone).

### Results
The matching thresholds were tuned on the tablet during development (unverified numbers).
**No WER measurements yet** — they come from the study; add the pooled WER table here.

---

## 3. Laplacian variance + brightness check — photo quality

### Objective
A blind user cannot see that a photo is blurry or dark. After each camera capture (document
Reader and Maglarawan) the app checks the photo and, if it is poor, speaks a short tip and
offers to take it again.

### Input / output
- **Input:** the captured photo.
- **Output:** *sharpness* (variance of the Laplacian) and *brightness* (mean luminance, 0–255),
  and the main problem, if any: `tooDark`, `tooBright` or `blurry`.

### Formula
1. Grayscale: `Y = 0.299 R + 0.587 G + 0.114 B`.
2. Convolve with the 3×3 Laplacian kernel (second derivative; strong response at edges):

```
 0  1  0
 1 -4  1        L(x, y) = Y(x-1,y) + Y(x+1,y) + Y(x,y-1) + Y(x,y+1) - 4 Y(x,y)
 0  1  0
```
3. `sharpness = Var(L) = E[L²] − (E[L])²` over the interior pixels. A sharp photo has many strong
   edges, so *L* varies a lot; a blurred photo has soft edges and *L* stays near zero.
4. `brightness = mean(Y)`.

### Pseudocode
```
quality(photo)
  image = decode(photo); fix orientation
  shrink so the longest side is 320 px                -- speed; same scale on every phone
  Y = grayscale(image)
  sum = 0; sumSquares = 0; count = 0
  for each interior pixel: r = L(x, y); sum += r; sumSquares += r*r; count++
  sharpness = sumSquares / count - (sum / count)^2
  brightness = mean(Y)
  if brightness < 45:  return tooDark
  if brightness > 235: return tooBright
  if sharpness < 50:   return blurry
  return ok
```
Lighting is checked before blur because a dark photo is also low in detail, and "find more
light" is the tip that helps.

### Spoken tips (Filipino first; `lib/l10n/app_fil.arb`)
- Blurry: "Malabo ang larawan. Pakihawakan nang mas matatag ang telepono."
- Dark: "Masyadong madilim ang larawan. Lumipat po sa mas maliwanag na lugar."
- Bright: "Masyadong maliwanag ang larawan. Iwasan po ang direktang ilaw."
- Then: "Gusto mo bang kunan ulit?" — "Oo" (or a double-tap) takes it again; "Hindi" keeps the photo
  and goes on. If there is no answer the photo is dropped after 30 s and the camera carries on.

### Why chosen
- The variance of the Laplacian is a standard, cheap focus measure (one pass over the pixels),
  needs no model and works offline on a low-end phone.
- Alternatives: FFT-based sharpness (slower), deep-learning image-quality models (large, need
  training data), the phone's autofocus state (not available on every device, says nothing about
  motion blur after the shot).
- Limitations: a photo of a plain surface has few edges and looks "blurry"; the threshold is
  scale-dependent, hence the fixed 320 px size.

### Where in the code
- `lib/core/algorithms/image_quality.dart` — `laplacianVariance`, `meanBrightness`,
  `measureImageQuality` (runs in a background isolate).
- Thresholds: `lib/config/image_quality_config.dart` (`blurVarianceBelow` 50,
  `tooDarkBelow` 45, `tooBrightAbove` 235 — **unverified starting values**).
- Use: `lib/features/camera/camera_screen.dart` (`_offerRetakeIfPoor`), for both the Reader
  camera and the Maglarawan camera.
- Every capture logs `[IMAGE QUALITY] sharpness=… brightness=… issue=…` (`adb logcat -s flutter`)
  for tuning on real phones.

### How evaluated
- Unit tests: a synthetic sharp checkerboard scores far higher than its Gaussian-blurred copy; a
  single bright pixel has the exact hand-computed variance; flat dark/bright images are flagged
  (`test/core/algorithms/image_quality_test.dart`); the spoken tip and retake flow
  (`test/features/camera/camera_quality_test.dart`).
- To do on the tablet: take sharp, blurred, dark and bright photos, read the log values, and set
  the thresholds so that the correct photos pass; report the detection rate.

### Results
None measured on real photos yet (**unverified**). The measured values will go in a table here.

---

## 4. Otsu's thresholding — OCR fallback

### Objective
Text recognition (ML Kit) can fail on photos with poor lighting or low contrast. When the first
result is weak, turn the photo into a clean black-and-white image and read it again; keep
whichever result is better.

### Input / output
- **Input:** a photo whose first OCR result is weak (fewer than 20 letters/digits, or mean line
  confidence below 0.60).
- **Output:** the OCR result (original or from the binarized image) with more valid words.

### Formula
Otsu's method picks the gray level *t* that best separates dark pixels (ink) from light pixels
(paper), by maximizing the **between-class variance**. With the 256-bin histogram probabilities
`p_i`:

```
ω0(t) = Σ_{i≤t} p_i          ω1(t) = 1 − ω0(t)
μ0(t) = Σ_{i≤t} i·p_i / ω0   μ1(t) = Σ_{i>t} i·p_i / ω1
σ²_B(t) = ω0(t) · ω1(t) · (μ0(t) − μ1(t))²          t* = argmax σ²_B(t)
```
Binarize: pixel `> t*` → white (255), otherwise black (0).

### Pseudocode
```
recognizeWithOtsuFallback(photo)
  first = OCR(photo)
  if first is not weak: return first
  gray = grayscale(photo, shrunk to at most 2400 px)      -- background isolate
  histogram[0..255] = count of pixels per level
  best = -1
  for t in 0..255:                                         -- running sums, one pass
      compute ω0, ω1, μ0, μ1 from the histogram
      if ω0·ω1·(μ0-μ1)² > best: best = that value; t* = t
  bw = binarize(gray, t*)
  second = OCR(bw)
  return the result with more valid words (the original on a tie)
  -- any failure of the retry keeps the first result
```
*Valid word* = at least two letters, only letters/apostrophe/hyphen, at least one vowel
(a cheap filter for noise such as "xqzt" or "|||").

### Why chosen
- Otsu is a classic automatic threshold: no parameters, one histogram pass, deterministic,
  explainable. It needs no network and no trained model.
- Used **only as a fallback**: binarizing a good photo can lose thin strokes, so the original is
  always tried first, and the retry is kept only if it actually reads more words.
- Alternatives: adaptive (local) thresholds such as Sauvola handle uneven lighting better but
  have more parameters and cost more; they are noted as future work. A global threshold can fail
  on photos with a strong shadow across the page.
- **Never applied to the Maglarawan (image description) picture**: image labeling needs color
  and gray levels; only the OCR text check of a page uses it.

### Where in the code
- `lib/core/algorithms/otsu.dart` — `grayHistogram`, `otsuThreshold`, `binarize`,
  `otsuBinarizeToPng` (isolate).
- `lib/core/ocr/ocr_fallback.dart` — `isWeakOcr`, `validWordCount`, `recognizeWithOtsuFallback`.
- Use: `lib/core/extraction/document_extractor.dart` (every image the Reader reads: camera,
  gallery, upload). Limits and thresholds: `OcrFallbackConfig` in
  `lib/config/image_quality_config.dart`.
- Each fallback logs `[OCR FALLBACK] … chars … valid words … kept Otsu/original (ms)`.

### How evaluated
- Unit tests: known histograms (two tones, two clusters, 90/10 classes) give a threshold between
  the classes; a faint-text image becomes pure black and white with strokes black; the fallback
  keeps the better result, keeps the original on a tie, and never loses the first result when
  the retry fails (`test/core/algorithms/otsu_test.dart`, `test/core/ocr/ocr_fallback_test.dart`).
- To do for the study: photograph the same pages in good and poor light, compare the number of
  valid words (and character accuracy against the known text) with and without the fallback,
  using the `[OCR FALLBACK]` log lines.

### Results
None measured on real photos yet (**unverified**).

---

## 5. TF-IDF + cosine similarity — Percy's answers to questions (knowledge retrieval)

### Objective
Percy must answer questions about itself and the app ("Anong kaya mo?", "Paano mag-scan?"),
not only obey commands. The answers are written by us (`assets/percy/knowledge.json`); the
algorithm finds which answer fits what the user said. Offline, no AI service.

### Input / output
- **Input:** the user's question as heard (any mix of Filipino, English, Taglish and speech-recognition
  spellings such as "anu", "pano", "ung", "kaya mu"), and the knowledge base: 32 topics, each with
  about 30 example questions and a Filipino and English answer.
- **Output:** the topics ranked by a score from 0 to 1. Score ≥ 0.55: answer it. 0.35–0.55: ask
  "Ito ba ang tinatanong mo: …?" with the closest topic. Below 0.35: say it is not sure and suggest
  three example questions.

### Formula
1. Normalize: lowercase, fold accents, drop apostrophes, other punctuation → space, map spellings
   (`anu→ano`, `pano→paano`, `mu→mo`, `ung/yung→ang`), drop politeness words and the wake word
   (`po, opo, nga, naman, ba, percy`) and a few function words (`ang, ng, sa, na, the, a, of, to`).
2. Features: word 1–2-grams and character 3–4-grams inside each padded word (so "mag-scan",
   "magscan" and "mag scan" share most features).
3. Weight each feature of a question with `tf × idf`, `idf(f) = ln((1 + N) / (1 + df(f))) + 1`,
   where `N` is the number of example questions (about 1,000) and `df(f)` how many contain `f`.
   L2-normalize the word block and the character block separately.
4. For the user's question `q` and one example question `d`:
   `cos(q, d) = Σ q_f · d_f` per block, and `score(q, d) = (cos_word + cos_char) / 2`.
   A feature of `q` that no example question has still counts in `q`'s norm (with the highest idf),
   so a question made mostly of unknown words scores low instead of matching on one familiar word.
5. `score(topic) = max over its example questions`.

### Pseudocode
```
build():  for each example question d: counts[d] = features(normalize(d))
          df[f] = number of questions containing f;  idf[f] = ln((1+N)/(1+df[f])) + 1
          vector[d] = l2(tf*idf per block);  inverted index: feature -> (d, weight)
rank(q):  v = l2(tf*idf of features(normalize(q)); unknown features add to the norm only)
          for each feature f in v: for (d, w) in index[f]: dot[d] += v[f] * w
          score[topic] = max(dot[d] / 2 for d in topic)      # two blocks, each at most 1
          return topics sorted by score
```

### Why chosen
- Same family as the intent classifier (TF-IDF), so the thesis explains one idea twice and the
  code reuses the feature approach; no new library, pure Dart (scoring about 1,000 short questions is a few milliseconds on a PC; not measured on the tablet).
- A classifier would need many examples **per answer** (32 classes); similarity to example questions
  lets the team add or fix an answer by editing one JSON file, with no retraining.
- The score is easy to explain and to threshold: "sure", "ask back" and "suggest examples" are three
  bands of the same number. A neural sentence encoder would be more flexible but needs a model
  download and is harder to defend with our small data.

### Where in the code
- `lib/core/percy/knowledge_base.dart` (`KnowledgeBase`: `rank`, `tokens`, `looksLikeQuestion`).
- Thresholds: `lib/config/percy_config.dart` (`knowledgeAnswer` 0.55, `knowledgeAsk` 0.35,
  `knowledgeRescue` 0.85).
- Used by `lib/core/percy/dialogue_manager.dart` (`_askedQuestion`): the intent classifier has an
  `ask_question` intent (all example questions are in `data/percy/intents.csv`); when it says
  "question", or a sentence with a question word is almost word for word a known question (≥ 0.85), the
  knowledge base answers. Commands stay commands.

### How evaluated
- `test/core/percy/knowledge_test.dart`: every example question returns its own topic (alone and
  through the real classifier + dialogue manager, in Filipino and English); the questions named by the
  team return the expected topic; wordings that are in no list; **leave-one-out** (each third question
  is removed from the list, then asked); off-topic questions give three suggestions; no command row of
  the dataset is answered as a question.

### Results
- Leave-one-out (a question that is **not** in the list): **87.8 %** of 345 questions reach the right
  topic (2026-10-18). The misses are mostly neighbouring topics ("Do I need an account?" is both
  *register* and *guest*; "what is your job" is *purpose* or *abilities*).
- Off-topic sentences ("what is the weather today", "ano ang pinakamataas na bundok") score 0.07–0.18,
  below the 0.35 line.
- Not measured with real users or speech recognition output on the tablet (**unverified**).

---

## Tools used (not developed by us)

These are ready-made components; the thesis should name them and not claim them as our work.

| Tool | What it does for us | Notes |
|---|---|---|
| Google ML Kit **Text Recognition** (`google_mlkit_text_recognition`) | OCR: reads printed text from photos, PDFs pages and uploads (Latin script: Filipino and English) | on the phone, offline; our code only prepares images and cleans the text (`lib/core/ocr/`) |
| Google ML Kit **Image Labeling** | Offline labels for Maglarawan ("mesa", "aso") | on the phone; Filipino label names and the description sentence are ours (`lib/config/image_labels_fil.dart`, `lib/core/describe/`) |
| Android **speech recognition** (`speech_to_text`) | Voice commands and dictation when online or when the phone has the language installed | not ours; we only match its output (algorithm 2) |
| **sherpa-onnx** (offline speech) | Offline command recognition and offline text-to-speech voices (downloaded once) | models are third-party (e.g. MMS Tagalog is CC-BY-NC, eSpeak is GPL-3.0): non-commercial thesis use only |
| `flutter_tts` / Android **text-to-speech** | Spoken output | system voices |
| **Gemini vision**, through the **web dashboard** | The optional detailed image description in Maglarawan | the app never calls an AI API; it sends the picture to our dashboard (server side, its own key) only after the user agrees (RA 10173) |
| `image` (Dart package) | Decoding, resizing and pixel access only | the Laplacian, Otsu and grayscale steps are our own code |
| scikit-learn (Python) | Used offline by `train.py` only to *fit* the Logistic Regression and Naive Bayes weights, and for the metrics and the cross-validation split | the TF-IDF features are our own code (Python for training, Dart on the phone); prediction on the phone is our own Dart code, checked against Python with `scripts/percy/test_vectors.json` |
| Flutter, Riverpod, go_router, sqflite | App framework, state, navigation, local database | |
