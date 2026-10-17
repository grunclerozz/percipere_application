#!/usr/bin/env python3
"""Generates Percy's bundled voice clips with ElevenLabs.

Reads every FIXED Percy sentence (assets/percy/responses.json, the answers in
assets/percy/knowledge.json, the persona greeting, and the ARB keys in
extra_arb_keys.json), asks the ElevenLabs
text-to-speech API for one small mono mp3 per sentence, and writes them to
assets/percy/voice/ together with manifest.json.

The API key is read ONLY from the environment variable ELEVENLABS_API_KEY.
It is never written to a file, a log or the output.

Clips are per sentence because the app speaks one sentence at a time
(Announcer.splitSentences). Sentences with {placeholders} are dynamic and
are skipped: the app speaks them with its offline voice.

The clip name and the manifest key must match
lib/core/percy/percy_clips.dart (PercyClipKey): sha256("<lang>|<text>")
first 16 hex characters, text trimmed with whitespace runs collapsed.
"""

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

VOICE_ID = "u0P5zPuh3SvxTi9vSTCn"  # not a secret
DEFAULT_MODEL = "eleven_multilingual_v2"
OUTPUT_FORMAT = "mp3_22050_32"  # mono, 22.05 kHz, 32 kbps
# Models that accept language_code (the others work out the language from the text).
LANGUAGE_CODE_MODELS = {"eleven_v3", "eleven_v4", "eleven_v4_turbo"}
LANGS = ("fil", "en")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VOICE_DIR = os.path.join(ROOT, "assets", "percy", "voice")
MANIFEST = os.path.join(VOICE_DIR, "manifest.json")


def normalize(text):
    return re.sub(r"\s+", " ", text).strip()


def clip_key(lang, text):
    return hashlib.sha256(f"{lang}|{normalize(text)}".encode("utf-8")).hexdigest()[:16]


def split_sentences(text):
    # Same rule as Announcer.splitSentences.
    return [s for s in (normalize(p) for p in re.split(r"(?<=[.!?…])\s+", text)) if s]


def lines_in(entry):
    """Yields (lang, line) from {lang: {politeness: [lines]}}."""
    if not isinstance(entry, dict):
        return
    for lang in LANGS:
        by_lang = entry.get(lang)
        if not isinstance(by_lang, dict):
            continue
        for lines in by_lang.values():
            if isinstance(lines, list):
                for line in lines:
                    if isinstance(line, str):
                        yield lang, line


def collect():
    """Returns {key: (lang, sentence)} for every fixed sentence."""
    found = {}

    def add(lang, line):
        for sentence in split_sentences(line):
            if "{" in sentence or not re.search(r"\w", sentence):
                continue
            found[clip_key(lang, sentence)] = (lang, sentence)

    with open(os.path.join(ROOT, "assets", "percy", "responses.json"), encoding="utf-8") as f:
        responses = json.load(f)
    for section in ("intents", "dialogue"):
        for entry in responses.get(section, {}).values():
            for lang, line in lines_in(entry):
                add(lang, line)
    with open(os.path.join(ROOT, "assets", "percy", "knowledge.json"), encoding="utf-8") as f:
        knowledge = json.load(f)
    for topic in knowledge.get("topics", []):
        for lang, line in lines_in(topic.get("answer")):
            add(lang, line)
    with open(os.path.join(ROOT, "assets", "percy", "persona.json"), encoding="utf-8") as f:
        persona = json.load(f)
    for lang, line in lines_in(persona.get("greeting")):
        add(lang, line)

    with open(os.path.join(os.path.dirname(__file__), "extra_arb_keys.json"), encoding="utf-8") as f:
        keys = json.load(f)["keys"]
    for lang in LANGS:
        with open(os.path.join(ROOT, "lib", "l10n", f"app_{lang}.arb"), encoding="utf-8") as f:
            arb = json.load(f)
        for key in keys:
            if isinstance(arb.get(key), str):
                add(lang, arb[key])
    return found


def load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            return json.load(f)
    return {"version": 1, "clips": {}}


def save_manifest(manifest):
    tmp = MANIFEST + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, MANIFEST)


