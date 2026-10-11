# Fresh-Eyes Discovery (started 2026-10-11)

A whole-repo traversal to find refactor ideas. It looks at the components **as they actually are**, not through CLAUDE.md / README.md / the Architecture Review charter. There are four lenses: **skill/agent depth, real-world usage, maintainability, portability**.

- **Approved by Shafi:** 2026-10-11 (plan mode). The approval covers **discovery only**. Every change outside `discovery/` needs a separate "go" after Shafi reviews the backlog.
- **Architecture Review campaign:** **paused at P5 (5/15), not abandoned.** The synthesis (pass 12) recommends whether P5–P9 continue, change or get dropped.
- **Branch:** `discovery/fresh-eyes`
- **Execution:** one subagent at a time (parallel runs hit Shafi's session limits). Each pass writes its file before the next starts.

## Cold-start / resume

1. Read this file and find the first pass that is not `done`.
2. Read the finished pass files before it (pass 01 especially, because it shapes the later ones).
3. Run that pass using the handoff rules below.

## Rules for every pass

**Fresh-eyes rule:**
- Read the component files first.
- Treat CLAUDE.md and the charter as *current rules to challenge*, not constraints. A proposal that breaks a rule names the rule it breaks.
- Every finding cites `file:line` evidence.
- No edits outside `discovery/`.

**Findings format.** Each pass file starts with a short narrative, followed by:

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact H/M/L | Effort S/M/L | Confidence |
|---|---|---|---|---|---|---|---|---|

- IDs are `P<pass>-<n>`, e.g. `P04-07`.
- `Kind` is one of: new-skill · new-reference · new-asset · new-script · new-test · description-rewrite · agent-change · command/hook-change · merge/delete · process · docs · portability · bug.

## Passes

| # | Pass | Lens | Status | File |
|---|---|---|---|---|
| 00 | Baseline health | all | done | [00-baseline.md](00-baseline.md) |
| 01 | Dogfood run (`--plugin-dir`, sample product) | usage | pending | 01-dogfood.md |
| 02 | Skills: backend (part 1) | depth | pending | 02-skills-backend-1.md |
| 03 | Skills: backend (part 2) | depth | pending | 03-skills-backend-2.md |
| 04 | Skills: testing | depth | pending | 04-skills-testing.md |
| 05 | Skills: platform + observability | depth | pending | 05-skills-platform-observability.md |
| 06 | Skills: data + governance | depth | pending | 06-skills-data-governance.md |
| 07 | Skills: architecture + domain-modeling + security | depth | pending | 07-skills-arch-ddd-security.md |
| 08 | Skills: frontend + ux + strategy + discovery + validation | depth | pending | 08-skills-front-strategy.md |
| 09 | Agents + commands + hooks + repo-root scripts | depth/usage | pending | 09-agents-commands-hooks.md |
| 10 | Maintainability | maintainability | pending | 10-maintainability.md |
| 11 | Portability | portability | pending | 11-portability.md |
| 12 | Synthesis: ranked backlog + P5–P9 re-plan | all | pending | 12-synthesis.md |
