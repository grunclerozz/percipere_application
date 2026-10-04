# Phase 6C — Maglarawan: manual test checklist

Use the emulator `Percipere_Light` (or a real phone). Tick each line in **both** navigation
modes where it says "voice / gesture". Photos with real objects work best on a phone;
on the emulator use the virtual scene (camera) or push images to the Pictures folder.

## 1. Capture screen
- [ ] Three buttons in this order: **Mag-upload**, **Gamit ang Camera**, **Maglarawan**
      (white with a navy border, readable in all three themes).
- [ ] Spoken entry: the usual question, then "Pwede mo ring gamitin ang bago naming
      feature: Maglarawan…".
- [ ] **First visit of a new user (also a guest):** the full explanation is read once
      after the announcement. Leave the screen and come back: only the short line.
- [ ] Gesture: swipe right ×3 focuses Mag-upload → Camera → Maglarawan; double-tap opens it.
- [ ] Voice: "maglarawan", "ilarawan", "describe", "ano ito" each open Maglarawan.
- [ ] With Maglarawan focused, say "ano ang maglarawan?", "paliwanag", "explain" or
      "tulong": the explanation is spoken and you stay on Capture.
- [ ] Text size 48 in Settings: Capture still fits, nothing overlaps.

## 2. Source choice
- [ ] Spoken: "Maglarawan. Paano mo gustong kunin ang larawan?" Two buttons.
- [ ] "Gamit ang Camera" and "Mag-upload" work by voice and by gesture.
- [ ] Mag-upload shows **only images** (no PDF/DOCX) in the picker; cancelling is announced.

## 3. Camera
- [ ] The camera gives its usual audio guidance and takes the photo (auto or double-tap).
- [ ] The photo goes to the **Description** screen, not the Reader.

## 4. Offline description (airplane mode on)
- [ ] A plate of food: "Mukhang may pagkain, plato, at mesa sa larawan." (Filipino words).
- [ ] A dark or empty picture: "Hindi ko matiyak kung ano ang nasa larawan. Subukan ulit
      na may mas maliwanag na ilaw."
- [ ] A label not in the Filipino map is spoken in English (note which: add to
      `lib/config/image_labels_fil.dart`).
- [ ] A medicine box / pills / banknotes: the **Paalala** sentence is added.
- [ ] Offline: "Kailangan ng internet para sa mas detalyadong paglalarawan…" once; no
      detail offer.
- [ ] Taking longer than ~1 s: "Tinitingnan ang larawan…" is spoken.

## 5. Text in the picture
- [ ] A page of text: "May nakita rin akong teksto. Gusto mo bang basahin ito?"
      "oo" / double-tap opens it in the Reader and reads it; it appears in History.
- [ ] "hindi": moves on to the detailed offer (when online).

## 6. Detailed description (online; the web app is a mock for now)
- [ ] "Gusto mo ba ng mas detalyadong paglalarawan?" → "oo".
- [ ] **First time only:** "Ipapadala ang larawan sa aming server at sa serbisyo ng Google
      para mailarawan ito. Sige ba?" "oo" sends; the mock text is read and shown.
- [ ] "hindi" to the consent: nothing is sent; asking again explains it can be changed in
      Settings. Settings → "Detalyadong paglalarawan" cycles Itatanong muna / Pinapayagan /
      Hindi pinapayagan.
- [ ] Guest does the same flow (the request is sent anonymous — check once the real web
      app exists).

## 7. Description screen
- [ ] Thumbnail above the description, scrollbar visible, text readable at all sizes.
- [ ] Options by **gesture** (swipe right/left, double-tap) and **voice**: ulitin,
      mas detalyado, basahin ang teksto (only when text was found), i-save, bagong larawan.
- [ ] "i-save" → "Na-save sa kasaysayan."; History shows it as "larawan (Maglarawan)" with
      the thumbnail; opening it shows the thumbnail and text without re-analysing.
- [ ] "bagong larawan" returns to the source choice.
- [ ] Text size: **A−/A+** buttons, **pinch** in the box, "palakihin" / "paliitin" — each
      says "Laki: N"; limits say "Pinakamalaki na." / "Pinakamaliit na." with a buzz.
- [ ] Two-finger swipe right (and Android back) goes back with the usual announcement.

## 8. Regression
- [ ] Mag-upload and Gamit ang Camera on Capture still go to the **Reader** as before.
- [ ] History: old documents unchanged after the database upgrade (install over the 6B build).
- [ ] Release APK size with the ML Kit labeling model: 137.7 MB (fat APK, all CPU types; `flutter build apk --release --split-per-abi` is smaller).
