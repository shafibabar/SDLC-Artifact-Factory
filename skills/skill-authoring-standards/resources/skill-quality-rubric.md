# Skill Quality Rubric

Self-contained — usable without `SKILL.md` in context. This is the rule set a new or refactored skill is cross-checked against before the work is called done. A refactor is complete only when **every** row passes, not just the row that motivated the refactor.

Rows marked **(tool)** are checked mechanically; the rest need a reader's judgment.

## Quality Criteria

| # | Criterion | Pass | Fail |
|---|---|---|---|
| Q1 | Single responsibility | The skill covers one coherent capability; `description` names it precisely | It quietly covers two or more unrelated capabilities |
| Q2 | `description` is a trigger surface | Names the nouns, verbs and owning agent a real prompt would contain, as a usage condition | Reads as an accurate topic summary with no usage condition |
| Q3 | Lean `SKILL.md` | The body holds only decision-shaping guidance and stays under ~200 lines below the frontmatter | A full template, worked example or exhaustive checklist sits resident in the body |
| Q4 | Folder discipline **(tool: `lint-skill-layout` L1–L3)** | Only `SKILL.md` at the root; only spec folders; no empty folder | A stray root file, a non-spec folder (`docs/`, `misc/`), or an empty placeholder folder |
| Q5 | Every file is reachable **(tool: L4)** | Each folder file is reached from `SKILL.md` through pointers, and each pointer says *when* to read it | A file nothing points to (dead weight), or a pointer with no trigger ("see also `x.md`") |
| Q6 | Relative pointers only **(tool: L5)** | Pointers are relative to the skill's own root (`./templates/x.md`, `references/y.md`) | `skills/<name>/...`, an absolute path, or the plugin-root variable pointing into `skills/` |
| Q7 | Folder files are self-contained | Each `references/`, `resources/`, `examples/` or `steps/` file is usable without the body in context | A file written as a continuation of the body's train of thought |
| Q8 | Grounded where research applies **(tool: `lint-manifests` checks `sources:` exist)** | Where a `research/` book informs the content, the prose names it and `sources:` lists it | Framework names cited from memory with no research file behind them, or `sources:` listing files the content does not draw on |
| Q9 | Examples scaled to the skill | Examples run from the simplest real case to the hardest the skill will meet (multi-tenant, high availability, multi-tier, scale), as many as the variety of real use needs | One toy example, or many near-identical ones; enterprise cases missing for a skill used on enterprise products |
| Q10 | Templates are genuinely copyable | A `templates/` file is used as-is and filled in, needing little rewriting | A "template" that must be substantially rewritten every time (it was guidance, so it belongs in `references/`) |
| Q11 | Scripts are deterministic and tested | Every `scripts/` file has a synthetic-input test under `tests/scripts/` | A script exercised only through a live model call, or not at all |
| Q12 | Evals beat the baseline **(tool: `tests/run-skill-evals.sh`)** | `evals/<skill>/` cases pass, and the mean delta against the no-plugin baseline is positive | No evals, or evals that Claude passes just as well without the plugin (the skill adds nothing) |
| Q12a | Evals authored independently **(tool: `run-skill-evals.sh` prints the freeze status)** | A fresh subagent that never saw the rewritten skill wrote the suite; a `Freeze evals: <skill>` commit precedes the first run; every eval file changed since is logged in the PR with its reason | The rewriting session wrote its own exam, no freeze commit, or a grader loosened after the skill failed it |
| Q13 | Declared composability | Every other skill named in prose is listed in `related:` | A prose "see `other-skill`" that no field backs, so a rename silently breaks it |
| Q14 | Version bump matches change | `description` (trigger) change → MAJOR; body or folder content → MINOR; wording → PATCH | A trigger-surface change shipped as MINOR or PATCH |

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Description as documentation** | The matcher has no usage condition to score; an accurate summary can still fail at its actual job | Write it as the only text deciding whether this skill fires; name nouns, verbs and the owning agent |
| **The unsplit skill** | Every invocation pays for content only some need; the body becomes a chore to read even when correct | Apply the folder decision test per section; keep only decision-shaping guidance resident |
| **The speculative folder** | An empty or near-empty folder signals structure the content does not have, and costs a reader a look | Create a folder only when there is content for it; delete it when it empties |
| **The pointer with no trigger** | "See `references/x.md`" never tells the agent *when*, so it reads everything or nothing | Write the condition: "When the tenant model is shared, read `./examples/shared-tenancy.md`" |
| **Golden answers beside the skill** | Eval datasets inside `skills/` load with the skill and leak the answers into the run they grade; the runner refuses that location | Keep evals at the repo root, `evals/<skill>/<case>/` |
| **The self-graded exam** | The session that rewrote the skill writes cases that check what it wrote, and after a failure it decides alone whether the skill or the grader was wrong | A fresh subagent writes the suite from the sources (`../templates/eval-author-brief.md`); freeze it; change a grader only when it is shown wrong, and log why in the PR |
| **Name-dropped authority** | "Per Moore" or "per Cagan" written from memory looks grounded but isn't traceable to anything the plugin owns | Draw on the `research/` file, cite it in prose, list it in `sources:` — or drop the attribution |
| **Toy examples only** | The agent meets an enterprise, multi-tenant or high-availability case with no demonstration and falls back to generic knowledge | Add the harder cases the skill will really meet, simple → complex |
| **The template that isn't copyable** | It saves no work and hides guidance where a reader won't look for it | Move the guidance to `references/`; keep only the fill-in skeleton in `templates/` |
| **Mixed files** | One file that is half template and half guidance belongs in two folders and is right in neither | Split it: skeleton → `templates/`, prose → `references/` |
| **The script nobody tests** | A described behaviour is not a verified one; a rarely-triggered script can stay broken for months | Every skill-owned script gets a synthetic-input test in `tests/scripts/` |
| **Version bump blindness** | Discovery behaviour changes under a version number that says nothing changed | Bump MAJOR whenever `description` changes in a way that could change matching |
