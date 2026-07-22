---
description: Commit + push staged work for a sub-issue and move it to In Review
argument-hint: <sub-issue-number> <commit message>
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(python3 scripts/github-project/exec_complete.py:*)
---

Arguments text: `$ARGUMENTS`

1. Parse the arguments: the first whitespace-separated token is the
   sub-issue number, everything after it is the commit message.
2. Run `git status` / `git diff --staged` to check whether anything is
   staged. If nothing is staged, tell Shafi and ask what to stage — do not
   run `git add` yourself without him naming what to include.
3. Once something is staged, run:
   ```
   python3 scripts/github-project/exec_complete.py <number> "<commit message>"
   ```
   quoting the commit message exactly as given.
4. This command itself is the approval checkpoint — no further confirmation
   needed before running step 3, since typing this slash command with a
   message already is the explicit approval. Report the result: commit
   pushed, sub-issue Status now In Review. Remind Shafi that review, merge,
   and closing the PR/issue are manual from here — this tooling stops.
