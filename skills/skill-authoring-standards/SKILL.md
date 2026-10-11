---
name: skill-authoring-standards
description: >
  The canonical rubric for shaping, writing, grounding, testing and versioning a
  Claude Code Agent Skill in this plugin. Use when creating a new skill,
  refactoring or migrating an existing one, deciding which folder a piece of
  skill content belongs in (references/, resources/, templates/, examples/,
  steps/, scripts/, assets/), writing a description as a trigger surface,
  declaring research grounding with sources:, scaling examples from simple to
  enterprise, writing evals under evals/<skill>/, or choosing a version bump.
  Consulted at the start of every skill-refactor session. Cross-cutting
  governance skill alongside glossary-management and methodology-review.
version: 2.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-23
tags: [skill-authoring, progressive-disclosure, governance, cross-cutting, meta]
produces: skill-definition
domain: governance
status: stable
related: [glossary-management, methodology-review]
sources:
  - research/ai-agent-engineering/mastering-claude-code-agent-skills-gale.md
  - research/ai-agent-engineering/context-engineering-for-ai-agents-zhu.md
---

# Skill Authoring Standards

## Purpose

A skill is prose consumed by Claude, not code a runtime executes. "Does this skill work?" is therefore answered by triggering it and measuring behaviour, never by reading it for coherence. With nearly 190 skills, imitating whichever skill was refactored last no longer keeps them consistent. This skill is the checkable standard every skill is built and judged against.

It governs *this plugin's own components* and teaches nothing about a product's domain. It sits beside `glossary-management` (canonical vocabulary) and `methodology-review` (methodology compliance) as the third cross-cutting authority. The model comes from Gale, *Mastering Claude Code Agent Skills* (three load tiers, the description as trigger surface, self-contained references, two-surface versioning). The decision about what loads when comes from Zhu, *Mastering Context Engineering for AI Agents* (always-resident, session-resident and retrieved-on-demand context). The six named terms used here (Trigger Surface, Resident Content, Skill Collision, Progressive Disclosure, Declared Composability, Self-Contained Reference) are defined in `references/vocabulary-and-collision-detection.md`; read it when a term is unclear or when checking two skills for overlap.

---

## The Skill Shape: One Entry File, Seven Optional Folders

`SKILL.md` (exactly that name, uppercase) is the only mandatory file. It is the skill's engine: it holds what most invocations need and tells the agent *when* to open anything else. Every other folder is optional and is created **only when content earns it**. Most skills need few or none, and an empty folder is a defect.

| Folder | Holds | Loaded when |
|---|---|---|
| `references/` | Documentation and standards to look up: third-party docs, deep explanation, conventions | The body says to consult it for a specific question |
| `resources/` | Rules the output is cross-checked against: governance rule sets, dictionaries, rigid schemas | Before handing off, to validate the output |
| `templates/` | Skeletons the agent copies and fills: document structures, scaffolds, empty tables | When producing the artifact |
| `examples/` | Input → output demonstrations, simple to complex | For edge cases, ambiguity, or the harder variants (multi-tenant, HA, multi-tier, scale) |
| `steps/` | One file per stage of a long multi-stage procedure | One stage at a time, so later stages don't crowd the context early |
| `scripts/` | Deterministic executables: exact calculation, validation, scaffolding | When the procedure says to run one |
| `assets/` | Media, binary files, env/property files, metadata schemas | When the procedure needs the file itself |

Evals do **not** live in the skill. They go in the repo-root `evals/<skill>/`, for two reasons: the eval runner refuses any eval directory inside `skills/`, and golden answers stored beside a skill load with it and leak into the run they grade.

### The folder decision test

For each piece of content, ask in order:
1. **Do most invocations need it to make a decision?** Then it stays in the body.
2. Is it something you'd **run**? → `scripts/`. **Copy and fill**? → `templates/`. **Check output against**? → `resources/`. **Learn from by example**? → `examples/`. **Read stage by stage**? → `steps/`. **Look up**? → `references/`. **Use as a file, not prose**? → `assets/`.
3. Does it answer two of those at once ("template and examples")? Then **split it**. A mixed file belongs in no single folder.

The body should stay under ~200 lines below the frontmatter. That is a prompt to apply the test, not a hard block. To see the test worked at three scales, read `./examples/01-simple-lookup-skill.md` (no folders), `./examples/02-growing-saas-skill.md` (references, templates, examples) and `./examples/03-enterprise-multistage-skill.md` (all seven folders, plus evals and sources).

