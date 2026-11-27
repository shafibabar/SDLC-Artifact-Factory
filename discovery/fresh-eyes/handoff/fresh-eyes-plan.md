# Fresh-Eyes Refactor — research-augmented skills on a 9-folder spec

## Context

The fresh-eyes discovery campaign (branch `discovery/fresh-eyes`) has expanded from *read-only discovery* to **discover + augment**. Measured today:
- Of 187 skills, **6** have had no content change since the research library arrived.
- **~91** were edited afterwards, but not demonstrably from the research.
- Only **17** cite a `research/` file.
- **9** skills are named in a research file's recommendations and have never been updated (e.g. `vision-statement`, whose "vision" format is really Moore's *positioning* statement).

Shafi wants every skill augmented with the research library **wherever applicable**, so skills carry industry and business depth rather than older-model general knowledge. Not every skill must cite a book. Skills are also restructured to a **9-folder progressive-disclosure spec** (pasted 2026-10-11).

Decisions (Shafi, 2026-10-11):
- **Full migration** to the folder spec. Existing content moves into the right folders: templates → `templates/`, worked examples → `examples/`, rule sets → `resources/`. Tooling and docs follow.
- **Evals** use the built-in `claude plugin eval` format, per skill, with the no-plugin baseline comparison. The 186 contract tests keep running until each skill's evals replace them.
- **Per-skill GitHub issues**, using the existing tooling in `scripts/github-project/`.
- **Examples scaled to the skill:** 1–5 per skill, simple → enterprise (multi-tenant, HA, multi-tier, scalable). None where nothing needs demonstrating.
- **Subagents run one at a time.** Every step persists progress, because session limits cut agents off three times today.

**Approval gate.** Approving this plan = "go" for **Phase A (standard + tooling) and Phase B (3-skill pilot) only**. Phase C (the waves) starts only after Shafi reviews the pilot skills.

## The folder spec (normative, as codified in Phase A)

`SKILL.md` (mandatory, uppercase): frontmatter plus a lean core. Optional folders, created **only when content warrants** (never empty):

