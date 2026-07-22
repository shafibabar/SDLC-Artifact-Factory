---
description: Show the current sub-issue draft for approval, then create it on GitHub
allowed-tools: Bash(python3 scripts/github-project/plan_exit.py:*)
---

This is a two-step, approval-gated action — never skip the pause.

1. Run `python3 scripts/github-project/plan_exit.py` (no `--confirm`). This
   only prints the current draft table; it makes no GitHub changes.
2. Show Shafi that table exactly as printed (title, description, depends_on,
   sequence for each row) and ask him to explicitly confirm before anything
   is created on GitHub. If the draft is empty, tell him there's nothing to
   exit with and stop — do not proceed to step 3.
3. Only after he explicitly approves, run
   `python3 scripts/github-project/plan_exit.py --confirm` and report what
   was created: each sub-issue's number/title, the dependency links wired,
   and the parent issue's new Status (In Progress).

If he asks to modify or reject rows instead of approving as-is, use
`python3 scripts/github-project/save_draft.py update|reject ...` and then
re-run step 1 to show the revised table — do not jump straight to
`--confirm` after an edit without showing the updated table again.