def synthesize(api_key, model, lang, text):
    body = {"text": text, "model_id": model}
    if model in LANGUAGE_CODE_MODELS:
        body["language_code"] = lang
    url = (
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
        f"?output_format={OUTPUT_FORMAT}"
    )
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read()
        except urllib.error.HTTPError as e:
            detail = e.read()[:300].decode("utf-8", "replace")
            if e.code in (429, 500, 502, 503) and attempt < 4:
                time.sleep(2 ** (attempt + 1))
                continue
            raise RuntimeError(f"HTTP {e.code}: {detail}") from None
        except urllib.error.URLError as e:
            if attempt < 4:
                time.sleep(2 ** (attempt + 1))
                continue
            raise RuntimeError(f"network error: {e.reason}") from None


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--model", default=DEFAULT_MODEL, help="ElevenLabs model id")
    parser.add_argument("--dry-run", action="store_true",
                        help="list what would be generated; no API call, no key needed")
    parser.add_argument("--prune", action="store_true",
                        help="delete clips of sentences that no longer exist")
    parser.add_argument("--check", action="store_true",
                        help="compare the manifest with the current lines: 'N of M have clips'; "
                             "no API call, no key needed")
    parser.add_argument("--limit", type=int, default=0,
                        help="generate at most N new clips (try a few first)")
    args = parser.parse_args()

    wanted = collect()
    manifest = load_manifest()
    clips = manifest.setdefault("clips", {})

    todo = []
    for key, (lang, text) in sorted(wanted.items(), key=lambda kv: (kv[1][0], kv[1][1])):
        have = clips.get(key)
        path = os.path.join(VOICE_DIR, f"{lang}_{key}.mp3")
        current = (
            have is not None
            and os.path.exists(path)
            and have.get("voice_id") == VOICE_ID
            and have.get("model") == args.model
        )
        if not current:
            todo.append((key, lang, text))

    stale = [k for k in clips if k not in wanted]
    if args.check:
        have = len(wanted) - len(todo)
        chars_left = sum(len(t) for _, _, t in todo)
        print(f"{have} of {len(wanted)} lines have clips "
              f"({sum(1 for k, v in wanted.items() if v[0] == 'fil')} fil, "
              f"{sum(1 for k, v in wanted.items() if v[0] == 'en')} en in total)")
        print(f"Missing: {len(todo)} lines ({chars_left} characters)")
        print(f"Stale clips (text no longer used): {len(stale)}")
        for _, lang, text in todo[:5]:
            print(f"  missing [{lang}] {text}")
        if len(todo) > 5:
            print(f"  ... and {len(todo) - 5} more")
        print("All lines have clips." if not todo else "Not finished: run the script without --check.")
        return 0

    chars = sum(len(t) for _, _, t in todo)
    print(f"Fixed sentences: {len(wanted)} "
          f"({sum(1 for v in wanted.values() if v[0] == 'fil')} fil, "
          f"{sum(1 for v in wanted.values() if v[0] == 'en')} en)")
    print(f"Already generated: {len(wanted) - len(todo)}")
    print(f"To generate: {len(todo)} ({chars} characters)")
    print(f"Stale clips (text no longer used): {len(stale)}"
          + (" - run with --prune to delete them" if stale and not args.prune else ""))

    if args.prune:
        for key in stale:
            entry = clips.pop(key)
            try:
                os.remove(os.path.join(VOICE_DIR, entry["file"]))
            except OSError:
                pass
        if stale and not args.dry_run:
            save_manifest(manifest)

    if args.dry_run:
        for _, lang, text in todo[:10]:
            print(f"  [{lang}] {text}")
        if len(todo) > 10:
            print(f"  ... and {len(todo) - 10} more")
        return 0
    if not todo:
        print("Nothing to do.")
        return 0

    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("ELEVENLABS_API_KEY is not set (see tool/percy_voice/README.md).", file=sys.stderr)
        return 2

    os.makedirs(VOICE_DIR, exist_ok=True)
    manifest["version"] = 1
    manifest["voice_id"] = VOICE_ID
    manifest["output_format"] = OUTPUT_FORMAT
    used = 0
    done = 0
    for key, lang, text in todo:
        if args.limit and done >= args.limit:
            break
        name = f"{lang}_{key}.mp3"
        try:
            audio = synthesize(api_key, args.model, lang, text)
        except RuntimeError as e:
            print(f"FAILED [{lang}] {text[:40]!r}: {e}", file=sys.stderr)
            save_manifest(manifest)
            print(f"Stopped. Characters used so far: {used}")
            return 1
        with open(os.path.join(VOICE_DIR, name), "wb") as f:
            f.write(audio)
        clips[key] = {
            "file": name,
            "lang": lang,
            "text": text,
            "voice_id": VOICE_ID,
            "model": args.model,
            "date": datetime.date.today().isoformat(),
        }
        manifest["model"] = args.model
        manifest["date"] = datetime.date.today().isoformat()
        save_manifest(manifest)  # progress survives an interruption
        used += len(text)
        done += 1
        print(f"[{done}/{len(todo)}] {name} ({len(audio)} bytes)")
    print(f"Done. Generated {done} clips, {used} characters used.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
