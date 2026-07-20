---
name: sdlc-config-management
description: >
  Defines the shape and precedence rules for sdlc-config.json — the
  per-product configuration file the /sdlc-start questionnaire populates,
  recording only the tech-stack, compliance, deployment, and methodology
  choices that override CLAUDE.md's defaults. Consulted by every agent
  before applying a CLAUDE.md default, by the /sdlc-start command that
  writes it, and by hooks validating that an agent's output matches the
  product's actual configuration rather than an unchecked default.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, sdlc-config, configuration, tech-stack, cross-cutting]
---

# SDLC Config Management

## Purpose

CLAUDE.md's Tech Stack Defaults table gives this plugin a sensible starting configuration for every product it builds — Go, `net/http` + chi, PostgreSQL, Redpanda, and so on. Not every product needs every default. `sdlc-config.json` is the per-product record of where a specific product's configuration diverges from those defaults, populated interactively by the `/sdlc-start` questionnaire and consulted by every agent for the remainder of that product's build.

This skill defines the config file's shape, the precedence rule between it and CLAUDE.md, who may change it and how, and the obligation every agent has to check it before falling back to a CLAUDE.md default.

## Precedence Rule

**`sdlc-config.json` overrides CLAUDE.md defaults. CLAUDE.md defaults apply wherever a product does not override them.**

This is a two-tier lookup, always performed in this order:

1. Check `sdlc-config.json` for the field in question. If present, use it — it is the product's deliberate choice.
2. If absent, use the corresponding default from CLAUDE.md's Tech Stack Defaults table (or the relevant methodology/naming/artifact-standard section for non-tech-stack fields).

There is no third tier. An agent never invents a configuration choice that exists in neither file — an unresolvable gap is an open question for Shafi, handled per the working agreements in CLAUDE.md and `sdlc-context.json`, not a default to be improvised.

## Config Shape

`sdlc-config.json` records only fields that differ from CLAUDE.md defaults, organized into four categories:

| Category | Contains | Example |
|---|---|---|
| Tech stack overrides | Any field from CLAUDE.md's Tech Stack Defaults table that this product sets differently, plus optional fields (like `optional_database`) that CLAUDE.md exposes as a choice rather than a fixed default | `"graph_database": "Neo4j Community"` overriding the Apache AGE default, because graph is this product's primary surface |
| Compliance framework selections | Which compliance frameworks this product must satisfy, and which control families are in scope | `"compliance_frameworks": ["SOC 2 - CC6, CC7, A1"]` |
| Deployment model choice | Which of the product's supported deployment models applies to a specific customer instance | `"deployment_model": "Option B — managed private cloud, dedicated tenant"` |
| Per-product methodology parameters | Any methodology parameter that has a product-specific value rather than the factory-wide default (e.g. a non-standard test coverage threshold, a different mutation-testing cadence) | `"mutation_test_cadence": "weekly"` overriding the factory default of "periodic" |

## The Override-Only Principle

`sdlc-config.json` never repeats a CLAUDE.md default unchanged. If a product uses Go, `net/http` + chi, PostgreSQL, and Redpanda exactly as CLAUDE.md specifies, none of those fields appear in `sdlc-config.json` at all — the file may be nearly empty, and that is correct, not incomplete.

This matters for two reasons:

1. **Drift risk.** A repeated-but-unchanged field is a second copy of a fact that already lives in CLAUDE.md. If CLAUDE.md's default later changes (a new Tech Stack Defaults decision), every product's config that redundantly copied the old value now silently contradicts the new default instead of inheriting it — the two files disagree about a fact that was never actually a product-specific choice.
2. **Signal clarity.** A config file containing only overrides tells a reader, at a glance, exactly what makes this product different from the factory norm. A config file padded with restated defaults hides the two or three fields that actually matter for a decision.

### Methodology Parameters — Examples

Most of CLAUDE.md's five non-negotiable methodologies (DDD, Event Storming, TDD, BDD, SOLID) are not parameterized — they apply in full, always, with no product-level dial. `methodology_parameters` exists for the narrow set of factory-wide defaults set by individual skills (not CLAUDE.md itself) that a specific product has reason to tune:

| Parameter | Factory-wide default (set by the relevant skill) | Example override |
|---|---|---|
| Mutation testing cadence | Periodic, not per-PR (per `test-engineering/go-mutation-test`, chosen for frugality) | `"mutation_test_cadence": "weekly"` for a product with a compliance-critical rule engine, where the frugality trade-off is deliberately tightened |
| Test coverage threshold | No fixed factory-wide percentage; coverage reviewed qualitatively per `methodology-review` | `"unit_test_coverage_minimum": 85` for a bounded context handling PII classification, where Shafi wants a hard number |
| Contract testing scope | Consumer-Driven Contracts on service-to-service boundaries only | `"contract_testing_scope": "all boundaries including third-party storage connectors"` |

A methodology parameter is never used to weaken one of the five non-negotiables themselves — it tunes a calibration point *within* a methodology's implementation (how often mutation testing runs, what coverage number counts as sufficient), never whether the methodology applies at all.