| Folder | Holds |
|---|---|
| `references/` | Third-party docs, standards, deep explanation, looked up as needed |
| `resources/` | Governance rule sets, dictionaries, rigid schemas outputs are cross-checked against |
| `templates/` | Boilerplate the agent duplicates and fills (today's `assets/*-template.md`, `output-format-template.md`) |
| `examples/` | Few-shot input→output pairs, simple → enterprise. Fetched for edge or ambiguous cases |
| `steps/` | Stage files for multi-stage procedures, so later stages don't load early |
| `scripts/` | Deterministic executables: calculation, validation, scaffolding |
| `assets/` | Media, binary files, env/property files, metadata schemas. No longer templates |
| `evals/` | `claude plugin eval` cases + graders, golden datasets |

Rules:
- `SKILL.md` names **when** to read each file, with a **relative path** (`./templates/…`). No absolute paths and no `${CLAUDE_PLUGIN_ROOT}` inside skills.
- No mandated file names inside folders.

## Phase A — Standard + tooling (parent issue; one child per artifact)

A1. **Codify the spec**
- Rewrite the parts table, folder-decision test, quality criteria and anti-patterns in `skills/skill-authoring-standards/SKILL.md`, and move its own content to the new folders.
- Update CLAUDE.md § Skill Authoring and the Layout block. Update the README.

A2. **`sources:` frontmatter field**
- Optional: a list of `research/<cluster>/<file>.md` paths the skill draws on.
- Changes:
  - add it to `schemas/skill.schema.json`;
  - read it in `scripts/arch/manifest.py`;
  - `lint-manifests.py` checks that each listed file exists;
  - `build-catalog.py` emits `skill→research` edges plus a grounding-coverage figure.

A3. **New linter `scripts/lint-skill-layout.py`**
- Checks:
  - only the 8 allowed folder names;
  - no empty folders;
  - every file in a subfolder is reachable through relative-path pointers starting from `SKILL.md`;
  - no absolute paths;
  - `SKILL.md` is uppercase.
- Wiring: add it to `scripts/lint-all.sh` as **report-only** until the migration is done, then **blocking**. It gets its own test in `tests/arch/`.

A4. **Derived facts**
- `manifest.py` derives a `has_<folder>` flag for all 8 folders, extending today's `has_references/assets/scripts`.
- Catalog and its snapshot test updated.

A5. **Migration mechanics**
- A one-off script moves files by rule (`assets/*template*` → `templates/`, `references/worked-example*.md` → `examples/`, …) and rewrites the pointers in `SKILL.md`.
- Repoint the 10 `skills/*/scripts/scaffold-*.sh` (`TEMPLATE="$SKILL_DIR/assets/…"`) and their `tests/scripts/` tests.
- Extend `lint-duplication.py`'s template exclusion (`_scan_frontmatter_block`) to scan `templates/` and `examples/`.
- The script only moves files. Each skill's issue (Phase C) reviews the moves.

A6. **Evals runner**
- `tests/run-skill-evals.sh <skill>` wraps `claude plugin eval --eval-dir skills/<name>/evals --max-cost-usd <cap> --runs 3`, with the default with/without-plugin comparison.
- First confirm that a nested `--eval-dir` works. If it doesn't, fall back to a root `evals/<skill>/` layout.
- `manifest.py` derives `has_evals`.

## Phase B — Pilot (3 skills, then Shafi reviews)

- **`vision-statement`**: ungrounded, research-flagged. Sources: Cagan, Dunford, Moore. Separates vision from positioning.
- **`adr-authoring`**: has scripts, assets and validators, so it exercises the migration end to end.
- **One Go backend skill** (e.g. `go-repository-pattern`): checks the recipe on code-producing skills.

Together these set the exemplar recipe and the eval shape. Shafi reviews them before Phase C starts.

## Per-skill recipe (one sub-issue per skill)

1. **Audit.** Read the skill fully, every research file in its cluster(s), and any research file that names it. Record gaps in that wave's discovery findings file.
2. **Augment.** Fold in the research where it adds industry or business depth, and cite it in prose. Set `sources:`. Fix stale or ungrounded formats.
3. **Restructure** to the spec. Keep `SKILL.md` lean, and add only the folders it needs.
4. **Examples.** Scale to the skill, simple → enterprise (multi-tenant / HA / multi-tier / scalable), with phase-realistic inputs.
5. **Evals.** Cases + graders. The skill must beat the no-plugin baseline. Keep `tests/skills/<name>.contract.sh` until the evals pass, then retire it.
6. **Housekeeping.**
   - Version: MAJOR if the `description` (trigger surface) changes, otherwise MINOR.
   - Rebuild the catalog, then run `lint-all.sh`, the skill's evals and `--skill <name>`.
   - Finish with `exec_complete.py`.

Tooling:
- `plan_start.py` creates the parent issue.
- `save_draft.py` + `plan_exit.py` create the sub-issues.
- `exec_start.py <N> --base <wave-branch>` starts each skill.
- `exec_complete.py <N> "<msg>"` commits, pushes and moves the issue to In Review.

## Phase C — Waves (after the pilot is approved)

Each wave gets a parent issue and an integration branch `fresh-eyes/<wave>`. Children branch per skill and merge back. The wave merges to `main` when it completes, with the four-file housekeeping and a CHANGELOG entry.

Order (research-richest and least-grounded first):
1. strategy + discovery + validation
2. domain-modeling + architecture
3. testing
4. platform + observability
5. security
6. data + governance
7. frontend + ux
8. backend Go
9. backend Python

Each wave's findings file replaces the old read-only passes 02–08.

**Execution:** one subagent per skill, run in sequence. Each one gets the recipe, the exemplar pilot skills and its research list. A progress table in `discovery/fresh-eyes/README.md` is updated after every skill.

## Remaining discovery (unchanged, run between waves)

- 01 dogfood: resume from Ideate and get to Design.
- 09 agents / commands / hooks.
- 10 maintainability.
- 11 portability.
- 12 synthesis, which also makes the Architecture Review P5–P9 keep/change/drop call. P8 (test infra) is partly absorbed by A6.

## Verification

- **Phase A:**
  - new tests pass for `lint-skill-layout`, `sources` (schema + linter) and `has_*`;
  - `scripts/lint-all.sh` exits 0;
  - `tests/run-smoke-tests.sh scripts schemas arch` is all green;
  - all 10 scaffold scripts still produce valid artifacts.
- **Per skill:**
  - the layout linter is clean for that skill;
  - evals pass, with a **positive baseline delta**;
  - the contract test passes until it's retired;
  - the catalog is current.
- **Campaign:** the catalog's grounding coverage and has_evals counts rise each wave, and `lint-skill-layout` turns blocking once every skill is migrated.
