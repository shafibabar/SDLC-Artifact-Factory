# GitHub Project Sync Tooling

Tracks this repo's own plan/execute workflow against the **SKILL GEN Project**
(github.com/users/shafibabar/projects/1). This is dev tooling for working on
*this* repo — it is not part of the SDLC Artifact Factory plugin shipped to
downstream products, which is why it lives under `.claude/` (session-only
commands/settings) rather than the plugin's own `commands/`/`hooks/` dirs.
See `INVESTIGATION.md` at the repo root for how the field/mechanism choices
below were determined.

## Prerequisites

- `gh` CLI installed and authenticated: `gh auth status`
- Required scopes: `repo`, `project`. If missing:
  ```
  gh auth refresh -s repo,project
  ```
- Python 3 (stdlib only, no extra packages).

## Workflow

```
plan-start "<title>"          issue created, added to Project, Status: Todo -> In Planning
save-draft add/update/reject  iterate on the sub-issue table during planning (local only)
plan-exit [--confirm]         print draft for review, then (on --confirm) create
                               sub-issues + wire dependencies + parent -> In Progress
exec-start <n>                branch + draft PR for sub-issue #n, Status -> In Progress
exec-complete <n> "<msg>"     commit + push, Status -> In Review (stops there — manual after)
```

Every command that mutates GitHub only runs when explicitly invoked (or, for
`plan-exit`, only when `--confirm` is passed) — invoking the command *is* the
approval checkpoint. Nothing past "In Review" (review, merge, close) is
automated by this tooling.

## Commands

Run from the repo root: `python3 scripts/github-project/<script>.py ...`
(the paired slash commands in `.claude/commands/` wrap these.)

### `plan_start.py "<title>" [--body "<body>"]`
Creates the parent issue, adds it to the Project, sets Status Todo -> In
Planning, and tracks it as the active plan in local state. Fails if a plan is
already active.

### `plan_status.py <planning|in-progress|in-review|done>`
Updates the Status of the currently tracked parent issue. `done` maps to the
board's existing "Done" option — a manual convenience for closing out the
parent once all sub-issues have actually merged; nothing infers this
automatically. Marking `done` also clears `current_plan` from local state —
this is what frees `plan_start.py` to begin the next plan; every other status
value leaves `current_plan` in place.

### `save_draft.py add|update|reject|list|clear`
Local-only, no GitHub calls. Keyed by a stable draft id (`d1`, `d2`, ...):

```
save_draft.py add --title T --description D [--depends-on d1,d2] [--sequence 3.a]
save_draft.py update <id> [--title T] [--description D] [--depends-on d1,d2] [--sequence 3.a]
save_draft.py reject <id>
save_draft.py list
save_draft.py clear
```

`update` only touches the fields you pass; other rows are never rewritten.
`reject` deletes the row entirely and strips it from every other row's
`depends_on` list. `depends_on` values reference other draft ids and are
resolved to real issue dependencies at `plan-exit` time.

Sequence values use dotted-letter notation (`1`, `2`, `3.a`, `3.b`, `4`) —
rows sharing a leading number are parallel/unordered relative to each other.
A non-matching value is a warning, not a hard error (it's a free-text field).

### `plan_exit.py [--confirm]`
Without `--confirm`: prints the draft table, mutates nothing. With
`--confirm`: creates each row as a **native GitHub sub-issue** of the parent
(`parentIssueId` on `createIssue` — the modern sub-issue relationship, not a
body-text convention), adds each to the Project (Status: Todo), sets its
`Sequence` field, wires cross-sub-issue dependencies via the native issue
**Relationships** mechanism (`addBlockedBy` — this is an issue-level linked-
issues feature, not a Project item field), then moves the parent to
Status: In Progress and clears the draft.

Safe to re-run: rows already created (tracked in local state) are skipped on
retry, so a failure partway through a batch won't duplicate issues.

### `exec_start.py <sub-issue-number>`
Creates branch `issue-<n>-<slug-of-title>`, an empty starting commit (so a
draft PR can open immediately with `Closes #<n>` in its body), pushes, opens
a **draft PR**, and moves the sub-issue to Status: In Progress.

### `exec_complete.py <sub-issue-number> "<commit message>"`
Commits **currently staged changes** (does not `git add` anything for you —
stage what you want committed first), pushes, moves the sub-issue to
Status: In Review. Stops there. The commit message's subject line is
whatever is passed in, but the tool always appends a deterministic
`git diff --staged --stat` block as the body — every commit objectively
records which files changed regardless of how descriptive the subject line
is. Fails fast with a clear error if nothing is staged.

## Local state

`scripts/github-project/.state.json` (gitignored — per-machine, not a durable
artifact) holds the active plan, the in-progress draft, and per-sub-issue
tracking (project item ids, branches, PR urls) so repeat invocations don't
need to re-query GitHub for ids they've already resolved. If it's missing or
stale, commands that need an id not in local state (`exec-start`,
`exec-complete`) fall back to a live GraphQL lookup by issue number.

## Field/status mapping

The board's Status field already had near-miss options before this tooling
existed (`Todo` not `To Do`, `In progress` not `In Progress`). Per decision
on 2026-07-22, the tooling reuses the existing options rather than creating
duplicates — see `scripts/github-project/ghp/config.py` for the exact
option-id mapping and `INVESTIGATION.md` for the full field inventory.
