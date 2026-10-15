"""Trains Percy's intent classifier and exports it for the app.

Usage (from the project folder, Windows):
    scripts/percy/.venv/Scripts/python scripts/percy/train.py [--dry-run]

Evaluation (decision 2026-10-16):
  * PRIMARY: the fixed, team-written test set data/percy/test_team.csv. It is
    never trained on, split or reshuffled; training rows that match it after
    preprocessing are dropped. Accuracy, macro F1, per-intent scores and the
    confusion matrix are reported for Naive Bayes and Logistic Regression
    (with and without class weighting).
  * SECONDARY: an all-data 70/15/15 split and 5-fold cross-validation.
  * Hyperparameters and the chosen model come from 5-fold CV on the training
    data only (never from the test set).
  * Data share per intent (team / generated / starter); intents with less than
    2/3 team-written phrases are flagged.

The exported models are trained on all training data. Without --dry-run the
script refuses to train until test_team.csv has MIN_TEAM_TEST+ team phrases for
each new intent. --dry-run evaluates and writes a report to --report-dir only.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from scipy import sparse
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.naive_bayes import MultinomialNB

from percy_text import (
    CHAR_NGRAMS,
    WAKE_WORDS,
    WORD_NGRAMS,
    char_features,
    preprocess,
    word_features,
)
from validate_dataset import (
    DEFAULT_CSV,
    INTENTS,
    MIN_TEAM_TEST,
    TEST_CSV,
    check,
    load,
    load_test,
    source_kind,
    team_test_gaps,
)

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "percy"
REPORTS = ROOT / "data" / "percy" / "reports"
VECTORS = Path(__file__).resolve().parent / "test_vectors.json"

SEED = 42
CV_FOLDS = 5
NB_ALPHAS = [0.01, 0.03, 0.1, 0.3, 1.0]
LR_CS = [1.0, 3.0, 10.0, 30.0, 100.0]
DECIMALS = 6  # rounding of exported numbers (keeps model.json small)

# Extra sentences for the test vectors: misspellings, Taglish, polite forms.
EXTRA_VECTOR_SENTENCES = [
    "basahen mo nga po",
    "Percy, buksan mo ang library",
    "hey percy pakibilisan",
    "pwede bang palakihin ang letra",
    "wag na lang",
    "hindi",
    "ano ang panahon bukas",
    "salamat po percy",
    "go back please",
    "nasaan na ba ako",
]


# ── Features ────────────────────────────────────────────────────────────────


class Featurizer:
    """TF-IDF over two blocks (words, characters), each L2-normalized.

    Same formulas as scikit-learn's TfidfVectorizer defaults: raw counts,
    smooth idf = ln((1 + n) / (1 + df)) + 1, L2 norm (here per block).
    """

    def __init__(self) -> None:
        self.vocab: dict[str, int] = {}
        self.features: list[str] = []
        self.blocks: list[int] = []
        self.idf: np.ndarray = np.zeros(0)

    @staticmethod
    def _grams(clean: str) -> list[tuple[int, str]]:
        return [(0, g) for g in word_features(clean)] + [
            (1, g) for g in char_features(clean)
        ]

    @staticmethod
    def key(block: int, gram: str) -> str:
        return ("w:" if block == 0 else "c:") + gram

    def fit(self, texts: list[str]) -> "Featurizer":
        df: Counter = Counter()
        for t in texts:
            df.update({self.key(b, g) for b, g in self._grams(t)})
        self.features = sorted(df)
        self.vocab = {f: i for i, f in enumerate(self.features)}
        self.blocks = [0 if f.startswith("w:") else 1 for f in self.features]
        n = len(texts)
        self.idf = np.array(
            [math.log((1 + n) / (1 + df[f])) + 1 for f in self.features]
        )
        return self

    def transform(self, texts: list[str]) -> sparse.csr_matrix:
        rows, cols, vals = [], [], []
        for r, t in enumerate(texts):
            counts: Counter = Counter()
            for b, g in self._grams(t):
                i = self.vocab.get(self.key(b, g))
                if i is not None:
                    counts[i] += 1
            for block in (0, 1):
                items = [
                    (i, c * self.idf[i])
                    for i, c in counts.items()
                    if self.blocks[i] == block
                ]
                norm = math.sqrt(sum(v * v for _, v in items))
                if norm == 0:
                    continue
                for i, v in items:
                    rows.append(r)
                    cols.append(i)
                    vals.append(v / norm)
        return sparse.csr_matrix(
            (vals, (rows, cols)), shape=(len(texts), len(self.features))
        )


# ── Models ──────────────────────────────────────────────────────────────────


def make_model(kind: str, param: float, option: object):
    if kind == "logreg":
        return LogisticRegression(
            C=param, class_weight=option, max_iter=5000, random_state=SEED
        )
    return MultinomialNB(alpha=param, fit_prior=bool(option))


def fit(kind, param, option, texts, labels):
    feat = Featurizer().fit(texts)
    model = make_model(kind, param, option).fit(feat.transform(texts), labels)
    return feat, model


def describe(kind, param, option) -> str:
    if kind == "logreg":
        return f"Logistic Regression (C={param}, class_weight={option})"
    return f"Multinomial Naive Bayes (alpha={param}, fit_prior={option})"


def tune(kind, data):
    """Hyperparameters for [kind], best first, by stratified 5-fold
    cross-validation on [data] (train + validation).

    Each row is (mean macro F1, mean accuracy, SD of macro F1, param,
    option). Cross-validation replaced the single validation set
    (2026-10-11): with 77 validation sentences the winner changed by noise.
    The features are refit inside every fold, so no fold sees its own words.
    """
    grid = (
        [(c, w) for c in LR_CS for w in (None, "balanced")]
        if kind == "logreg"
        else [(a, p) for a in NB_ALPHAS for p in (True, False)]
    )
    X, y = np.array(data[0], dtype=object), np.array(data[1])
    folds = list(
        StratifiedKFold(n_splits=CV_FOLDS, shuffle=True, random_state=SEED).split(X, y)
    )
    results = []
    for param, option in grid:
        f1s, accs = [], []
        for a, b in folds:
            feat, model = fit(kind, param, option, list(X[a]), list(y[a]))
            pred = model.predict(feat.transform(list(X[b])))
            f1s.append(f1_score(y[b], pred, average="macro", zero_division=0))
            accs.append(accuracy_score(y[b], pred))
        results.append(
            (float(np.mean(f1s)), float(np.mean(accs)), float(np.std(f1s)), param, option)
        )
    results.sort(key=lambda r: (r[0], r[1]), reverse=True)
    return results


# ── Export ──────────────────────────────────────────────────────────────────


def export(kind, param, option, feat: Featurizer, model, version: str) -> dict:
    r = lambda a: np.round(np.asarray(a, dtype=float), DECIMALS).tolist()  # noqa: E731
    data = {
        "format": "percy-intent-model",
        "format_version": 1,
        "type": kind,
        "version": version,
        "date": dt.date.today().isoformat(),
        "hyperparameters": {
            "C": param, "class_weight": option
        } if kind == "logreg" else {"alpha": param, "fit_prior": option},
        "preprocessing": {
            "lowercase": True,
            "fold_accents": True,
            "delete": ["-", "'", "’"],
            "keep": "a-z0-9 space",
            "wake_words": sorted(WAKE_WORDS),
        },
        "features": {
            "word_ngrams": list(WORD_NGRAMS),
            "char_ngrams": list(CHAR_NGRAMS),
            "char_mode": "per word, padded with one space each side",
            "tf": "raw count",
            "idf": "smooth: ln((1+n)/(1+df))+1",
            "norm": "l2 per block (w:, c:)",
        },
        "labels": [str(c) for c in model.classes_],
        "vocabulary": feat.features,
        "idf": r(feat.idf),
    }
    if kind == "logreg":
        data["weights"] = r(model.coef_)
        data["bias"] = r(model.intercept_)
    else:
        data["log_prob"] = r(model.feature_log_prob_)
        data["log_prior"] = r(model.class_log_prior_)
    return data


def json_predict(m: dict, text: str) -> list[float]:
    """Probabilities exactly as the app computes them from model.json."""
    clean = preprocess(text)
    vocab = {f: i for i, f in enumerate(m["vocabulary"])}
    idf = m["idf"]
    counts: Counter = Counter()
    for b, g in Featurizer._grams(clean):
        i = vocab.get(Featurizer.key(b, g))
        if i is not None:
            counts[i] += 1
    x: dict[int, float] = {}
    for prefix in ("w:", "c:"):
        items = [
            (i, c * idf[i])
            for i, c in counts.items()
            if m["vocabulary"][i].startswith(prefix)
        ]
        norm = math.sqrt(sum(v * v for _, v in items))
        for i, v in items:
            if norm:
                x[i] = v / norm
    if m["type"] == "logreg":
        scores = [
            m["bias"][k] + sum(m["weights"][k][i] * v for i, v in x.items())
            for k in range(len(m["labels"]))
        ]
    else:
        scores = [
            m["log_prior"][k] + sum(m["log_prob"][k][i] * v for i, v in x.items())
            for k in range(len(m["labels"]))
        ]
    top = max(scores)
    exps = [math.exp(s - top) for s in scores]
    total = sum(exps)
    return [e / total for e in exps]


# ── Report helpers ──────────────────────────────────────────────────────────


def top_features(kind, feat: Featurizer, model, k=10) -> dict[str, list[str]]:
    """Most informative word features per intent."""
    words = [i for i, b in enumerate(feat.blocks) if b == 0]
    if kind == "logreg":
        scores = model.coef_
    else:
        lp = model.feature_log_prob_
        scores = lp - lp.mean(axis=0, keepdims=True)
    out = {}
    for c, label in enumerate(model.classes_):
        best = sorted(words, key=lambda i: scores[c][i], reverse=True)[:k]
        out[str(label)] = [feat.features[i][2:] for i in best]
    return out


def save_confusion(cm, labels, path: Path, title: str) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(13, 11))
    ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(len(labels)), labels, rotation=90, fontsize=8)
    ax.set_yticks(range(len(labels)), labels, fontsize=8)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("True")
    ax.set_title(title)
    for i in range(len(labels)):
        for j in range(len(labels)):
            if cm[i, j]:
                ax.text(
                    j, i, int(cm[i, j]), ha="center", va="center", fontsize=7,
                    color="white" if cm[i, j] > cm.max() / 2 else "black",
                )
    fig.tight_layout()
    fig.savefig(path, dpi=120)
    plt.close(fig)


def md_table(header: list[str], rows: list[list[object]]) -> str:
    lines = ["| " + " | ".join(header) + " |", "|" + "---|" * len(header)]
    for r in rows:
        lines.append("| " + " | ".join(str(c).replace("|", "\\|") for c in r) + " |")
    return "\n".join(lines)


# ── Evaluation helpers ──────────────────────────────────────────────────────


def metrics(y_true, y_pred) -> dict:
    """Accuracy and macro F1 (over the intents that occur in [y_true]) plus
    per-intent precision / recall / F1 / support."""
    present = sorted(set(y_true))
    labels = sorted(set(y_true) | set(y_pred))
    rep = classification_report(
        y_true, y_pred, labels=labels, output_dict=True, zero_division=0
    )
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "macro_f1": f1_score(y_true, y_pred, labels=present, average="macro", zero_division=0),
        "present": present,
        "labels": labels,
        "report": rep,
        "cm": confusion_matrix(y_true, y_pred, labels=labels),
    }


def best_with(tuned_rows, option):
    """Best tuning row whose option (class_weight / fit_prior) equals [option]."""
    return next(r for r in tuned_rows if r[4] == option)


def md_confusion(cm, labels) -> str:
    """Confusion matrix as a Markdown table (numbered columns + a legend)."""
    head = ["true \\ predicted"] + [str(i + 1) for i in range(len(labels))]
    rows = []
    for i, lab in enumerate(labels):
        rows.append([f"{i + 1}. {lab}"] + [int(v) if v else "" for v in cm[i]])
    return md_table(head, rows)


def confused_pairs(cm, labels, k=10):
    pairs = [
        (int(cm[i, j]), labels[i], labels[j])
        for i in range(len(labels))
        for j in range(len(labels))
        if i != j and cm[i, j]
    ]
    return sorted(pairs, reverse=True)[:k]


def baseline_predictions(path: Path, texts: list[str]):
    """Predictions of an already-exported model.json (the 'before' model).

    Returns (labels, predicted intents) or None when the file is missing.
    """
    if not path.exists():
        return None
    m = json.loads(path.read_text(encoding="utf-8"))
    out = []
    for t in texts:
        probs = json_predict(m, t)
        out.append(m["labels"][int(np.argmax(probs))])
    return m["labels"], out


# ── Main ────────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--csv", type=Path, default=DEFAULT_CSV, help="training data")
    ap.add_argument("--test", type=Path, default=TEST_CSV, help="fixed team-only test set")
    ap.add_argument(
        "--baseline", type=Path, default=ASSETS / "model.json",
        help="model scored as 'before' (read before anything is overwritten)",
    )
    ap.add_argument(
        "--dry-run", action="store_true",
        help="evaluate and write a report to --report-dir only; do not touch "
             "assets/percy or test_vectors.json, and skip the test-set completeness gate",
    )
    ap.add_argument("--report-dir", type=Path, default=None)
    args = ap.parse_args()
    report_dir = args.report_dir or REPORTS

    # ── Data ──
    rows = load(args.csv)
    errors, warnings = check(rows)
    test_rows, test_errors = load_test(args.test)
    errors += test_errors
    if errors:
        print("Dataset errors (fix them first; see validate_dataset.py):")
        for e in errors:
            print("  ", e)
        return 1
    gaps = team_test_gaps(test_rows)
    if gaps and not args.dry_run:
        print(f"STOP: {args.test.name} needs {MIN_TEAM_TEST}+ team-written phrases for:")
        for i, n in gaps.items():
            print(f"  {i}: {n}")
        print("Nothing was trained or exported.")
        return 2

    # The test set is fixed: it is never split, shuffled or trained on. Any
    # training row that matches a test phrase (after preprocessing) is dropped.
    test_clean = {preprocess(r["text"]) for r in test_rows}
    seen, data, leaked = set(), [], 0
    for r in rows:
        clean = preprocess(r["text"])
        if clean in seen:
            continue
        seen.add(clean)
        if clean in test_clean:
            leaked += 1
            continue
        data.append({**r, "clean": clean})
    dropped = len(rows) - len(data) - leaked
    labels = [d["intent"] for d in data]
    idx = np.arange(len(data))
    test_x = [preprocess(r["text"]) for r in test_rows]
    test_y = [r["intent"] for r in test_rows]
    all_x, all_y = [d["clean"] for d in data], labels
    print(f"{len(data)} training sentences ({dropped} repeats dropped, {leaked} matching the "
          f"test set dropped); {len(test_rows)} fixed team test sentences")

    # ── Secondary: all-data 70/15/15 split (stratified, seed 42) ──
    train_i, rest_i = train_test_split(idx, test_size=0.30, stratify=labels, random_state=SEED)
    val_i, test_i = train_test_split(
        rest_i, test_size=0.50, stratify=[labels[i] for i in rest_i], random_state=SEED
    )
    pick = lambda ids: ([data[i]["clean"] for i in ids], [labels[i] for i in ids])  # noqa: E731
    train, val, split_test = pick(train_i), pick(val_i), pick(test_i)
    trval = (train[0] + val[0], train[1] + val[1])
    tuned_split = {k: tune(k, trval) for k in ("multinomial_nb", "logreg")}
    split_models = {}
    for k in tuned_split:
        _, _, _, p, o = tuned_split[k][0]
        feat, model = fit(k, p, o, *trval)
        split_models[k] = metrics(split_test[1], list(model.predict(feat.transform(split_test[0]))))

    # ── Tuning on all training data (5-fold CV) ──
    tuned = {k: tune(k, (all_x, all_y)) for k in ("multinomial_nb", "logreg")}
    best = {k: v[0] for k, v in tuned.items()}
    for k, (f1, acc, sd, p, o) in best.items():
        print(f"  {describe(k, p, o)}: {CV_FOLDS}-fold CV macro F1 {f1:.3f} ± {sd:.3f}, accuracy {acc:.3f}")
    # Higher CV macro F1 wins (never the test set); a tie goes to Logistic Regression.
    chosen = max(best, key=lambda k: (best[k][0], best[k][1], k == "logreg"))
    other = "logreg" if chosen == "multinomial_nb" else "multinomial_nb"

    # ── Primary: fixed team-only test set ──
    candidates = {
        "Naive Bayes": ("multinomial_nb", best["multinomial_nb"]),
        "Logistic Regression, class_weight=balanced": ("logreg", best_with(tuned["logreg"], "balanced")),
        "Logistic Regression, no class weighting": ("logreg", best_with(tuned["logreg"], None)),
    }
    primary = {}
    fitted = {}
    for name, (k, (f1, acc, sd, p, o)) in candidates.items():
        feat, model = fit(k, p, o, all_x, all_y)
        pred = list(model.predict(feat.transform(test_x)))
        proba = model.predict_proba(feat.transform(test_x))
        primary[name] = dict(kind=k, cv=(f1, sd, acc), p=p, o=o, pred=pred, proba=proba,
                             m=metrics(test_y, pred))
        fitted[name] = (feat, model)
    chosen_name = next(n for n, (k, r) in candidates.items()
                       if k == chosen and r is best[chosen])
    ch = primary[chosen_name]
    ch_feat, ch_model = fitted[chosen_name]
    oth_name = "Naive Bayes" if chosen == "logreg" else \
        "Logistic Regression, class_weight=balanced"
    # The alternative model that is exported is the best of the other kind.
    oth_best = best[other]
    oth_feat, oth_model = fit(other, oth_best[3], oth_best[4], all_x, all_y)

    # Baseline ("before"): the currently shipped model on the same sentences.
    base = baseline_predictions(args.baseline, test_x)
    base_m = metrics(test_y, base[1]) if base else None

    today = dt.date.today().isoformat()
    version = f"{today}-{len(data)}"
    m = ch["m"]
    labels_c, cm = m["labels"], m["cm"]

    print("\nPRIMARY (fixed team-only test set, "
          f"{len(test_rows)} sentences, {len(m['present'])} intents):")
    for name, r in primary.items():
        mark = "  <- chosen" if name == chosen_name else ""
        print(f"  {name}: accuracy {r['m']['accuracy']:.3f}, macro F1 {r['m']['macro_f1']:.3f}, "
              f"CV macro F1 {r['cv'][0]:.3f}{mark}")
    if base_m:
        print(f"  before (shipped model.json): accuracy {base_m['accuracy']:.3f}, "
              f"macro F1 {base_m['macro_f1']:.3f}")
    print("SECONDARY (all-data 70/15/15 split, test 15%):")
    for k, r in split_models.items():
        print(f"  {k}: accuracy {r['accuracy']:.3f}, macro F1 {r['macro_f1']:.3f}")

    # ── Data shares per intent ──
    def count(kind, intent, pool):
        return sum(1 for r in pool if r["intent"] == intent and source_kind(r) == kind)

    shares = []
    flagged = []
    for intent in INTENTS:
        t_tr, g, st = (count(k, intent, data) for k in ("team", "generated", "starter"))
        t_te = sum(1 for r in test_rows if r["intent"] == intent)
        total = t_tr + t_te + g + st
        team = t_tr + t_te
        share = team / total if total else 0.0
        low = share < 2 / 3
        if low:
            flagged.append(intent)
        shares.append([intent, team, t_te, g, st, total, f"{share:.0%}", "LOW" if low else ""])

    # ── Export ──
    exported_note = "dry run: nothing exported"
    if not args.dry_run:
        ASSETS.mkdir(parents=True, exist_ok=True)
        exported = {}
        for k, feat, model, (p, o), name in (
            (chosen, ch_feat, ch_model, (ch["p"], ch["o"]), "model.json"),
            (other, oth_feat, oth_model, (oth_best[3], oth_best[4]), "model_alt.json"),
        ):
            mj = export(k, p, o, feat, model, version)
            (ASSETS / name).write_text(json.dumps(mj, ensure_ascii=False), encoding="utf-8")
            exported[k] = mj
            print(f"  wrote assets/percy/{name} ({describe(k, p, o)}, "
                  f"{(ASSETS / name).stat().st_size / 1024:.0f} KB)")
        mj = exported[chosen]
        worst = 0.0
        for t, sk in zip(test_x, ch["proba"]):
            worst = max(worst, float(np.max(np.abs(np.array(json_predict(mj, t)) - sk))))
        print(f"  model.json vs scikit-learn on the team test set: max probability difference {worst:.6f}")
        sample_n = 30 - len(EXTRA_VECTOR_SENTENCES)
        texts = [r["text"] for r in test_rows]
        step = max(1, len(texts) // sample_n)
        vectors = []
        for t in texts[::step][:sample_n] + EXTRA_VECTOR_SENTENCES:
            probs = json_predict(mj, t)
            top = int(np.argmax(probs))
            vectors.append({
                "text": t, "clean": preprocess(t), "intent": mj["labels"][top],
                "probability": round(probs[top], 6),
                "probabilities": [round(p_, 6) for p_ in probs],
            })
        VECTORS.write_text(
            json.dumps({"model_version": version, "labels": mj["labels"], "vectors": vectors},
                       ensure_ascii=False, indent=1),
            encoding="utf-8",
        )
        print(f"  wrote {VECTORS.relative_to(ROOT)} ({len(vectors)} sentences)")
        exported_note = f"`assets/percy/model.json` (version `{version}`)"

    # ── Report ──
    report_dir.mkdir(parents=True, exist_ok=True)
    cm_name = f"confusion-{today}.png"
    save_confusion(cm, labels_c, report_dir / cm_name,
                   f"Percy intents — {chosen_name} (fixed team test set)")

    conf = ch["proba"].max(axis=1)
    bands = []
    for name, lo, hi in (("≥ 0.60 (act)", 0.60, 1.01), ("0.30–0.60 (ask)", 0.30, 0.60),
                         ("< 0.30 (fallback)", 0.0, 0.30)):
        sel = [(p_ == y) for p_, y, c in zip(ch["pred"], test_y, conf) if lo <= c < hi]
        bands.append([name, len(sel), f"{(sum(sel) / len(sel)):.2f}" if sel else "—"])

    def per_intent(mm):
        rep = mm["report"]
        return [[lab, f"{rep[lab]['precision']:.2f}", f"{rep[lab]['recall']:.2f}",
                 f"{rep[lab]['f1-score']:.2f}", int(rep[lab]["support"])]
                for lab in mm["labels"]]

    cmp_rows = [[name, f"{r['m']['accuracy']:.3f}", f"{r['m']['macro_f1']:.3f}",
                 f"{r['cv'][0]:.3f} ± {r['cv'][1]:.3f}", f"{r['cv'][2]:.3f}",
                 describe(r["kind"], r["p"], r["o"])]
                for name, r in primary.items()]
    if base_m:
        cmp_rows.insert(0, [f"BEFORE: {args.baseline.name} as shipped", f"{base_m['accuracy']:.3f}",
                            f"{base_m['macro_f1']:.3f}", "—", "—", "old data; saw these phrases in training"])
    split_rows = [[describe(k, tuned_split[k][0][3], tuned_split[k][0][4]),
                   f"{r['accuracy']:.3f}", f"{r['macro_f1']:.3f}",
                   f"{tuned_split[k][0][0]:.3f} ± {tuned_split[k][0][2]:.3f}"]
                  for k, r in split_models.items()]
    wrong = sorted(
        [(c, t, y, p_) for t, y, p_, c in zip(
            [r["text"] for r in test_rows], test_y, ch["pred"], conf) if y != p_],
        reverse=True,
    )
    confused_rows = [[t, y, p_, f"{c:.2f}"] for c, t, y, p_ in wrong[:10]]
    pair_rows = [[n, a, b] for n, a, b in confused_pairs(cm, labels_c)]
    nb_rows = [[a, p, f"{f1:.3f} ± {sd:.3f}", f"{ac:.3f}"] for f1, ac, sd, a, p in tuned["multinomial_nb"]]
    lr_rows = [[c, w, f"{f1:.3f} ± {sd:.3f}", f"{ac:.3f}"] for f1, ac, sd, c, w in tuned["logreg"]]
    untested = [i for i in INTENTS if i not in m["present"]]
    why = (
        f"{chosen_name} had the higher {CV_FOLDS}-fold cross-validation macro F1 on the training data "
        f"({best[chosen][0]:.3f} vs {best[other][0]:.3f}); the choice never looks at the test set"
        if best[chosen][0] != best[other][0]
        else "Both had the same cross-validation macro F1; Logistic Regression is preferred "
             "because its probabilities are better calibrated for Percy's confidence thresholds"
    )
    report = f"""# Percy intent classifier — evaluation report ({today}){' — DRY RUN' if args.dry_run else ''}

