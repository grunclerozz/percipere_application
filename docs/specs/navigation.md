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
