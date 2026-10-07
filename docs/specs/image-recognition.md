# Maglarawan — image recognition (Phase 6C)

Tells the user **what is in a picture**: for photos without readable text, or when the
user wants to know what an image shows. Spec status: **requirements from the user,
2026-10-04; build plan awaiting approval.** The core algorithms (Levenshtein, Laplacian,
Otsu) are postponed to Phase 6D (`algorithms.md`); this phase reuses the existing
command matcher, camera guidance and OCR unchanged.

## A1. Capture screen: third option
- Third button below "Mag-upload" and "Gamit ang Camera": **"Maglarawan"**. Style like the
  "Subukan muna" button on Welcome (white with a navy border, adapted per theme; the
  existing `PillVariant.tertiary`). `docs/ui/` doesn't show it yet; stay consistent.
- Focus order: Mag-upload → Gamit ang Camera → **Maglarawan** → (Settings; the Library link moved to Home).
- Voice: "maglarawan", "ilarawan", "describe", "ano ito".
- **Announcement**, after the usual capture question: "Pwede mo ring gamitin ang bago
  naming feature: Maglarawan. Sasabihin nito kung ano ang nasa isang larawan."
- **Explanation** when Maglarawan is focused and the user says "ano ang maglarawan?",
  "paliwanag", "explain" or "tulong": "Ang Maglarawan ay para sa mga larawang walang
  teksto, o kung gusto mong malaman kung ano ang nasa larawan. Kumuha ng litrato gamit
  ang camera o mag-upload ng larawan, at sasabihin namin kung ano ang nakikita namin.
  Kung may internet, maaari kang humingi ng mas detalyadong paglalarawan."
- On each user's **first visit** to Capture after this update, read the full explanation
  once, automatically (flag saved per user/guest scope). Afterwards only the short
  announcement.

## A2. Flow
1. Choose Maglarawan, then the source: **Gamit ang Camera** or **Mag-upload** (existing
   camera screen with its audio guidance, and file picker, images only).
2. **Offline description first, always.** ML Kit image labeling
   (`google_mlkit_image_labeling`, on-device base model) on the image. Top 3 labels with confidence ≥ 0.7, translated through
   `lib/config/image_labels_fil.dart` (English fallback for labels not in the map).
   Spoken: "Mukhang may pagkain, plato, at mesa sa larawan." No label passes: "Hindi ko
   matiyak kung ano ang nasa larawan. Subukan ulit na may mas maliwanag na ilaw."
3. **Text check:** also run the existing OCR. If readable text is found:
   "May nakita rin akong teksto. Gusto mo bang basahin ito?" — on yes, open the Reader.
4. **Detailed description (online, optional):** if online, ask "Gusto mo ba ng mas
   detalyadong paglalarawan?" Yes → send the image to the web app (A4), read the result.
   Offline → say it needs internet and offer to try later.
5. **Privacy consent**, first time a user requests a detailed description, before
   sending: "Ipapadala ang larawan sa aming server at sa serbisyo ng Google para
   mailarawan ito. Sige ba?" The answer is saved per user and can be changed in Settings.

Progress: if labeling/OCR/upload takes > 1 s, say "Tinitingnan ang larawan…". All image
work runs off the main thread. Guests can use everything; their detailed-description
requests are sent flagged anonymous.

## A3. Description screen
- Text size works as in the Reader: pinch (out = bigger, in = smaller), "palakihin" / "paliitin", and the A−/A+ buttons. No two-finger swipe (decided 2026-10-04: pinch only).
- Reader layout: the **Document Box** shows the image thumbnail at the top, then the
  description text, with the persistent scrollbar. The **Gesture Pad** carries controls.
- Options (voice, or swipe to focus + double-tap): **ulitin** / repeat, **mas detalyado** /
  more detail (online), **basahin ang teksto** / read text (only if text found),
  **i-save** / save, **bagong larawan** / new picture.
- Saved descriptions go to the Library (source "Maglarawan") with the thumbnail.
- Back navigation follows the app-wide rules (`navigation.md`).

## A4. Online description via the web app (mocked for now)
- **The app never calls Gemini directly and never holds an API key.**
- `ImageDescriptionRepository` interface + **mock implementation** (sample text after a
  short delay). Real implementation: `POST {API_BASE_URL}/api/describe-image`, multipart:
  image, `language` (`fil`/`en`, matching the user's voice language), user id or guest
  flag. Response: `{ "description": "...", "has_text": true|false }`.
- Contract and recommended Gemini instructions in `docs/api-contract.md`: describe
  clearly and briefly for a visually impaired listener in the requested language; mention
  visible text; never guess who a person is; for medicines, money or safety-related
  items, add a reminder to confirm with someone trusted.
- Before upload: resize (longest side ≤ 1600 px) and JPEG-compress, in an isolate.

## A5. Safety messaging
- Every description starts "Mukhang…" / "It looks like…" (it is an estimate).
- If a label suggests medicine, pills or money, add: "Paalala: kumpirmahin ito sa taong
  pinagkakatiwalaan mo bago gamitin."

## Technical rules
- All new strings in the ARB files (Filipino template). Actions registered through
  `ActionRegistry` / `CommandBus`. Guests can use everything.
