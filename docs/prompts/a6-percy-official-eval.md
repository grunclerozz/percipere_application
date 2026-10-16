# A6 – Official Percy evaluation (Sonnet 5.5, new chat) – only when the team test phrases are done

Read CLAUDE.md, docs/agent-rules.md, docs/handoff/03-voice-and-percy.md and
percy-smarter-handoff.md. data/percy/test_team.csv is now complete (team-written phrases for
all intents, including describe_image, more_detail, read_image_text, tutorial, set_speed).
Create branch chore/percy-eval from main.
1. Check that no test_team.csv row (after normalization) appears in training; remove and report.
2. Rerun scripts/percy/train.py WITHOUT --provisional; export assets/percy/model.json.
3. Write docs/thesis/percy-evaluation.md: team-only test accuracy and macro F1 (primary),
   per-intent precision/recall/F1, confusion matrix image, 5-fold CV, Naive Bayes vs
   Logistic Regression, data source shares (team/generated/starter), how leakage was
   prevented, and limitations.
4. Analyze + Percy tests; if they pass, merge into main. Update docs/handoff + worklog,
   commit (don't push).
