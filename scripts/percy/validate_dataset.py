"""Checks data/percy/intents.csv and prints how many examples each intent has.

Usage (from the project folder):
    scripts\\percy\\.venv\\Scripts\\python scripts\\percy\\validate_dataset.py [path]

Also checks data/percy/test_team.csv (the fixed, team-written test set): lines
starting with "#" are comments, blank/template rows are rejected, and no
training phrase may match a test phrase after preprocessing (leakage).

Exit code 1 when there are errors (unknown intent, empty text, duplicates,
a phrase in two intents, leakage, missing columns); warnings (fewer than 30
examples) don't fail.
"""

from __future__ import annotations

import csv
import sys
from collections import Counter
from pathlib import Path

from percy_text import preprocess

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CSV = ROOT / "data" / "percy" / "intents.csv"
TEST_CSV = ROOT / "data" / "percy" / "test_team.csv"

INTENTS = [
    "open_home", "open_library", "open_settings", "back", "next_option",
    "previous_option", "select", "cancel", "help", "where_am_i", "read", "pause",
    "resume", "stop", "repeat", "faster", "slower", "bigger_text", "smaller_text",
    "open_item", "greeting", "thanks", "goodbye", "yes", "no", "out_of_scope",
    "report_issue",  # Phase 10
    # Percy smarter (feat/percy-smarter): not in the bundled model until retrained.
    "describe_image", "more_detail", "read_image_text", "tutorial", "set_speed",
]
# Intents whose team-written test phrases are required before retraining.
NEW_INTENTS = ["describe_image", "more_detail", "read_image_text", "tutorial", "set_speed"]
MIN_TEAM_TEST = 8
COLUMNS = ["text", "intent", "author", "source", "notes"]
STARTER = "Starter (Claude)"
GENERATED = "Generated (Codex)"
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


def source_kind(row: dict) -> str:
    """One of "starter", "generated" or "team" (anything else is team-written)."""
    src = row.get("source", "")
    if src == STARTER:
        return "starter"
    if src == GENERATED:
        return "generated"
    return "team"


def load_test(path: Path = TEST_CSV) -> tuple[list[dict], list[str]]:
    """Reads the fixed team test set. Returns (rows, errors).

    Lines starting with "#" and blank lines are skipped. Rows with empty text
    or an unknown intent are errors (they would be template leftovers).
    """
    with open(path, encoding="utf-8-sig", newline="") as f:
        lines = [ln for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
    reader = csv.DictReader(lines)
    missing = [c for c in COLUMNS if c not in (reader.fieldnames or [])]
    if missing:
        raise ValueError(f"{path.name}: missing columns: {', '.join(missing)}")
    rows, errors, seen = [], [], {}
    for n, row in enumerate(reader, start=1):
        row = {k: (v or "").strip() for k, v in row.items() if k}
        if not row["text"] or not preprocess(row["text"]):
            errors.append(f"{path.name} row {n}: empty text (template row?)")
            continue
        if row["intent"] not in INTENTS:
            errors.append(f'{path.name} row {n}: unknown intent "{row["intent"]}"')
            continue
        clean = preprocess(row["text"])
        if clean in seen:
            errors.append(f'{path.name} row {n}: same as row {seen[clean]} after preprocessing ("{row["text"]}")')
            continue
        seen[clean] = n
        rows.append(row)
    return rows, errors


def leakage(train_rows: list[dict], test_rows: list[dict]) -> list[dict]:
    """Training rows whose preprocessed text equals a test row's."""
    test_clean = {preprocess(r["text"]) for r in test_rows}
    return [r for r in train_rows if preprocess(r["text"]) in test_clean]


def conflicts(rows: list[dict]) -> list[str]:
    """Phrases that appear (after preprocessing) in two different intents."""
    seen: dict[str, set[str]] = {}
    for r in rows:
        seen.setdefault(preprocess(r["text"]), set()).add(r["intent"])
    return [f'"{c}" is in {", ".join(sorted(i))}' for c, i in seen.items() if len(i) > 1]


def team_test_gaps(test_rows: list[dict]) -> dict[str, int]:
    """New intents with fewer than MIN_TEAM_TEST team-written test phrases."""
    counts = Counter(r["intent"] for r in test_rows if source_kind(r) == "team")
    return {i: counts[i] for i in NEW_INTENTS if counts[i] < MIN_TEAM_TEST}


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
    for c in conflicts(rows):
        errors.append(f"phrase in two intents: {c}")
    counts = Counter(r["intent"] for r in rows)
    for intent in INTENTS:
        if counts[intent] < MIN_EXAMPLES:
            warnings.append(
                f"{intent}: only {counts[intent]} examples (aim for {MIN_EXAMPLES}+)"
            )
    return errors, warnings


def summary(rows: list[dict]) -> str:
    kinds = {k: Counter(r["intent"] for r in rows if source_kind(r) == k)
             for k in ("team", "generated", "starter")}
    lines = [f"{'intent':<16} {'team':>5} {'generated':>10} {'starter':>8} {'total':>6}"]
    for intent in INTENTS:
        t, g, s = kinds["team"][intent], kinds["generated"][intent], kinds["starter"][intent]
        flag = "  <-- under 30" if t + g + s < MIN_EXAMPLES else ""
        lines.append(f"{intent:<16} {t:>5} {g:>10} {s:>8} {t + g + s:>6}{flag}")
    lines.append(
        f"{'TOTAL':<16} {sum(kinds['team'].values()):>5} "
        f"{sum(kinds['generated'].values()):>10} {sum(kinds['starter'].values()):>8} {len(rows):>6}"
    )
    return "\n".join(lines)


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CSV
    rows = load(path)
    errors, warnings = check(rows)
    print(f"{path}: {len(rows)} rows\n")
    print(summary(rows))

    if TEST_CSV.exists():
        test_rows, test_errors = load_test(TEST_CSV)
        errors += test_errors
        print(f"\n{TEST_CSV.name}: {len(test_rows)} team-written test phrases")
        counts = Counter(r["intent"] for r in test_rows)
        print("  " + ", ".join(f"{i} {counts[i]}" for i in INTENTS if counts[i]))
        for r in leakage(rows, test_rows):
            errors.append(f'leakage: training row "{r["text"]}" ({r["intent"]}) matches a test phrase')
        for c in conflicts(rows + test_rows):
            if f"phrase in two intents: {c}" not in errors:
                errors.append(f"phrase in two intents (training + test): {c}")
        for i, n in team_test_gaps(test_rows).items():
            warnings.append(f"{TEST_CSV.name}: {i} has {n} team phrases (needs {MIN_TEAM_TEST}+ before retraining)")
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
