---
name: sdlc-config-management
description: >
  sdlc-config.json — the per-product configuration file the /sdlc-start
  questionnaire writes, recording only tech-stack, compliance-framework,
  deployment-model, and methodology-parameter choices that OVERRIDE
  CLAUDE.md's Tech Stack Defaults. Covers the override-only principle, the
  two-tier config-then-default precedence lookup an agent performs before
  applying any default, who may change the file (only Shafi, via a recorded
  decision), _meta.last_updated / updated_by tracking, and validation against
  schemas/sdlc-config.schema.json. Consulted by every agent resolving a
  tech-stack fact (api_framework, primary_database, graph_database,
  optional_database, deployment_model), by the /sdlc-start command that writes
  it, and by hooks checking an artifact matches the product's real config.
version: 2.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, configuration, sdlc-config, tech-stack, questionnaire, per-product]
produces: sdlc-config
domain: governance
status: stable
related: [artifact-manifest, methodology-review, skill-authoring-standards]
---

# SDLC Config Management

## Purpose

CLAUDE.md's Tech Stack Defaults table gives this plugin a sensible starting configuration for every product it builds — Go, `net/http` + chi, PostgreSQL, Redpanda, and so on. Not every product needs every default. `sdlc-config.json` is the per-product record of where a specific product's configuration diverges from those defaults, populated interactively by the `/sdlc-start` questionnaire and consulted by every agent for the remainder of that product's build.

This skill defines the config file's shape, the precedence rule between it and CLAUDE.md, who may change it and how, and the obligation every agent has to check it before falling back to a CLAUDE.md default. The exhaustive field reference (every field, type, constraint), the questionnaire-question-to-field mapping, and a full worked config for this repo's data-estate product live in **`references/config-field-reference.md`**, derived directly from `schemas/sdlc-config.schema.json`.

## Precedence Rule

**`sdlc-config.json` overrides CLAUDE.md defaults. CLAUDE.md defaults apply wherever a product does not override them.**

This is a two-tier lookup, always performed in this order:

1. Check `sdlc-config.json` for the field in question. If present, use it — it is the product's deliberate choice.
2. If absent, use the corresponding default from CLAUDE.md's Tech Stack Defaults table (or the relevant methodology/naming/artifact-standard section for non-tech-stack fields).

There is no third tier. An agent never invents a configuration choice that exists in neither file — an unresolvable gap is an open question for Shafi, handled per the working agreements in CLAUDE.md and `sdlc-context.json`, not a default to be improvised.

No agent resolves an entire product configuration once and caches it informally — each fact is looked up field-by-field against the same two-tier order, so a partial config update (Shafi overrides one more field mid-project) is picked up correctly by every subsequent artifact without any agent needing to "know" the change happened through a channel other than the file itself.

## The Override-Only Principle

`sdlc-config.json` never repeats a CLAUDE.md default unchanged. If a product uses Go, `net/http` + chi, PostgreSQL, and Redpanda exactly as CLAUDE.md specifies, none of those fields appear in `sdlc-config.json` at all — the file may be nearly empty, and that is correct, not incomplete.

This matters for two reasons:

1. **Drift risk.** A repeated-but-unchanged field is a second copy of a fact that already lives in CLAUDE.md. If CLAUDE.md's default later changes, every product config that redundantly copied the old value now silently contradicts the new default instead of inheriting it.
2. **Signal clarity.** A config file containing only overrides tells a reader, at a glance, exactly what makes this product different from the factory norm. A file padded with restated defaults hides the two or three fields that actually matter.

The four override categories are: **tech-stack overrides**, **compliance-framework selections**, **deployment-model choice**, and **per-product methodology parameters**. `references/config-field-reference.md` gives the exact JSON shape, type, and required/optional status of each, matching the schema.

## Methodology Parameters — Scope

Most of CLAUDE.md's five non-negotiable methodologies (DDD, Event Storming, TDD, BDD, SOLID) are not parameterized — they apply in full, always, with no product-level dial. `methodology_parameters` exists only for the narrow set of factory-wide calibration points that individual skills (not CLAUDE.md itself) define and that a specific product has reason to tune — e.g. mutation-testing cadence, a hard unit-test coverage number, contract-testing scope.

A methodology parameter is never used to weaken one of the five non-negotiables themselves — it tunes a calibration point *within* a methodology's implementation, never whether the methodology applies at all. The full parameter table with example overrides is in `references/config-field-reference.md`.

## Validation Against the Schema

`sdlc-config.json` is formalized machine-readably as `schemas/sdlc-config.schema.json` (Draft 2020-12; see `settings.json → env.SDLC_CONFIG_SCHEMA`). The schema encodes the override-only shape directly: only `_meta`, `product`, and `product_slug` are required; every content field (`tech_stack_overrides`, `compliance_frameworks`, `deployment_model`, `methodology_parameters`) is optional, so a product that overrides nothing still validates. `product_slug` is constrained to the component-naming pattern `^[a-z0-9]+(-[a-z0-9]+)*$` because it becomes the prefix of every artifact ID (see `artifact-manifest`).

