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

## Refactor campaign progress (scope expanded 2026-10-11: discover + augment)

Plan: `~/.claude/plans/now-that-opus-5-5-transient-blossom.md`. Phase A + B approved; Phase C needs Shafi's review of the pilot first.

| Phase | Parent | Status |
|---|---|---|
| A — folder spec, `sources:`, layout linter, evals runner, migration script, standard rewrite | #1224 | **done** — merged to main via #1237 (851ac0a), CI green |
| B — pilot: vision-statement, adr-authoring, one Go backend skill | — | next |
| C — domain waves (per-skill issues) | — | after Shafi reviews B |

Phase A facts a resuming session needs:
- Evals live at ROOT `evals/<skill>/<case>/` — `claude plugin eval` refuses dirs inside `skills/`.
- `tests/run-skill-evals.sh <skill>` passes only if all cases pass AND mean delta > 0. Cost ref: 3 cases × 2 runs ≈ $1.70.
- Skill pointers start with `./`. A bare `templates/` or `scripts/` may be a product path (Helm) or repo-root scripts.
- Layout baseline: 177/187 skills clean. The linter is report-only until the waves finish.
- Plan tooling runs from the main-tracking worktree, with `.state.json` symlinked to the primary checkout's.

## Side-task: required `summary` (DONE — merged to main in dc5d07f)

Make artifact frontmatter `summary` REQUIRED everywhere, then merge to main. Findings so far:
- Consumer: `scripts/memory/ingest.py` `build_texts()` uses `summary` verbatim as the L0 abstract (falls back to first paragraph, ~140 chars). Form it as ONE sentence, ≤ ~200 chars, placed after `created:`.
- 105 artifact-frontmatter templates in 89 skill files: 42 in SKILL.md, 45 in references/, 1 in assets/. Detect them with `_scan_frontmatter_block` in `scripts/lint-duplication.py` (name-first block with ≥3 of version/phase/owner/created). Shapes vary, e.g. vision-statement's has no `owner`.
- Also: the 10 `skills/*/scripts/scaffold-*.sh` (emit frontmatter) and `validate-*.sh` (check fields), with their tests in `tests/scripts/`. `scripts/validate-artifact-structure.sh` REQUIRED gets `summary` again, and its test fixture changes. Add `summary` to `ARTIFACT_FM_MANDATED_KEYS` in `lint-duplication.py`. Update CLAUDE.md § Artifact Standards (6 fields), README, `skills/memory-recall` (required again), and the `schemas/sdlc-manifest` check if relevant.
- Then: version bumps (MINOR), rebuild the catalog, `scripts/lint-all.sh`, `tests/run-smoke-tests.sh scripts schemas arch`, CHANGELOG, push main.
- Work in a separate worktree off `main` (the primary worktree is on `discovery/fresh-eyes`).