Training data: `{_rel(args.csv)}` — {len(rows)} rows, {len(data)} distinct sentences after
preprocessing ({dropped} repeats dropped, {leaked} dropped for matching the test set).
Fixed test set: `{_rel(args.test)}` — {len(test_rows)} team-written sentences, never trained on,
never split or reshuffled. Features: TF-IDF word {WORD_NGRAMS[0]}–{WORD_NGRAMS[1]}-grams +
character {CHAR_NGRAMS[0]}–{CHAR_NGRAMS[1]}-grams ({len(ch_feat.features)} features).
Settings are tuned by stratified {CV_FOLDS}-fold CV on the training data only.
Exported: {exported_note}.

## Primary: fixed team-only test set
Intents with test sentences: {len(m['present'])} of {len(INTENTS)}.
Not covered by the test set: {', '.join(untested) if untested else 'none'}.
Macro F1 is over the intents that have test sentences.

{md_table(["Model", "Accuracy", "Macro F1", f"{CV_FOLDS}-fold CV macro F1 (training data)", "CV accuracy", "Settings"], cmp_rows)}

**Chosen:** {chosen_name}. Why: {why}. The other kind is exported as `model_alt.json`.

### Per intent (chosen model, test set)
{md_table(["Intent", "Precision", "Recall", "F1", "Support"], per_intent(m))}

