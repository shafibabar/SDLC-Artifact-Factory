---
description: Run the full two-wave skill refactor workflow (discovery sub-issues, then implementation sub-issues) for one skill, using the issue-level integration-branch pattern
argument-hint: <skill-name> [--merge]
allowed-tools: Bash(python3 scripts/github-project/plan_start.py:*), Bash(python3 scripts/github-project/save_draft.py:*), Bash(python3 scripts/github-project/plan_exit.py:*), Bash(python3 scripts/github-project/exec_start.py:*), Bash(python3 scripts/github-project/exec_complete.py:*), Bash(python3 scripts/github-project/plan_status.py:*), Bash(git checkout:*), Bash(git pull:*), Bash(git push:*), Bash(git status:*), Bash(git diff:*), Bash(gh issue view:*), Bash(gh pr view:*)
---

Arguments: `$ARGUMENTS` — the first whitespace-separated token is the skill name (e.g. `bounded-context-mapping`); an optional trailing `--merge` means merge the final integration PR to `main` yourself once every sub-issue lands. Without `--merge` (the default), leave the final PR open for Shafi's own review — this is the `aggregate-design` precedent, not the earlier three-skill batch that auto-merged.

This is the full two-wave process agreed 2026-07-24: **discovery sub-issues are drafted and executed first; implementation sub-issues are drafted only after discovery's real findings are known** — never predict the reference-file/content shape before the research that should determine it has actually run. Every step below is meant to be followed by a fresh session with no memory of prior conversations, so don't skip steps because they seem obvious.

Every issue and sub-issue created in this workflow needs `--labels` (Shafi's
decision, 2026-07-24): one or more of discovery, agent, skill, bug,
documentation, enhancement. Wave 1 sub-issues are `discovery`. Wave 2
sub-issues are normally `skill`, plus `agent` if the row touches an
`agents/*.md` file, plus `documentation` for the trailing housekeeping row
(glossary/sdlc-context.json/CHANGELOG). PRs need no separate label choice —
`exec_start.py` mirrors whatever labels are already on the sub-issue.

## Wave 0 — Setup

1. Read `CLAUDE.md` and `sdlc-context.json` in full (session-startup discipline applies here too, even mid-session).
2. Read the target skill's current `skills/<name>/SKILL.md` in full, and every file under `skills/<name>/references/` if any already exist.
3. `grep -rl` across `research/` for anything already relevant to this skill's topic. Read every hit in full, not just matching filenames.
4. Run `python3 scripts/github-project/plan_start.py "<title>" --labels skill` — name the skill and signal this is a rebuild under `skill-authoring-standards`.
5. Write a provisional issue body via `gh api repos/<owner>/<repo>/issues/<N> -X PATCH -f body="..."` — **never `gh issue edit`, which has a known GraphQL bug on this repo**. State the intent plainly and flag the implementation plan as provisional pending discovery.
6. Create and push the integration branch: `git checkout -b issue-<N>-<slug> main && git push -u origin issue-<N>-<slug>`.

## Wave 1 — Discovery (research sub-issues only)

7. Decide the discovery sub-issue list:
   - One sub-issue per book that needs genuinely new research — a book directly relevant to this skill's topic with no existing `research/` file covering it.
   - **Always at least one discovery sub-issue**, even when no new book is needed. In that case its job is: check `research/` thoroughly, confirm whether existing coverage is sufficient, and document the finding. Never skip this or fold it into planning without a GitHub artifact — this is a deliberate, standing preference, not an optional nicety.
8. Draft each via `save_draft.py add --title ... --description ... --labels discovery` (specific: which book, what to ground it against, expected content areas) and create them via `plan_exit.py --confirm`.
9. For each discovery sub-issue, in dependency order:
   - `exec_start.py <N> --base issue-<N>-<slug>`
   - **New research**: spawn a foreground Agent (`subagent_type: general-purpose`, `run_in_background: false`) with a self-contained prompt instructing it to read `CLAUDE.md`, the target skill, any adjacent skills to check against, and any already-completed sibling research files in the same cluster (to avoid duplication) — then write `research/<cluster>/<book-slug>.md` matching the section shape every existing `research/` file uses: `# Title`, `**Authors:**`, `**Domain:**`, `## Core Concepts`, `## Actionable Techniques`, `## Applies To`, `## Candidate New Skills/Agents`, `## Key Terminology`, `## Caveats`. Point it at an existing file (e.g. `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`) as the structural template. Tell it explicitly to ground every claim in something it actually read in this repo, never invent content from general book knowledge alone.
   - **Confirming existing coverage**: read the relevant research files directly yourself; no new file is needed unless the check reveals a real gap.
   - Verify the output before staging (read the file back, check its section headers are all present).
   - `exec_complete.py <N> "<commit message covering what was researched or checked, and what was found>"` — auto-merges into the integration branch and auto-closes the sub-issue.

## Synthesis checkpoint (planning work, not a sub-issue)

10. Once every discovery sub-issue is closed, read what was actually found — every research file produced or re-confirmed in Wave 1. Determine the real implementation plan from that evidence: how many `references/` files are warranted and what goes in each, whether `scripts/`+`assets/` make sense and what they should do, whether new canonical glossary terms are needed. Do not reuse a structure you guessed before discovery ran.
11. Update the parent issue body (`gh api ... -X PATCH`) replacing the Wave-0 provisional description with the full, evidence-based plan — name every sub-issue about to be drafted in Wave 2.

## Wave 2 — Implementation

12. Draft the implementation sub-issues via `save_draft.py add --labels skill` (add `agent` too for any row touching `agents/*.md`; the trailing housekeeping row is `--labels documentation,skill`): an architecture blueprint sub-issue first (no dependencies — produces a thin `SKILL.md` plus stub `references/` files with real section headers and a one-paragraph brief per section, reviewable on its own before deep content fills it in), then content-writing sub-issues (depending on the blueprint, grouped by what discovery actually revealed — not a pre-guessed grouping), then scripts/assets (depending on content), then tests (depending on scripts/assets), then housekeeping last. Create via `plan_exit.py --confirm` — a second, separate wave under the same parent issue.
13. For each implementation sub-issue, in dependency order:
    - `exec_start.py <N> --base issue-<N>-<slug>`
    - Do the work directly for scripts/tests/housekeeping-scale work; spawn a foreground content-writing Agent for substantial reference-file authoring, with a self-contained prompt naming exactly which files to read (research files, already-completed sibling reference files, adjacent existing skills to stay consistent with) and exactly which stub sections to fill in.
    - Verify the output before staging: read the files back, run any new test scripts live, confirm zero stub/placeholder markers remain.
    - `exec_complete.py <N> "<commit message covering what was implemented, what was reviewed, and what was verified>"`.

## Finalize

14. Once every sub-issue is closed, run `git diff main...issue-<N>-<slug> --stat` to confirm the full diff is clean and scoped only to this effort — no unrelated files.
15. Open the final integration-branch → `main` PR with a comprehensive description: what changed, the most consequential findings from discovery, what was verified before landing.
16. If `--merge` was passed: merge the PR, post a closing summary comment on the parent issue, and run `plan_status.py done`. If not: leave the PR open, post a summary comment on the parent issue explaining what's ready for review, and do **not** run `plan_status.py done` — that waits for Shafi's own merge, matching the `aggregate-design` precedent and decision D026's timing rule (don't mark a plan done until the actual merge happens, not when sub-issue work merely finishes landing on the integration branch).

Report progress at each wave boundary — Wave 0 complete, all discovery sub-issues closed, synthesis complete (name the resulting plan), all implementation sub-issues closed, final PR opened — don't go silent across an effort this size.