## Versioning and Change Management

Changing `sdlc-config.json` mid-project is a decision, not a file edit:

1. **Only Shafi authorizes a config change.** No agent changes `sdlc-config.json` on its own initiative — a tech-stack or compliance-scope change is exactly the kind of consequential, cross-cutting choice that CLAUDE.md's Session Startup rule ("if Shafi has not said go... do not build") and Agent Behaviour Rules reserve for his approval.
2. **The rationale is recorded in `sdlc-context.json → decisions`.** Every config change gets a decision entry — what changed, why, and what alternative was rejected — following the same shape as existing entries (see `sdlc-context.json`'s `decisions` array, e.g. D006, D009). The config file records *what* the current state is; the decisions array records *why* it changed and *when*.
3. **The config file's own version increments.** `sdlc-config.json` carries a `_meta.last_updated` and a `_meta.updated_by` field, following the same convention as `sdlc-context.json`'s `_meta` block — updated on every change, pointing at the decision ID that authorized it.
4. **Downstream artifacts are not silently invalidated.** If a config change affects artifacts already produced under the old configuration (e.g. switching `graph_database` after `data-architect` has already produced a data model assuming Apache AGE), the affected artifacts must be flagged for revision — via the artifact manifest's `status` field (`governance/artifact-manifest`) — not left to quietly drift out of sync with the new config.

## Agent Obligation: Check Config Before Defaulting

Every agent in this plugin already follows the rule, stated in its own agent file, to read `sdlc-context.json` first before producing an artifact (for example: *"First, read `sdlc-context.json` — confirm the current phase..."*, as stated in `agents/backend-engineer.md`, `agents/platform-engineer.md`, and equivalently across every agent). This skill extends that same rule to cover `sdlc-config.json`:

**Before applying any CLAUDE.md default, an agent must check whether `sdlc-config.json` overrides it for this product.** Concretely: `backend-engineer` does not assume `net/http` + chi without checking `sdlc-config.json → tech_stack_overrides.api_framework` first; `platform-engineer` does not assume Option A deployment without checking `sdlc-config.json → deployment_model` first. The check costs one file read and prevents an entire artifact from being built against the wrong configuration.

An agent that applies a CLAUDE.md default without checking for an override is not using an out-of-date value by accident — it is silently discarding a decision Shafi already made at `/sdlc-start` or in a later config change. This is a defect, not a stylistic gap (see Anti-Patterns).

## Relationship to `/sdlc-start`

`sdlc-config.json` is created once, at the start of a product's build, by the `/sdlc-start` command's interactive questionnaire (see `sdlc-context.json → tech_stack.sdlc_start_questionnaire`). The command asks Shafi a fixed set of questions — one per Tech Stack Defaults row, plus compliance scope and deployment model — and for each question, a "keep the default" answer writes nothing to the file, while a "override" answer writes exactly the overriding field. This is what keeps the override-only principle mechanically enforced rather than relying on later discipline: the file starts empty and only ever grows by explicit divergence.

`/sdlc-start` is a command (a workflow), not this skill — this skill defines the standard the command's output must conform to. The command orchestrates the questionnaire; this skill is what an agent consults afterward to know how to read the result.

## Config Read Order in Practice

A concrete example of the two-tier lookup in action. When `backend-engineer` begins implementing a service, it resolves each tech-stack fact independently:

1. **API framework** — checks `sdlc-config.json → tech_stack_overrides.api_framework`. Not present in the worked example below → falls back to CLAUDE.md's `net/http` + chi.
2. **Optional database inclusion** — checks `sdlc-config.json → tech_stack_overrides.optional_database`. Present → uses MongoDB for the entity-extraction and crawl-metadata bounded contexts, per the override's stated scope; still uses PostgreSQL (the unoverridden default) for every other bounded context.
3. **Deployment model** — not `backend-engineer`'s concern directly, but it reads `sdlc-config.json → deployment_model` when instrumenting anything deployment-model-sensitive (e.g. tenant isolation checks), rather than assuming Option A or B.

No agent resolves an entire product configuration once and caches it informally — each fact is looked up field-by-field against the same two-tier order, so a partial config update (Shafi overrides one more field mid-project) is picked up correctly by every subsequent artifact without requiring every agent to "know" the change happened through any channel other than the file itself.

## Worked Example

`sdlc-config.json` for the running product (Data Estate Mapping and Compliance Intelligence). Per `sdlc-context.json → tech_stack`, no product-level tech-stack decisions have been overridden yet — the product's `status` is "Not yet started," and the `optional_database` (MongoDB) is explicitly called out as "exposed as config option at `/sdlc-start`. Not default," which this worked example confirms as taken. The deployment model is narrowed from the two options named in `sdlc-context.json → first_product.deployment_model` to the one this pilot customer instance actually uses:

```json
{
  "_meta": {
    "purpose": "Per-product configuration. Records only fields that differ from CLAUDE.md's Tech Stack Defaults and standard methodology parameters. Absence of a field means the CLAUDE.md default applies.",
    "how_to_use": "1. Check this file before applying any CLAUDE.md default. 2. If a field is present here, it overrides CLAUDE.md. 3. If absent, use the CLAUDE.md default. 4. Only Shafi may change this file; every change is recorded in sdlc-context.json's decisions array.",
    "last_updated": "2026-07-20",
    "updated_by": "D012 — /sdlc-start questionnaire, confirming MongoDB and Option B deployment for the pilot customer instance"
  },
  "product": "Data Estate Mapping and Compliance Intelligence",
  "product_slug": "dataestate",
  "tech_stack_overrides": {
    "optional_database": {
      "included": true,
      "value": "MongoDB",
      "rationale": "Entity extraction output and crawl metadata are variable-schema; used only for those bounded contexts, not as the primary database."
    }
  },
  "compliance_frameworks": [
    "SOC 2 - CC6, CC7, A1"
  ],
  "deployment_model": "Option B — managed private cloud, dedicated tenant, no data commingling",
  "methodology_parameters": {}
}
```

Everything not listed — `primary_language`, `api_framework`, `primary_database`, `message_broker`, `graph_database`, `ci_cd`, `iac`, `service_mesh`, `container_orchestration`, `observability`, `frontend` — uses the CLAUDE.md default unchanged, and correctly does not appear in this file.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Override-only | Every field present in the config differs from the CLAUDE.md default | A field is present with the same value CLAUDE.md already specifies |
| Precedence respected | Every agent checks `sdlc-config.json` before applying a CLAUDE.md default | An agent applies a CLAUDE.md default without checking for an override |
| Change authorized | Every value in the config traces to a decision Shafi made — at `/sdlc-start` or a later recorded change | A config value with no corresponding decision (in `sdlc-context.json → decisions` or the `/sdlc-start` record) |
| Rationale recorded | Config changes mid-project have a matching entry in `sdlc-context.json → decisions` | Config file edited with no decision entry explaining why |
| Downstream impact tracked | Artifacts produced under a superseded config are flagged via the artifact manifest | Artifacts silently left assuming the old configuration after a config change |
| `_meta` maintained | `last_updated` and `updated_by` reflect the most recent change | Stale `_meta` block after the config has changed |

## Anti-Patterns

- **Default restatement** — copying CLAUDE.md's defaults into `sdlc-config.json` unchanged "for clarity." This is the primary anti-pattern this skill exists to prevent: it creates a second source of truth for facts that were never product-specific, and that source silently goes stale when CLAUDE.md's defaults evolve.
- **Silent override-ignoring** — an agent applies the CLAUDE.md default anyway, without having checked `sdlc-config.json` first, because it assumed the default without verifying. The artifact produced no longer matches the product's actual configuration and the mismatch may not surface until integration.
- **Unauthorized config changes** — an agent edits `sdlc-config.json` on its own judgment mid-build, without Shafi's approval and without a corresponding decision entry. Configuration changes are consequential enough to require the same approval discipline as any other architectural decision.
- **Orphaned overrides** — a config field is added for a decision that later gets reversed, but the field is never removed, so the config continues to override a choice nobody actually holds anymore. Reverting a decision means removing (or updating) the corresponding config field, not leaving it in place.
- **Vague deployment/compliance fields** — recording `"deployment_model": "private"` without naming which of the product's documented options this is, or `"compliance_frameworks": ["SOC 2"]` without naming the specific control families in scope. Config values must be specific enough for an agent to act on without asking a follow-up question.
- **Config drift from `sdlc-context.json`** — a config value that contradicts something already confirmed in `sdlc-context.json → tech_stack.confirmed` or `→ first_product`, introduced without reconciling the two. The config narrows and instantiates what `sdlc-context.json` states at the plugin/product-definition level; it must not silently disagree with it.

## Output Format

This skill's output is a machine-readable JSON file consumed by every agent and by hooks, not a Markdown artifact — the usual `name`/`version`/`phase`/`owner`/`created` frontmatter does not apply to it. It follows `sdlc-context.json`'s own `_meta` convention for versioning and tracking metadata within the JSON:

```json
{
  "_meta": {
    "purpose": "<why this file exists and what it governs>",
    "how_to_use": "<numbered steps for how an agent should consult it>",
    "last_updated": "<YYYY-MM-DD>",
    "updated_by": "<decision id or event that produced the most recent change>"
  },
  "product": "<product name>",
  "product_slug": "<product slug>",
  "tech_stack_overrides": {
    "<field name matching a CLAUDE.md Tech Stack Defaults row>": "<override value, only if different from default>"
  },
  "compliance_frameworks": ["<framework and control families in scope>"],
  "deployment_model": "<the specific option this product/instance uses>",
  "methodology_parameters": {
    "<parameter name>": "<product-specific value, only if different from the factory-wide default>"
  }
}
```

Stored at the product's root config path referenced by `settings.json → env` conventions; formalized as `schemas/sdlc-config.schema.json` once built (see `settings.json → env.SDLC_CONFIG_SCHEMA`). Until then, this skill is the standard the schema will encode machine-readably.
