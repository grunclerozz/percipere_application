"""Trains Percy's intent classifier and exports it for the app.

Usage (from the project folder, Windows):
    scripts\\percy\\.venv\\Scripts\\python scripts\\percy\\train.py

Steps: validate the dataset, preprocess, split 70/15/15 (stratified, seed 42),
TF-IDF features (word 1–2-grams + per-word char 3–5-grams), compare Multinomial
Naive Bayes and Logistic Regression (tuned by 5-fold cross-validation on
train + validation), evaluate on test,
write the report and confusion matrix, export model.json / model_alt.json and
the test vectors used by the Dart unit test.

The exported models are trained on train + validation (the test set stays
unseen, so the report's test metrics describe exactly the shipped model).
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
from validate_dataset import DEFAULT_CSV, INTENTS, STARTER, check, load

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


# ── Main ────────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    args = ap.parse_args()

    rows = load(args.csv)
    errors, warnings = check(rows)
    if errors:
        print("Dataset errors (fix them first; see validate_dataset.py):")
        for e in errors:
            print("  ", e)
        return 1

    # One row per distinct cleaned sentence.
    seen, data = set(), []
    for r in rows:
        clean = preprocess(r["text"])
        if clean in seen:
            continue
        seen.add(clean)
        data.append({**r, "clean": clean})
    dropped = len(rows) - len(data)
    labels = [d["intent"] for d in data]
    idx = np.arange(len(data))

    train_i, rest_i = train_test_split(
        idx, test_size=0.30, stratify=labels, random_state=SEED
    )
    val_i, test_i = train_test_split(
        rest_i, test_size=0.50, stratify=[labels[i] for i in rest_i],
        random_state=SEED,
    )
    pick = lambda ids: ([data[i]["clean"] for i in ids], [labels[i] for i in ids])  # noqa: E731
    train, val, test = pick(train_i), pick(val_i), pick(test_i)
    print(f"{len(data)} sentences ({dropped} repeats dropped): "
          f"train {len(train_i)}, validation {len(val_i)}, test {len(test_i)}")

    # Tune both by cross-validation on train + validation.
    trval = (train[0] + val[0], train[1] + val[1])
    tuned = {k: tune(k, trval) for k in ("multinomial_nb", "logreg")}
    best = {k: v[0] for k, v in tuned.items()}
    for k, (f1, acc, sd, p, o) in best.items():
        print(f"  {describe(k, p, o)}: {CV_FOLDS}-fold CV macro F1 {f1:.3f} ± {sd:.3f}, "
              f"accuracy {acc:.3f}")
    # Higher CV macro F1 wins; a tie goes to Logistic Regression
    # (its probabilities are better calibrated for the confidence thresholds).
    chosen = max(best, key=lambda k: (best[k][0], best[k][1], k == "logreg"))
    other = "logreg" if chosen == "multinomial_nb" else "multinomial_nb"

    # Final models on train + validation; evaluated on test.
    final = {}
    for k in (chosen, other):
        _, _, _, p, o = best[k]
        feat, model = fit(k, p, o, *trval)
        pred = model.predict(feat.transform(test[0]))
        proba = model.predict_proba(feat.transform(test[0]))
        final[k] = dict(feat=feat, model=model, pred=pred, proba=proba, p=p, o=o)

    # Cross-validation scores of the chosen settings (from the tuning):
    # (macro F1 mean, macro F1 SD, accuracy mean).
    cv_scores = {k: (best[k][0], best[k][2], best[k][1]) for k in (chosen, other)}

    today = dt.date.today().isoformat()
    version = f"{today}-{len(data)}"
    REPORTS.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)

    # Export.
    exported = {}
    for k, name in ((chosen, "model.json"), (other, "model_alt.json")):
        f = final[k]
        m = export(k, f["p"], f["o"], f["feat"], f["model"], version)
        (ASSETS / name).write_text(json.dumps(m, ensure_ascii=False), encoding="utf-8")
        exported[k] = m
        size = (ASSETS / name).stat().st_size / 1024
        print(f"  wrote assets/percy/{name} ({describe(k, f['p'], f['o'])}, {size:.0f} KB)")

    # The JSON reimplementation must match scikit-learn.
    m = exported[chosen]
    ch = final[chosen]
    worst = 0.0
    for t, sk in zip(test[0], ch["proba"]):
        worst = max(worst, float(np.max(np.abs(np.array(json_predict(m, t)) - sk))))
    print(f"  model.json vs scikit-learn on test: max probability difference {worst:.6f}")

    # Test vectors for the Dart unit test.
    test_texts = [data[i]["text"] for i in test_i]
    step = max(1, len(test_texts) // (30 - len(EXTRA_VECTOR_SENTENCES)))
    sample = test_texts[::step][: 30 - len(EXTRA_VECTOR_SENTENCES)]
    vectors = []
    for t in sample + EXTRA_VECTOR_SENTENCES:
        probs = json_predict(m, t)
        top = int(np.argmax(probs))
        vectors.append({
            "text": t,
            "clean": preprocess(t),
            "intent": m["labels"][top],
            "probability": round(probs[top], 6),
            "probabilities": [round(p, 6) for p in probs],
        })
    VECTORS.write_text(
        json.dumps({"model_version": version, "labels": m["labels"], "vectors": vectors},
                   ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    print(f"  wrote {VECTORS.relative_to(ROOT)} ({len(vectors)} sentences)")

    # Metrics for the report.
    y_test = test[1]
    pred = ch["pred"]
    acc = accuracy_score(y_test, pred)
    macro = f1_score(y_test, pred, average="macro", zero_division=0)
    test_rows = [data[i] for i in test_i]
    team_mask = [r["source"] != STARTER for r in test_rows]
    team_n = sum(team_mask)
    team_acc = (
        accuracy_score([y for y, t in zip(y_test, team_mask) if t],
                       [p for p, t in zip(pred, team_mask) if t])
        if team_n else float("nan")
    )
    other_acc = accuracy_score(y_test, final[other]["pred"])
    other_macro = f1_score(y_test, final[other]["pred"], average="macro", zero_division=0)
    labels_sorted = list(ch["model"].classes_)
    cm = confusion_matrix(y_test, pred, labels=labels_sorted)
    cm_name = f"confusion-{today}.png"
    save_confusion(cm, labels_sorted, REPORTS / cm_name,
                   f"Percy intents — {describe(chosen, ch['p'], ch['o'])} (test set)")
    report_dict = classification_report(y_test, pred, labels=labels_sorted,
                                         output_dict=True, zero_division=0)
    conf = ch["proba"].max(axis=1)
    bands = []
    for name, lo, hi in (("≥ 0.60 (act)", 0.60, 1.01), ("0.30–0.60 (ask)", 0.30, 0.60),
                         ("< 0.30 (fallback)", 0.0, 0.30)):
        sel = [(p == y) for p, y, c in zip(pred, y_test, conf) if lo <= c < hi]
        bands.append([name, len(sel), f"{(sum(sel) / len(sel)):.2f}" if sel else "—"])

    team_counts = Counter(r["intent"] for r in data if r["source"] != STARTER)
    starter_counts = Counter(r["intent"] for r in data if r["source"] == STARTER)
    examples = []
    for intent in INTENTS:
        team_ex = [r["text"] for r in data if r["intent"] == intent and r["source"] != STARTER][:2]
        st_ex = [r["text"] for r in data if r["intent"] == intent and r["source"] == STARTER][:2]
        examples.append([intent, team_counts[intent], starter_counts[intent],
                         "; ".join(team_ex) or "—", "; ".join(st_ex) or "—"])

    tops = top_features(chosen, ch["feat"], ch["model"])
    wrong = [
        [r["text"], y, p, f"{c:.2f}", r["source"]]
        for r, y, p, c in zip(test_rows, y_test, pred, conf) if y != p
    ]
    per_intent = [
        [lab, f"{report_dict[lab]['precision']:.2f}", f"{report_dict[lab]['recall']:.2f}",
         f"{report_dict[lab]['f1-score']:.2f}", int(report_dict[lab]["support"])]
        for lab in labels_sorted
    ]
    nb_rows = [[a, p, f"{f1:.3f} ± {sd:.3f}", f"{ac:.3f}"]
               for f1, ac, sd, a, p in tuned["multinomial_nb"]]
    lr_rows = [[c, w, f"{f1:.3f} ± {sd:.3f}", f"{ac:.3f}"]
               for f1, ac, sd, c, w in tuned["logreg"]]

    why = (
        f"{describe(chosen, ch['p'], ch['o'])} had the higher {CV_FOLDS}-fold cross-validation macro F1 "
        f"({best[chosen][0]:.3f} vs {best[other][0]:.3f})"
        if best[chosen][0] != best[other][0]
        else "Both had the same cross-validation macro F1; Logistic Regression is preferred "
             "because its probabilities are better calibrated for Percy's confidence "
             "thresholds"
    )

    report = f"""# Percy intent classifier — training report ({today})