---

## Pointers: Relative, and Always Saying When

Every file in a folder must be reachable from `SKILL.md`, directly or through another file. Each pointer must state the **condition** for reading it. "See `references/<file>.md`" tells the agent nothing; "If the resource belongs to a tenant, follow `./examples/<tenant-case>.md`" does.

Pointers are **relative to the skill's own root and start with `./`**: `./templates/<file>.md`, `./references/<file>.md`, or `../examples/<file>.md` from inside a folder. The `./` makes a pointer unambiguous: a bare `templates/` or `scripts/` in a skill may name a *product* path (a Helm chart's `templates/`) or the plugin's repo-root `scripts/`, so checks only trust `./` pointers (and the legacy bare `references/`). Never `skills/<name>/...`, an absolute path, or the plugin-root variable pointing into `skills/`. A skill must work wherever it is installed. (The plugin-root variable remains correct for invoking the plugin's own repo-root scripts, which are not skill content.) Every file in a folder is self-contained, loadable without the body in context, because it may be opened on a later turn or by a different skill.

---

## The `description` Is the Trigger Surface

`description` is what skill matching scores against a live prompt; it is not documentation (Gale, Ch. 5). Write it as if it were the only text deciding whether this skill fires. Name the nouns and verbs a real request contains, the owning agent, and the phase or command. A usage condition ("Use when…") beats a topic label ("This skill covers…"). Keep each skill to **one responsibility**. A skill covering two capabilities gets a description too vague to match or too long to stay cheap.

---

## Grounding: `sources:` and the Research Library

Where a book in `research/` informs the content, draw on it. Name it in the prose, and list it in the optional `sources:` frontmatter field (`research/<cluster>/<file>.md`). The governance gate fails if a listed file doesn't exist, and the catalog reports grounding coverage. Not every skill must cite research. But a skill that attributes a framework ("per Moore") must trace that to a research file it actually draws on, or drop the attribution. A framework cited from memory looks grounded and isn't.

## Examples: Scaled to the Skill

Give as many examples as the variety of real use demands: none for a lookup skill, several for a skill used across products. Order them from the simplest real case to the hardest the skill will meet: multi-tenant isolation, high availability, multi-tier, multi-region, scale. Each example is a self-contained input → output pair, so the agent can generalise from it rather than fall back on generic knowledge.

## Testing: Behaviour, Not Coherence

- **Evals.** Write cases at `evals/<skill>/<case>/prompt.md` with `graders/*.md`. Each asks something only the skill's content answers well, ideally content behind a pointer, so passing also proves progressive disclosure works. Run `tests/run-skill-evals.sh <skill>`. It passes only if every case passes **and** the skill beats the no-plugin baseline. A skill that scores the same without the plugin adds nothing Claude didn't already know.
- **Scripts.** Every `scripts/` file gets a synthetic-input test in `tests/scripts/`, with no model call.
- **Contract tests.** The existing `tests/skills/<name>.contract.sh` stays until the skill's evals pass, then retires.

## Declared Composability and Versioning

List every skill the prose names in the optional `related:` field. A prose "see `other-skill`" with nothing behind it breaks silently on a rename. Version bumps follow two surfaces (Gale, Ch. 8):

| Change | Bump |
|---|---|
| `description` changes in a way that could change what triggers it, or guidance is reversed or removed | MAJOR |
| Body or folder content added without changing the trigger surface | MINOR |
| Wording or typo fixes only | PATCH |

---

## Applying This Skill

**Creating a skill:** copy `./templates/skill-template.md` into `skills/<new-skill>/SKILL.md`. Write the body first; create folders only for content that passes the folder decision test.

**Refactoring a skill:**
- **Move files.** Run `python3 scripts/arch/migrate-skill-layout.py <skill>`. It does a dry run by default; add `--apply` to execute. It moves only unambiguous templates and examples, rewrites every pointer, and lists mixed files for you to split.
- **Augment.** Add research where it applies, and add examples at the scales the skill meets.
- **Test.** Write its evals.

**Before calling it done:** cross-check the skill against every row of `./resources/skill-quality-rubric.md`, not just the gap that motivated the work, then run the checks:
- `bash scripts/validate-skill-structure.sh skills/<name>/SKILL.md` — frontmatter, body length, and the full folder spec via `scripts/lint-skill-layout.py`;
- `python3 scripts/lint-manifests.py` — schema and `sources:` existence;
- `tests/run-skill-evals.sh <name>` — behaviour and baseline delta.
