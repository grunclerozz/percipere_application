# Back navigation, app-wide (Phase 6B)

One back action, three ways in — all behave the same:

- **Gesture:** **two-finger swipe right** on the Gesture Pad; reserved for back on every
  screen. On screens without a Gesture Pad (Welcome), detected anywhere on screen.
- **Voice:** "bumalik", "bumalik ng page", "balik", "bumalik sa nakaraang page", "back",
  "go back". ("nakaraan" / "previous" stay = previous option or sentence only.)
- **System back:** Android back button and edge swipe go through the same action via
  `PopScope`.

Behavior:
- Announce the destination: "Bumalik sa Welcome".
- Unsaved input → confirm first: "May hindi pa naka-save. Sigurado ka bang babalik?"
- On **Welcome**: "Nasa simula ka na", then confirm before closing the app.
- In the **Reader**: stop speech and save the position first.
- In **profiling**: back keeps values already chosen.

Gesture-map consequences (see `decisions.md`, 2026-10-01): two-finger swipe right was
"next paragraph" in the Reader and two-finger swipe down was "back"; both are reassigned.

## Reader text size (Priority 3)

The Gesture Pad table is **unchanged** (two-finger swipe up/down stay previous/next
paragraph). Text size lives on the **Document Box**, so the pad's controls stay stable:

| Input | Action |
|---|---|
| Tap **A+** / **A−** (top of the Document Box, ≥ 48 dp; spoken "Palakihin ang teksto" / "Paliitin ang teksto") | bigger / smaller |
| **Pinch** inside the Document Box (out / in) | bigger / smaller (one step per ~18 % change of finger spread; two fingers don't scroll) |
| Voice "palakihin", "lakihan", "bigger", "zoom in" / "paliitin", "liitan", "smaller", "zoom out" | bigger / smaller |

All three send `NavIntent.textBigger` / `textSmaller`, so they behave identically.
- Steps of 2 sp, 18–48 sp; the same range as profiling Step 2 and Settings.
- At a limit: "Pinakamalaki na." / "Pinakamaliit na." with an error haptic.
- Each change shows "Laki: N" in the caption strip. While reading it is spoken at the
  **next sentence break** (the sentence is never cut off); otherwise it is spoken at once.
- The sentence being read is kept in view after the text reflows.
- The size is saved to the user's preferences (`ui.textSize`): it applies to future
  documents and shows in Settings.
- The Maglarawan (description) screen is not built yet; when it is, it should reuse
  `DocumentBox(onTextSize: …)`.
