# Percipere — system test checklist

Use this for every round of testing (each phase, each fix, before a study session).
Run it on the real tablet/phone, in **both navigation modes** (gestures and voice) and at
**least two text sizes** (default and 48). Tick a box only if it worked the first time;
write what happened under "Notes" if it did not.

Round: ______  Date: ______  Build/commit: ______  Device: ______  Tester: ______

Result key: ✅ pass · ❌ fail · ⚠️ works but poorly · — not tested

---

## 1. Correct input
Documents and photos that should work perfectly.
- [ ] Clear printed page (photo, good light): read aloud, text matches the page.
- [ ] Clean PDF with selectable text: read aloud without OCR delay.
- [ ] DOCX with headings and paragraphs: all paragraphs read, in order.
- [ ] Clear image with text (upload): text found and read.
- [ ] Maglarawan: clear photo of common objects (food, cup, table): described in Filipino.
- [ ] Filipino text, English text and mixed text all read with the right pronunciation.
- [ ] Library: the document is saved automatically and reopens with the same text.

## 2. Wrong input
Things the user should never be able to break.
- [ ] Unsupported file (e.g. .zip, .mp3, video): clear spoken message, no crash.
- [ ] Empty PDF / empty DOCX / blank page: "no text found" message, no silence.
- [ ] Corrupted or password-protected PDF: spoken error, app stays usable.
- [ ] Photo of something with no text (floor, wall): says it found nothing, offers to retry.
- [ ] Picking a file then cancelling the picker: announced, back on the same screen.
- [ ] Wrong password / unknown email at login: spoken reason, can try again.
- [ ] Register with an existing email, a short password, or empty fields: each says what is wrong.
- [ ] Voice: nonsense words or a command from another screen: "not understood" and a list of what works here.
- [ ] Image that is not a photo (screenshot, drawing) in Maglarawan: sensible answer or a clear "can't tell".

## 3. Blurry, dark and bad-quality input
- [ ] Blurry photo of a page: warns the user, does not read garbage as if it were fine.
- [ ] Too dark / too bright photo: guidance to change the light.
- [ ] Tilted, cropped or partly covered page: reads what is readable, says it may be incomplete.
- [ ] Low-contrast or faded print: result quality reported honestly.
- [ ] Handwriting: does not claim certainty; says reading may be poor.
- [ ] Camera guidance (move closer, hold steady, ready) matches what is really happening.
- [ ] Blurry/dark picture in Maglarawan: "Hindi ko matiyak…" instead of a wrong description.
- [ ] Same page, retaken after the warning: result is better and the warning goes away.

## 4. Long input
- [ ] 20+ page PDF: opens in a reasonable time, no freeze, memory stays stable.
- [ ] One very long paragraph (no line breaks): reads without cutting off or stuttering.
- [ ] Very long document read for 10+ minutes: TTS does not stop or drift out of sync.
- [ ] Pause in the middle, leave the screen, come back: resumes in the right place.
- [ ] Skip forward/back across many paragraphs: position is correct, text on screen follows.
- [ ] Scrolling/highlighting keeps the current sentence in view.
- [ ] Large file saved to the Library: saves, reopens and deletes cleanly.
- [ ] Text size 48 on a long document: nothing overlaps or gets cut off.

## 5. Accuracy of voice commands
Say each command 10 times (normal pace) and record how many were understood.
- [ ] Core commands (basahin, i-pause, ituloy, susunod, nakaraan, ulitin, bumalik): ___/10 each.
- [ ] Yes/no answers (oo, hindi, sige, ayaw): ___/10.
- [ ] Screen-specific commands on Home, Capture, Library, details, Reader, Description, Settings.
- [ ] Filipino and English versions of the same command both work.
- [ ] Natural phrasing ("sige, basahin mo na") still works.
- [ ] Different speakers: man, woman, older person, someone with a strong accent.
- [ ] Quiet room vs. background noise (TV, traffic, people talking).
- [ ] Phone held close vs. at arm's length.
- [ ] Misheard but close command: asks "Ang ibig mo bang sabihin ay …?" instead of guessing.
- [ ] Wrong command is never run by mistake (note any false positives): ______
- [ ] Command is heard but not understood: says so, does not just stay silent.
- [ ] Recognition language/locale correct for Filipino speech.

