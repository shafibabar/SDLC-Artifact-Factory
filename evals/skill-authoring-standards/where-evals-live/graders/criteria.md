---
type: llm
weight: 1
---

The response says the eval cases live at the repository root under `evals/<skill-name>/` (one directory per case, e.g. `evals/<skill>/<case>/prompt.md` with graders), NOT inside `skills/<skill-name>/`. It gives at least one of these reasons: the `claude plugin eval` runner refuses an eval directory inside `skills/` because that is a loaded component directory; or golden answers stored beside the skill would load with it and leak into the run they are meant to grade.
