# Profiling: guided setup after login (Phase 6B)

Mockups: `docs/ui/customization_1.png` (text color), `customization_2.png` (text size).
**Mockup wording wins.**

## Every step
- Own screen in the existing design: eye logo, (preview box where relevant), Speaking Zone
  with the question, Gesture Pad.
- Speaks the question and how to answer **by voice and by gesture**.
- **Previews every change live** (see or hear the result at once).
- Announces progress: "Hakbang 3 ng 10".
- Supports **ulitin/repeat**, **back** (`navigation.md`), **laktawan/skip** (keeps the
  default), **confirm** (double-tap or "okay" / "sige").
- Progress is saved per step, so an interrupted setup resumes where it stopped.

## Steps
**Main question**
1. **Navigation mode** — "Paano mo gustong gamitin ang app: sa boses o sa galaw?"
   Pa-boses (Voice) / Pa-galaw (Gestures). From here on the chosen mode is primary.
   Long-press on the Gesture Pad still starts listening in gesture mode.

**Look of the text** — first ask "Nakakakita ka ba ng kahit kaunting teksto sa screen?"
If **no**: skip Steps 2–3, keep defaults.

2. **Text size** — "Nababasa mo ba ng maayos ang texto?" Sample paragraph. Swipe up /
   "palakihin" = bigger; swipe down / "paliitin" = smaller. Announce "Laki ng teksto: 24".
   Range **18–48 sp**.
3. **Text color** — "Anong kulay ang nais mo sa texto?" Swipe left/right or "susunod" /
   "nakaraan" through the colors; sample updates live; each color's Filipino name spoken.
   Only the **current theme's list**, in order; first = theme default. Lists live in
   `lib/config/palette.dart` (Filipino name, English name, hex) and Settings uses the same:
   - **Cream & Navy:** Navy #0B2A45 (default), Itim #111111, Kayumanggi #3E2723,
     Lila #4A148C, Asul #0D47A1.
   - **Dark mode with yellow text:** Dilaw #FFEB3B (default), Melokoton #FFCC80,
     Puti #FFFFFF, Malambot na puti #E8E6E3, Mapusyaw na cyan #80DEEA,
     Mapusyaw na asul #90CAF9.
   - **Dark mode with white text:** Puti #FFFFFF (default), Malambot na puti #E8E6E3,
     Dilaw #FFEB3B, Melokoton #FFCC80, Mapusyaw na cyan #80DEEA, Mapusyaw na asul #90CAF9.
   All ≥ 7:1 contrast on their theme background (checked 2026-10-01: lowest is Asul 7.87
   on cream; dark lists ≥ 12.0 on #000000, ≥ 10.7 on #121212). A test enforces it.

**TTS settings**

4. **Voice language** — "Gusto mo ba ang boses sa Ingles o sa Tagalog?" Plays a sample in
   each. If fil-PH isn't installed: explain in English, offer Android TTS settings.
5. **Speed** — "Gusto mo bang bilisan ang boses?" Swipe up / "bilisan", swipe down /
   "bagalan". Sample after each change, value announced. **0.5×–2.0×, steps of 0.25.**
6. **Tone** — "Gusto mo bang palitan ang tono ng boses?" Swipe up / "taasan", swipe down /
   "babaan". Sample after each change. Pitch **0.5–2.0**.

**General customization**

7. **Theme** — "Anong tema ang gusto mong simulan?" Swipe through live whole-screen
   previews, names spoken: **Cream & Navy** (default), **Dark mode with yellow text** (high
   contrast, color-blind friendly), **Dark mode with white text**. If the Step-3 text color
   isn't in the new theme's list → switch to that theme's default and say "Pinalitan ang
   kulay ng teksto para mas mabasa." Same rule whenever the theme changes in Settings.
8. **Vibration** — "Gusto mo bang mag-vibrate ang phone kapag may ginagawa ka?" Sample
   vibration, then on/off. Off disables all haptics app-wide.
9. **Auto-read documents** — "Gusto mo bang awtomatikong basahin ang dokumento pagkatapos
   itong i-upload o i-scan?"
   - On: reading starts when extraction finishes.
   - Off: "Handa na ang dokumento. Mag-double-tap para simulan ang pagbasa." Reading
     starts with a double-tap on the Gesture Pad or "basahin".
   - Prompts/announcements are always spoken regardless.

**Summary**

10. Read the chosen settings back briefly, show them as a list, ask "Tama ba ang lahat?"
    Confirm, or jump back to a step by voice ("bumalik sa bilis") or by swiping the list +
    double-tap. On confirm: save to the user's preferences, mark profiling completed, go
    to Capture.

## Settings integration
- Every profiling preference is editable in Settings (same color lists, same theme rule).
- Add **"Ulitin ang setup"** (redo profiling) and **Logout** (spoken confirmation).
