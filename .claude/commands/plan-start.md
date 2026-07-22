---
description: Start a new plan/execute cycle — creates the parent issue on the SKILL GEN Project
argument-hint: <short title>
allowed-tools: Bash(python3 scripts/github-project/plan_start.py:*)
---

Run:

```
python3 scripts/github-project/plan_start.py "$ARGUMENTS"
```

Report the created issue number, URL, and Status back to Shafi in plain
language. If it errors because a plan is already active, tell him which
issue is active and that he needs to finish it (drive it to Status: In
Review or later) before starting a new one — do not attempt to clear or
override local state yourself.