One validator caveat: JSON Schema's `format: date` is annotation-only unless the validator explicitly enables format assertion (e.g. `jsonschema`'s `FormatChecker`) — a schema-conformant validator that skips this silently accepts a malformed `_meta.last_updated`.

## Versioning and Change Management

Changing `sdlc-config.json` mid-project is a decision, not a file edit:

1. **Only Shafi authorizes a config change.** No agent changes the file on its own initiative — a tech-stack or compliance-scope change is exactly the consequential, cross-cutting choice CLAUDE.md's Session Startup and Agent Behaviour Rules reserve for his approval.
2. **The rationale is recorded in `sdlc-context.json → decisions`.** Every config change gets a decision entry — what changed, why, and what alternative was rejected — following the shape of existing entries (e.g. D006, D009). The config file records *what* the current state is; the decisions array records *why* it changed.
3. **The config file's own `_meta` increments.** `_meta.last_updated` and `_meta.updated_by` follow `sdlc-context.json`'s `_meta` convention — updated on every change, with `updated_by` pointing at the decision ID that authorized it.
4. **Downstream artifacts are not silently invalidated.** If a config change affects artifacts already produced under the old configuration (e.g. switching `graph_database` after a data model assumed Apache AGE), the affected artifacts are flagged for revision via the artifact manifest's `status` field (`artifact-manifest`) — not left to quietly drift.

## Agent Obligation: Check Config Before Defaulting

Every agent already reads `sdlc-context.json` first before producing an artifact. This skill extends that rule to `sdlc-config.json`:

**Before applying any CLAUDE.md default, an agent must check whether `sdlc-config.json` overrides it for this product.** Concretely: `backend-engineer` does not assume `net/http` + chi without checking `sdlc-config.json → tech_stack_overrides.api_framework`; `platform-engineer` does not assume a deployment model without checking `sdlc-config.json → deployment_model`. The check costs one file read and prevents an entire artifact from being built against the wrong configuration.

An agent that applies a CLAUDE.md default without checking for an override is silently discarding a decision Shafi already made at `/sdlc-start` or in a later config change. This is a defect, not a stylistic gap.

## Relationship to `/sdlc-start`

`sdlc-config.json` is created once, at the start of a product's build, by the `/sdlc-start` command's interactive questionnaire (see `sdlc-context.json → tech_stack.sdlc_start_questionnaire`). The command asks Shafi a fixed set of questions — one per Tech Stack Defaults row, plus compliance scope and deployment model — and for each, a "keep the default" answer writes nothing to the file, while an "override" answer writes exactly the overriding field. This is what keeps the override-only principle mechanically enforced: the file starts empty and grows only by explicit divergence. The full question-to-field mapping is in `references/config-field-reference.md`.

`/sdlc-start` is a command (a workflow), not this skill — this skill defines the standard the command's output must conform to.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Override-only | Every field present differs from the CLAUDE.md default | A field restates the value CLAUDE.md already specifies |
| Precedence respected | Every agent checks `sdlc-config.json` before applying a default | An agent applies a default without checking for an override |
| Change authorized | Every value traces to a decision Shafi made | A config value with no corresponding decision or `/sdlc-start` record |
| Rationale recorded | Mid-project changes have a matching `sdlc-context.json → decisions` entry | Config edited with no decision entry |
| Downstream impact tracked | Artifacts under a superseded config are flagged via the manifest | Artifacts left assuming the old config |
| `_meta` maintained | `last_updated`/`updated_by` reflect the latest change | Stale `_meta` after a change |

## Anti-Patterns

- **Default restatement** — copying CLAUDE.md's defaults into the file "for clarity." Creates a second source of truth that goes stale when defaults evolve. This is the primary anti-pattern this skill exists to prevent.
- **Silent override-ignoring** — an agent applies the CLAUDE.md default without having checked `sdlc-config.json` first; the artifact no longer matches the product's real configuration.
- **Unauthorized config changes** — an agent edits `sdlc-config.json` on its own judgment mid-build, without Shafi's approval and without a decision entry.
- **Orphaned overrides** — a field is added for a decision later reversed but never removed, so the config keeps overriding a choice nobody holds. Reverting a decision means removing the field.
- **Vague deployment/compliance fields** — `"deployment_model": "private"` without naming which documented option, or `"compliance_frameworks": ["SOC 2"]` without the specific control families. Values must be specific enough to act on without a follow-up question.
- **Config drift from `sdlc-context.json`** — a config value contradicting something already confirmed in `sdlc-context.json → tech_stack.confirmed` or `→ first_product`, introduced without reconciling the two.

## Output Format

The output is a machine-readable JSON file (not a Markdown artifact) at the product's root config path, conforming to `schemas/sdlc-config.schema.json`. The full skeleton, the exhaustive field reference, and a validated worked example for the data-estate product are in **`references/config-field-reference.md`**.