### Confusion matrix (chosen model, test set)
Rows are the true intent, columns the predicted one (numbers = row numbers).
Image: `{cm_name}`.

{md_confusion(cm, labels_c)}

### Most confused intent pairs
{md_table(["Count", "True", "Predicted"], pair_rows) if pair_rows else "None."}

### The 10 most-confused phrases (wrong predictions with the highest confidence)
{md_table(["Phrase", "True", "Predicted", "Confidence"], confused_rows) if confused_rows else "None — no mistakes."}

### Confidence bands (chosen model, test set)
Current thresholds kept: ≥ 0.60 act, 0.30–0.60 ask, < 0.30 fallback.

{md_table(["Band", "Sentences", "Accuracy"], bands)}

## Secondary: all-data 70/15/15 split (stratified, seed {SEED})
Train {len(train_i)}, validation {len(val_i)}, test {len(test_i)} sentences of the training data
(team-test phrases are not in it). Tuned by {CV_FOLDS}-fold CV on train + validation.

{md_table(["Model", "Test accuracy", "Test macro F1", f"{CV_FOLDS}-fold CV macro F1"], split_rows)}

## Data source share per intent
`Team` = training team rows + held-out test rows. Flag = team-written share below 2/3.

{md_table(["Intent", "Team", "of which test", "Generated (Codex)", "Starter", "Total", "Team share", "Flag"], shares)}

Flagged intents ({len(flagged)}): {', '.join(flagged) if flagged else 'none'}.

## Tuning ({CV_FOLDS}-fold cross-validation, all training data)
Naive Bayes:

{md_table(["alpha", "fit_prior", "Macro F1 (mean ± SD)", "Accuracy"], nb_rows)}

Logistic Regression:

{md_table(["C", "class_weight", "Macro F1 (mean ± SD)", "Accuracy"], lr_rows)}

## Dataset warnings
{chr(10).join("- " + w for w in warnings) if warnings else "None."}
"""
    out = report_dir / f"report-{today}.md"
    out.write_text(report, encoding="utf-8")
    print(f"  wrote {_rel(out)}")
    print(f"\nChosen: {chosen_name} ({describe(chosen, ch['p'], ch['o'])})")
    return 0


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


if __name__ == "__main__":
    sys.exit(main())