Dataset: `{args.csv.relative_to(ROOT) if args.csv.is_relative_to(ROOT) else args.csv}` — {len(rows)} rows,
{len(data)} distinct sentences after preprocessing ({dropped} repeat(s) dropped), {len(INTENTS)} intents.
Split (stratified, seed {SEED}): train {len(train_i)}, validation {len(val_i)}, test {len(test_i)}.
Settings are tuned by stratified {CV_FOLDS}-fold cross-validation on train + validation
({len(trval[0])} sentences); the test set is used only for this report.
Features: TF-IDF word {WORD_NGRAMS[0]}–{WORD_NGRAMS[1]}-grams + character {CHAR_NGRAMS[0]}–{CHAR_NGRAMS[1]}-grams
inside words ({len(ch['feat'].features)} features on train + validation).
Exported models are trained on train + validation; the test set was never seen.

## Chosen model
**{describe(chosen, ch['p'], ch['o'])}** → `assets/percy/model.json` (version `{version}`).
Why: {why}. The other model is exported as `assets/percy/model_alt.json`.

## Test-set results
| Metric | {describe(chosen, ch['p'], ch['o'])} | {describe(other, final[other]['p'], final[other]['o'])} |
|---|---|---|
| Accuracy | {acc:.3f} | {other_acc:.3f} |
| Macro F1 | {macro:.3f} | {other_macro:.3f} |
| {CV_FOLDS}-fold CV macro F1 (train + validation), mean ± SD | {cv_scores[chosen][0]:.3f} ± {cv_scores[chosen][1]:.3f} | {cv_scores[other][0]:.3f} ± {cv_scores[other][1]:.3f} |
| {CV_FOLDS}-fold CV accuracy (train + validation), mean | {cv_scores[chosen][2]:.3f} | {cv_scores[other][2]:.3f} |
| Accuracy on team-written test sentences only ({team_n}) | {team_acc:.3f} | — |

