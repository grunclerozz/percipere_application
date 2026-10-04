# Core algorithms (Phase 6D — ⏸ POSTPONED)

Three algorithms implemented **by us, in Dart**, as pure, documented functions in
`lib/core/algorithms/` — no third-party implementation of the algorithm itself. The
`image` package may be used only for decoding, resizing and pixel access. Written so the
sections can be adapted into the thesis methodology chapter. Spec status: **POSTPONED to Phase 6D (2026-10-04); do not build in 6C. Requirements
from the user, kept for later.**

Notation: *a*, *b* strings; |a| length; *N* number of reference words.

---

## B1. Levenshtein distance — command matching and WER

**Purpose.** (1) Tolerate speech-recognition errors when matching spoken commands.
(2) Compute Word Error Rate for evaluating the recognizer.

**Character-level distance.** Dynamic programming over a table
`D[i][j] = min( D[i−1][j] + 1, D[i][j−1] + 1, D[i−1][j−1] + (aᵢ ≠ bⱼ) )`, with
`D[i][0] = i`, `D[0][j] = j`. Only two rows are kept (O(min(|a|,|b|)) memory).
Normalized similarity: `similarity = 1 − distance / max(|a|, |b|)` (1.0 if both empty).

**Command matching** (replaces/refactors `CommandMatcher`):
1. Normalize input: lowercase, strip punctuation and diacritics, collapse whitespace.
2. Compare against **every synonym of every command registered on the current screen**
   (plus the app-wide commands). For multi-word input also compare each **word and each
   word pair**, so "sige basahin mo na" still matches "basahin".
3. Best similarity **≥ 0.75** → execute. **0.55 – 0.75**, or two *different* commands
   within **0.05** of each other → ask "Ang ibig mo bang sabihin ay '…'?". **< 0.55** →
   unknown command; list the available commands.
4. Thresholds live in a config file (`lib/config/matching_config.dart`), tunable after
   testing.
5. Every match is written to the local usage log: heard text, matched command,
   similarity, accepted or not (for tuning and the study).

**Word Error Rate.** Word-level Levenshtein over the reference and hypothesis word
lists, with **backtracking** through the table to count substitutions *S*, deletions
*D* and insertions *I*. `WER = (S + D + I) / N`. Only the calculator and tests now; the
WER test screen stays in the postponed Phase 8 (table `wer_results` already exists).

**Where used:** `CommandBus` voice matching (yes/no answers, screen actions, global
commands); WER calculator (Phase 8 screen).

---

## B2. Laplacian variance — blur detection (and brightness check)

**Purpose.** Tell the user, by voice, when the camera image is too blurry, dark or
bright; block auto-capture while blurry.

**Steps (per analysed preview frame):**
1. Take the **Y (luminance) plane** of the YUV frame directly as the grayscale image;
   downscale to ≈ 320 px on the longest side (speed).
2. Convolve with the 3×3 Laplacian kernel `[0 1 0; 1 −4 1; 0 1 0]` (interior pixels).
3. **Sharpness = variance of the response.** Low variance ⇒ blurry (few edges).
4. **Brightness = mean luminance** (0–255) ⇒ too dark / too bright.
5. About **3–5 frames per second**, off the main thread, smoothed over the last few
   frames (no flickering messages).

**Spoken guidance** (at most one message every 2–3 s):
- Blurry: "Malabo ang larawan. Hawakan nang maayos ang phone."
- Too dark: "Masyadong madilim. Lumipat sa mas maliwanag na lugar."
- Too bright: "Masyadong maliwanag. Iwasan ang direktang ilaw."
- Sharp and lit: "Handa na." (+ haptic pulse if vibration is on)

**Rules.** No auto-capture while blurry. A manual capture of a blurry image is allowed,
followed by "Medyo malabo ang kuha. Gusto mo bang kumuha ulit?". Uploaded images get
the same check once; if blurry, warn before processing. Applies to both the document
camera and the Maglarawan camera. Thresholds configurable (`lib/config/`); a **hidden
debug readout** shows the live variance and brightness for calibration on real phones.

---

## B3. Otsu's thresholding — OCR preprocessing

**Purpose.** Improve OCR on poorly lit/low-contrast photos by binarizing.

**Steps:**
1. Grayscale: `Y = 0.299 R + 0.587 G + 0.114 B`.
2. 256-bin histogram; probabilities `pᵢ`.
3. For every threshold *t* compute class weights `ω₀(t) = Σ_{i≤t} pᵢ`, `ω₁(t) = 1 − ω₀(t)`
   and class means `μ₀(t)`, `μ₁(t)`; choose the *t* that **maximizes the between-class
   variance** `σ²_B(t) = ω₀(t) · ω₁(t) · [μ₀(t) − μ₁(t)]²`.
4. Binarize: pixel ≥ *t* → white, else black.

**Adaptive use.** OCR the original image first. If the result is weak (**< 20 characters**
or a high share of non-alphabetic noise), OCR the Otsu-binarized image too and keep the
result with **more valid words**. **Never** apply Otsu to the image used for Maglarawan
labeling (it needs color). All preprocessing runs in an isolate.

**Study support.** A hidden evaluator setting runs OCR **with and without** Otsu on every
capture and logs both character counts and processing times to a local table, exportable
as **CSV via the share sheet**.

---

## Tests required
- Levenshtein: known pairs, empty, identical, Filipino ("basahen" → "basahin" = 1).
- Command matching: accepted / confirmation / rejected at each threshold.
- WER: known reference/hypothesis pairs with exact S, D, I.
- Laplacian: a synthetic sharp image scores higher than its blurred copy.
- Otsu: a synthetic two-tone image yields a threshold between the two tones.
