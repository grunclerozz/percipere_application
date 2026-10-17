"""Text preprocessing and feature analyzers for Percy's intent classifier.

The app runs the same steps in Dart (`lib/core/percy/percy_text.dart`); any change
here must be made there too (the test vectors check that both agree).
"""

from __future__ import annotations

import re

# Accented letters folded to plain ones (same table as the Dart side).
FOLD = {
    "á": "a", "à": "a", "â": "a", "ä": "a", "ã": "a",
    "é": "e", "è": "e", "ê": "e", "ë": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i",
    "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o",
    "ú": "u", "ù": "u", "û": "u", "ü": "u",
    "ñ": "n", "ç": "c",
}

# Words removed only as the wake word ("Percy, …", "hey Percy …").
WAKE_WORDS = {"percy", "persi", "percey"}

# Common automatic-speech-recognition spellings. These are token replacements
# only; the original text is retained in Percy logs for the team to review.
CORRECTIONS = {
    "aklatann": "aklatan", "aklatam": "aklatan", "libary": "library",
    "seting": "settings", "setings": "settings", "settngs": "settings",
    "maglarawn": "maglarawan", "maglarwan": "maglarawan",
    "ilarawn": "ilarawan", "deskribe": "describe", "describ": "describe",
    "tutoryal": "tutorial", "tutoriyal": "tutorial",
}

# Polite words and speech disfluencies that do not change an intent. "ano" is
# handled below because it introduces meaningful questions such as
# "ano ang kaya mo".
FILLERS = {"po", "opo", "pakisuyo", "pakiusap", "please", "nga", "naman"}

# Never removed: negation changes the meaning (kept here for documentation).
NEGATION_WORDS = {"hindi", "huwag", "wag", "ayoko", "no", "not"}

WORD_NGRAMS = (1, 2)
CHAR_NGRAMS = (3, 5)

_KEEP = re.compile(r"[^a-z0-9 ]")


def preprocess(text: str) -> str:
    """Normalize text without removing negation or meaningful questions."""
    t = text.lower()
    t = "".join(FOLD.get(ch, ch) for ch in t)
    t = t.replace("-", "").replace("'", "").replace("’", "")
    t = _KEEP.sub(" ", t)
    words = t.split()
    corrected = [CORRECTIONS.get(w, w) for w in words]
    kept = []
    for i, w in enumerate(corrected):
        if w in WAKE_WORDS:
            continue
        if w == "hey" and i + 1 < len(corrected) and corrected[i + 1] in WAKE_WORDS:
            continue
        if w in FILLERS:
            continue
        # "ano" is a filler only when it does not start a question. Keep it
        # in "ano ang kaya mo?" and if dropping fillers would erase input.
        if w == "ano" and i + 1 < len(corrected) and corrected[i + 1] not in {"ang", "itong", "iyan", "yun"}:
            continue
        kept.append(w)
    return " ".join(kept) or " ".join(corrected)


def word_features(clean: str) -> list[str]:
    """Word unigrams and bigrams of preprocessed text."""
    words = clean.split()
    out = []
    lo, hi = WORD_NGRAMS
    for n in range(lo, hi + 1):
        for i in range(len(words) - n + 1):
            out.append(" ".join(words[i : i + n]))
    return out


def char_features(clean: str) -> list[str]:
    """Character 3–5-grams inside each word padded with spaces (" word ").

    A padded word shorter than n gives no n-gram of that length.
    """
    out = []
    lo, hi = CHAR_NGRAMS
    for w in clean.split():
        padded = f" {w} "
        for n in range(lo, hi + 1):
            for i in range(len(padded) - n + 1):
                out.append(padded[i : i + n])
    return out
