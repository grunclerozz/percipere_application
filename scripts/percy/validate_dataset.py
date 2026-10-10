"""Checks data/percy/intents.csv and prints how many examples each intent has.

Usage (from the project folder):
    scripts\\percy\\.venv\\Scripts\\python scripts\\percy\\validate_dataset.py [path]

Exit code 1 when there are errors (unknown intent, empty text, duplicates,
missing columns); warnings (fewer than 30 examples) don't fail.
"""

from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

from percy_text import preprocess

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CSV = ROOT / "data" / "percy" / "intents.csv"

INTENTS = [
    "open_home", "open_library", "open_settings", "back", "next_option",
    "previous_option", "select", "cancel", "help", "where_am_i", "read", "pause",
    "resume", "stop", "repeat", "faster", "slower", "bigger_text", "smaller_text",
    "open_item", "greeting", "thanks", "goodbye", "yes", "no", "out_of_scope",
]
COLUMNS = ["text", "intent", "author", "source", "notes"]
STARTER = "Starter (Claude)"
MIN_EXAMPLES = 30


def load(path: Path) -> list[dict]:
    """Reads the CSV (UTF-8, with or without BOM)."""
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in COLUMNS if c not in (reader.fieldnames or [])]
        if missing:
            raise ValueError(f"missing columns: {', '.join(missing)}")
        return [{k: (v or "").strip() for k, v in row.items() if k} for row in reader]


def is_starter(row: dict) -> bool:
    return row.get("source", "") == STARTER


def check(rows: list[dict]) -> tuple[list[str], list[str]]:
    """Returns (errors, warnings)."""
    errors, warnings = [], []
    seen_raw: dict[str, int] = {}
    seen_clean: dict[str, int] = {}
    for line, row in enumerate(rows, start=2):  # line 1 is the header
        text, intent = row["text"], row["intent"]
        if not text or not preprocess(text):
            errors.append(f"line {line}: empty text")
            continue
        if intent not in INTENTS:
            errors.append(f'line {line}: unknown intent "{intent}" ("{text}")')
        raw, clean = " ".join(text.lower().split()), preprocess(text)
        if raw in seen_raw:
            errors.append(
                f'line {line}: duplicate of line {seen_raw[raw]} ("{text}")'
            )
        elif clean in seen_clean:
            # Same once cleaned (e.g. only the wake word differs): harmless,
            # but training keeps only the first.
            warnings.append(
                f'line {line}: same as line {seen_clean[clean]} after '
                f'preprocessing ("{text}"); training uses it once'
            )
        seen_raw.setdefault(raw, line)
        seen_clean.setdefault(clean, line)
    counts = Counter(r["intent"] for r in rows)
    for intent in INTENTS:
        if counts[intent] < MIN_EXAMPLES:
            warnings.append(
                f"{intent}: only {counts[intent]} examples (aim for {MIN_EXAMPLES}+)"
            )
    return errors, warnings


def summary(rows: list[dict]) -> str:
    team = Counter(r["intent"] for r in rows if not is_starter(r))
    starter = Counter(r["intent"] for r in rows if is_starter(r))
    lines = [f"{'intent':<16} {'team':>5} {'starter':>8} {'total':>6}"]
    for intent in INTENTS:
        t, s = team[intent], starter[intent]
        flag = "  <-- under 30" if t + s < MIN_EXAMPLES else ""
        lines.append(f"{intent:<16} {t:>5} {s:>8} {t + s:>6}{flag}")
    lines.append(
        f"{'TOTAL':<16} {sum(team.values()):>5} {sum(starter.values()):>8} {len(rows):>6}"
    )
    return "\n".join(lines)


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CSV
    rows = load(path)
    errors, warnings = check(rows)
    print(f"{path}: {len(rows)} rows\n")
    print(summary(rows))
    if warnings:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print("  WARN", w)
    if errors:
        print(f"\n{len(errors)} error(s):")
        for e in errors:
            print("  ERROR", e)
        return 1
    print("\nNo errors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
