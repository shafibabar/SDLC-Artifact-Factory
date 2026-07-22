---
description: Start execution on a sub-issue — creates its branch + draft PR, moves it to In Progress
argument-hint: <sub-issue-number>
allowed-tools: Bash(python3 scripts/github-project/exec_start.py:*)
---

Run:

```
python3 scripts/github-project/exec_start.py $ARGUMENTS
```

Report the branch name and PR URL back to Shafi. This command itself is the
approval checkpoint — do not ask for additional confirmation before running
it, since typing this slash command with the sub-issue number already is the
explicit approval.