## 6. Linaw ng tone (voice clarity of the app's speech)
- [ ] Filipino words pronounced correctly (note mispronounced words): ______
- [ ] English words and numbers pronounced correctly.
- [ ] Speech speed is comfortable at the default; speed setting changes it.
- [ ] Volume is clear at the device's normal volume and with the speaker (no headphones).
- [ ] Works with headphones/earphones and with a Bluetooth speaker.
- [ ] Pauses between sentences and paragraphs sound natural.
- [ ] Abbreviations, dates, money and long numbers read sensibly.
- [ ] Announcements are short and clear (not too long or repeated).
- [ ] Brief vs. detailed verbosity setting changes the amount of speech.
- [ ] Voice choice/pitch settings work and are saved.
- [ ] Listening to it for 10 minutes is not tiring (tester's opinion): ______

## 7. Understanding vs. just reading
Does the app understand what the person says and does, or does it keep reading?
- [ ] Say "pause" or "itigil" while it is reading: stops within about 1–2 seconds.
- [ ] Say a new command mid-sentence: current speech stops, new command runs.
- [ ] The microphone does not pick up the app's own speech and answer itself.
- [ ] After reading finishes, the app announces it and waits (does not restart or loop).
- [ ] The app does not listen forever without feedback; says when it gives up or fails.
- [ ] Questions it asks (yes/no) wait for an answer; silence is handled with a reminder.
- [ ] The user always knows which screen they are on and what they can do (help/"tulong").
- [ ] Reader reacts to a command the same way by voice, gesture and tap.
- [ ] Description (Maglarawan) answers match the picture; repeats on request.

## 8. Spamming and abuse of gestures and taps
- [ ] Swipe left/right 20 times fast: focus moves in order, no skipped or frozen state.
- [ ] Double-tap the same action 10 times fast: runs once (or safely), no duplicate saves or crashes.
- [ ] Mix swipes, taps and two-finger gestures at the same time: no crash.
- [ ] Spam the back gesture and the Android back button: no black screen, no exit by accident.
- [ ] Spam next/previous paragraph while reading: speech and screen stay in sync.
- [ ] Spam pause/resume: ends in a clear state (paused or reading), never both.
- [ ] Spam text size A−/A+ and pinch: stays between 18 and 48, limits announced.
- [ ] Spam "i-save" / save button: one Library item only.
- [ ] Spam the camera shutter: one picture, no crash.
- [ ] Say commands rapidly one after another: each handled or ignored cleanly.
- [ ] Gesture + voice at the same time: no conflict, no double action.
- [ ] Palm/accidental touches while the phone is held: nothing destructive happens.
- [ ] After all the spamming, the app still speaks and responds normally.

## 9. Interruptions and device conditions
- [ ] Incoming phone call during reading: reading stops; after the call it can be resumed.
- [ ] Notification sound/another app's audio: the app recovers.
- [ ] Switch to another app and come back: same screen, same position.
- [ ] Screen lock and unlock while reading.
- [ ] Rotate the device (if allowed): no lost state.
- [ ] Low battery / battery saver mode.
- [ ] Low storage space: save fails with a spoken message, not a crash.
- [ ] Kill the app and reopen: login, preferences and Library are still there.

## 10. Permissions and connectivity
- [ ] Microphone permission denied: spoken explanation, gestures still work.
- [ ] Camera permission denied: spoken explanation, upload still works.
- [ ] Permission granted later from Settings: works without reinstalling.
- [ ] Offline (airplane mode): reading, OCR, the Library and downloaded books, and offline descriptions all work.
- [ ] Online detail request: works with consent; clear message if the server is down.
- [ ] Connection lost in the middle of a request: spoken error, can try again.
- [ ] Slow connection: waiting is announced, no hang.

## 11. Accounts, profiles and privacy
- [ ] Register, log in, log out, log in again: settings stay per user.
- [ ] Guest mode: everything works, nothing is tied to a name; guest data is clearly temporary.
- [ ] Two users on one device: Library and settings do not mix.
- [ ] Forgot password flow completes.
- [ ] Password is never shown or spoken aloud.
- [ ] Consent for image upload: asked first time, respected, changeable in Settings.
- [ ] Deleting Library items removes text, covers, favorites and collection links.

## 12. Accessibility and usability
- [ ] Every screen announces itself when opened.
- [ ] Every action works by gesture, voice and tap.
- [ ] Touch targets are easy to hit (56 dp or bigger).
- [ ] All three color themes readable; contrast is good; no meaning by color alone.
- [ ] Text size setting applies on all screens.
- [ ] Haptic feedback present and not annoying; can be turned off.
- [ ] A visually impaired participant can finish the main task without help (Reader, then Maglarawan).
- [ ] Time to finish the first task: ______ (note for the study)
- [ ] Number of times the user needed help or got lost: ______

## 13. Performance and stability
- [ ] App start time acceptable (note seconds): ______
- [ ] OCR time for one page (note seconds): ______
- [ ] No freezing or lag while TTS is reading.
- [ ] No crash in 30 minutes of mixed use.
- [ ] Memory/battery use acceptable over a long session.
- [ ] Release build behaves the same as debug (R8/proguard issues).

## 14. Regression (after any change)
- [ ] Sign-in and Profiling still work.
- [ ] Home (Magbasa ng bago, Aklatan) and Capture order: Mag-upload, Gamit ang Camera, Maglarawan.
- [ ] Reader controls (pause, skip, repeat, text size) work.
- [ ] Voice commands from earlier phases still match.
- [ ] Library: old history entries open after an update.
- [ ] Saved settings survive an update.

---

## 15. Report an Issue (Mag-report ng problema)
Spec: `docs/specs/report-an-issue.md`. Build with `API_BASE_URL` to send reports to the dashboard.

**Each type:**
- [ ] Bug: all 7 pages, including "Gaano kalala".
- [ ] Mungkahi and Puna: the severity page is **skipped**. Step numbers say "ng 5", not "ng 6".
- [ ] Each page speaks its question and options when it opens; severity options say their explanation.
- [ ] Options work by name in Filipino and in English ("may sira" / "bug", "kritikal" / "critical", "aklatan" / "library", "iba pa" / "other").

**Dictation:**
- [ ] The description is read back ("Narinig ko: … Tama ba?").
- [ ] "oo" keeps it; "hindi" asks again.
- [ ] "Magsalita" or a long-press dictates again.
- [ ] Typing works too.
- [ ] Under 10 characters is refused; over 1000 is refused.

**Email:**
- [ ] Logged in: "Gamitin ang email na ito: …?" "oo" uses it; "hindi" lets you say or type another.
- [ ] A wrong email ("juan at example") is caught.
- [ ] Guest: "laktawan" works and the review says "walang email".

**Review and ticket:**
- [ ] The review reads all answers, the automatic details (app version, Android, model, screen, date) and the RA 10173 line.
- [ ] "Baguhin" → choose a part → that page → back to the review with the change.
- [ ] Ticket `PRC-YYYYMMDD-XXXX`, read character by character, with no 0, O, 1 or I in the last 4.
- [ ] "Ulitin" repeats the ticket; "Tapos na" returns to the screen it was opened from.

**Offline, then online:**
- [ ] Wi-Fi off → Ipadala → "Naghihintay ipadala" and "Naka-save ang report…".
- [ ] Wi-Fi on → within a few seconds the report reaches Dashboard → Feedback & Bugs. The ticket and "Opened from" show in the details, and "Aking mga report" says Naipadala.
- [ ] Close the app while offline, reopen it online → the report is sent at start.
- [ ] The same report never appears twice in the dashboard.

**Cancel and back:**
- [ ] "bumalik" or the two-finger swipe goes to the previous page on every page.
- [ ] Page 1 with answers asks before leaving.
- [ ] "kanselahin" on every page asks first; "hindi" stays, "oo" leaves without saving.

**Opening it:**
- [ ] Settings → "Mag-report ng problema".
- [ ] Home link.
- [ ] Saying "mag-report" or "may problema" on any screen.
- [ ] Percy: "gusto kong mag-report ng problema".

**Robustness and accessibility:**
- [ ] Spam gestures (fast swipes, double-taps, back) on every page: no crash and no double report.
- [ ] TalkBack: every option, field and button is read; the text fields have their labels.
- [ ] Largest text size: everything fits or scrolls; theme colors are used.
- [ ] "Aking mga report": the list shows ticket, type, date and status; choosing one reads the details.

## Result log
| Section | ✅ | ❌ | ⚠️ | Notes / bugs found |
|---|---|---|---|---|
| 1 Correct input | | | | |
| 2 Wrong input | | | | |
| 3 Blurry input | | | | |
| 4 Long input | | | | |
| 5 Voice accuracy | | | | |
| 6 Linaw ng tone | | | | |
| 7 Understands vs. keeps reading | | | | |
| 8 Gesture spamming | | | | |
| 9 Interruptions | | | | |
| 10 Permissions / connectivity | | | | |
| 11 Accounts / privacy | | | | |
| 12 Accessibility | | | | |
| 13 Performance | | | | |
| 14 Regression | | | | |

### Voice accuracy table (section 5)
| Command | Tries | Understood | Wrong action | Not understood | Notes |
|---|---|---|---|---|---|
| | | | | | |

Accuracy = understood ÷ tries. Wrong action = a different command ran (most serious).
