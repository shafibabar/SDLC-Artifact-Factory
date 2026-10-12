# GitHub Project Sync Tooling — Investigation Findings

Investigation performed 2026-07-22 before building `scripts/github-project/`.
Read this before touching field IDs in `scripts/github-project/ghp/config.py`
— if the board's schema changes, re-run the queries below and update that
file to match.

## Auth

`gh auth status` showed scopes `gist, project, read:org, repo, workflow`
(the `project` scope was added mid-session via `gh auth refresh -s project`
at Shafi's request, before this build started). `repo` + `project` are
sufficient — there is no separate read-only project scope for OAuth/gh
tokens; `project` covers both read and write.

## Project

`gh project view 1 --owner shafibabar --format json`:
- Title: "SKILL GEN Project", id `PVT_kwHOA4gFKc4Bbj6Q`, 42 existing items,
  17 existing fields. This is an actively used board, not an empty scratch
  project — the Status-field near-misses below are a direct consequence of
  that.

## Status field — CONFLICT, paused and resolved with Shafi

`gh project field-list 1 --owner shafibabar --format json` showed the
Status field (`PVTSSF_lAHOA4gFKc4Bbj6QzhWTl28`) already has 8 options:
`Todo`, `In Planning`, `In progress`, `In Review`, `In Test`,
`Ready to Merge`, `Paused/Blocked`, `Done`.

Two of the four states this workflow needs are near-misses of the spec, not
exact matches:
- spec wanted `To Do` (with a space) — board has `Todo`
- spec wanted `In Progress` — board has `In progress` (lowercase p)
- `In Planning` and `In Review` matched exactly

Per the pause condition in the original brief ("Status field has unexpected
existing options that might conflict"), this was raised to Shafi rather than
guessed. **Decision (2026-07-22): reuse the existing options** — `Todo` and
`In progress` — rather than create new exact-spec duplicates that would sit
confusingly next to the old ones on a board with 42 live items. The four
extra options (`In Test`, `Ready to Merge`, `Paused/Blocked`, `Done`) are
untouched and irrelevant to this tooling, except `Done` which `plan-status`
optionally uses for closing out a parent manually (see the tooling README).

Final mapping (`ghp/config.py`):
```
todo         -> f75ad846  ("Todo")
in_planning  -> f21b3f44  ("In Planning")
in_progress  -> 47fc9ee4  ("In progress")
in_review    -> 1e0d67d2  ("In Review")
done         -> 98236657  ("Done")
```

## Native sub-issues — supported, no fallback needed

GraphQL schema introspection (`__type(name: "Issue")`) confirmed:
- `Issue.parent`, `Issue.subIssues`, `Issue.subIssuesSummary` fields exist
- Mutations `addSubIssue`, `removeSubIssue`, `reprioritizeSubIssue` exist
- `CreateIssueInput` additionally has a `parentIssueId` field, meaning a
  sub-issue can be created and linked to its parent in a single
  `createIssue` mutation — no separate `addSubIssue` call needed at all.

This matches the project's own field list already showing `Parent issue` and
`Sub-issues progress` as auto-surfaced Project fields (those only appear
once native sub-issues are in use anywhere on the board). **No `Part of
#<parent>` body-text fallback was needed anywhere** — every parent/child
link in this tooling uses the native mechanism.

Confirmed: `gh` CLI 2.46.0 has no `gh issue` subcommands wrapping
sub-issues or dependencies — those only exist via `gh api graphql`. The
tooling shells out to raw GraphQL for these two operations specifically
(see `ghp/gh.py:graphql()` and `ghp/project.py`).

## Relationships — issue-level, not a Project field

No field named "Relationships" exists among the Project's 17 fields.
Introspection found it's actually an **issue-level** feature:
`Issue.blockedBy` / `Issue.blocking` (both `IssueConnection`), with
mutations `addBlockedBy` / `removeBlockedBy`. Input shape:
`AddBlockedByInput { issueId, blockingIssueId }`.

So cross-sub-issue dependencies are wired via `addBlockedBy` directly on the
two issues, not via any Projects v2 item field — confirmed via
introspection rather than assumed, per the brief's explicit caution not to
substitute a workaround field if the real mechanism turned out to be
something else.

## Sequence field — did not exist, created as TEXT

Not present in the original 17 fields. `ghp/project.py:ensure_sequence_field()`
checks for a field named "Sequence" on first use and creates it via
`createProjectV2Field(dataType: TEXT, ...)` if missing, then caches the
resulting id in-process. Text (not number/single-select) so it can hold
dotted-letter values like `3.a`/`3.b` for parallel tracks, per spec.

## Hook events for Plan Mode — partially hookable, documented limitation

`EnterPlanMode` and `ExitPlanMode` are real tool names in this Claude Code
version (confirmed: both appear as invokable tools in-session), so both are
matchable by a `PreToolUse`/`PostToolUse` hook the same way this repo's own
`hooks/hooks.json` already matches on tool names like `"Agent"` or `"Write"`.

- **`ExitPlanMode` is hooked** in `.claude/settings.json`: `PostToolUse`
  fires `plan_exit.py` with no `--confirm` flag, so it only prints the
  current draft — it cannot mutate GitHub, keeping it safe to auto-fire
  without violating the "no mutation without explicit approval" rule.
- **No hook covers stage 1 (issue creation on plan start).** `EnterPlanMode`
  is technically hookable the same way, but the tool call itself carries no
  plan title or content — a hook firing on it has nothing to create an issue
  *from*. This isn't "no event exists," as the original brief anticipated;
  it's "the event exists but is content-free," which amounts to the same
  practical conclusion: `/plan-start "<title>"` is the only real mechanism
  for stage 1, not a fallback bolted on next to a working automation.
- **Not verified**: whether a `PostToolUse` command hook's stdout is
  actually surfaced back into the conversation (vs. only its exit code
  mattering for continue/block semantics) was not live-fire-tested during
  this build — doing so would have meant deliberately invoking
  `EnterPlanMode`/`ExitPlanMode` outside of a real planning task. Treat
  `/plan-exit` as the reliable path regardless of whether the hook's output
  is visible; the hook is a convenience nudge, not the workflow's backbone.

## Insights fields (#1266) — resolved by name, charts UI-only

- 11 single-select fields and 3 NUMBER fields were created by
  `createProjectV2Field` with options, colours and descriptions. They are
  resolved **by name** at runtime (`project.ensure_insights_fields()`), so
  `config.py` holds option definitions, not IDs. Names are hyphenated
  (`Work-Type`), so chart filters need no quoting.
- The `Sprint` iteration field had 3 overlapping 7-day-apart iterations.
  It was rewritten via `updateProjectV2Field(iterationConfiguration:)` to ten
  14-day sprints from 2026-06-22.
- **There is no API for Insights charts** (GitHub Docs, checked 2026-10-12).
  Group by is documented only for current charts. Sum/Avg/Min/Max on the
  Y-axis needs NUMBER fields. Claude in Chrome is unavailable under WSL, so
  the charts were built by hand from `discovery/insights/chart-build-guide.html`.
- Item field writes are batched as about 20 aliased
  `updateProjectV2ItemFieldValue` mutations per request with a 1 s pause. A
  full board run (19,102 values) took about 75 min with no rate-limit retries.

## Scope note: why this lives under `.claude/`, not `commands/`/`hooks/`

`commands/*.md` and `hooks/hooks.json` at the repo root are the SDLC
Artifact Factory **plugin's own shipped components** — auto-discovered when
this repo is loaded as a plugin for a downstream product, per CLAUDE.md's
Component Architecture section. This tooling manages *this repo's own* dev
workflow against a personal project board; it has nothing to do with
products built by the plugin. Putting it in `.claude/commands/` and
`.claude/settings.json` keeps it scoped to this repo's own Claude Code
session and out of the plugin's discovered component inventory — verified
by inspecting `commands/` and `hooks/hooks.json` before adding anything, to
avoid it showing up in `claude plugin details` for this plugin.