Confusion matrix: `{cm_name}` (same folder).

### Confidence bands (chosen model, test set)
How often the prediction was right at each of Percy's thresholds.

{md_table(["Band", "Sentences", "Accuracy"], bands)}

### Per intent (test set)
{md_table(["Intent", "Precision", "Recall", "F1", "Support"], per_intent)}

## Tuning ({CV_FOLDS}-fold cross-validation on train + validation)
Naive Bayes:

{md_table(["alpha", "fit_prior", "Macro F1 (mean ± SD)", "Accuracy"], nb_rows)}

Logistic Regression:

{md_table(["C", "class_weight", "Macro F1 (mean ± SD)", "Accuracy"], lr_rows)}

## Examples per intent (team vs Starter)
{md_table(["Intent", "Team", "Starter", "Team examples", "Starter examples"], examples)}

## Top 10 informative words per intent (chosen model)
{md_table(["Intent", "Words"], [[k, ", ".join(v)] for k, v in tops.items()])}

## Misclassified test sentences
{md_table(["Sentence", "True", "Predicted", "Confidence", "Source"], wrong) if wrong else "None."}

## Dataset warnings
{chr(10).join("- " + w for w in warnings) if warnings else "None."}
"""
    out = REPORTS / f"report-{today}.md"
    out.write_text(report, encoding="utf-8")
    print(f"  wrote {out.relative_to(ROOT)}")
    print(f"\nChosen: {describe(chosen, ch['p'], ch['o'])}")
    print(f"Test accuracy {acc:.3f}, macro F1 {macro:.3f}, "
          f"CV macro F1 {cv_scores[chosen][0]:.3f} ± {cv_scores[chosen][1]:.3f}, "
          f"team-only {team_acc:.3f} ({team_n} sentences)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
