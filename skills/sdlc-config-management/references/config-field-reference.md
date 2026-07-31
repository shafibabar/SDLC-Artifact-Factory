# sdlc-config.json — Field Reference, Questionnaire Mapping, and Worked Example

Self-contained — loadable without reading `SKILL.md` first. This is the exhaustive companion to the `sdlc-config-management` skill: every field of `sdlc-config.json`, its type and constraints, the `/sdlc-start` question that populates it, and a full validated config for this repo's data-estate product. Every field below is derived directly from `schemas/sdlc-config.schema.json` (Draft 2020-12) — no field appears here that is not in the schema.

---

## The complete skeleton

```json
{
  "_meta": {
    "purpose": "<why this file exists and what it governs>",
    "how_to_use": "<numbered steps for how an agent should consult it>",
    "last_updated": "<YYYY-MM-DD>",
    "updated_by": "<decision id (e.g. D012) or event that produced the most recent change>"
  },
  "product": "<product name>",
  "product_slug": "<lowercase-hyphen slug, prefix of every artifact ID>",
  "tech_stack_overrides": {
    "<Tech Stack Defaults row this product overrides>": "<override value>",
    "optional_database": {
      "included": true,
      "value": "<database name>",
      "rationale": "<why, and for which bounded contexts>"
    }
  },
  "compliance_frameworks": ["<framework and control families in scope>"],
  "deployment_model": "<the specific option this product/instance uses>",
  "methodology_parameters": {
    "<parameter name>": "<product-specific value, string or number>"
  }
}
```

---

## Field-by-field reference

### Top-level structure

| Field | Type | Required | Meaning |
|---|---|---|---|
| `_meta` | object | **Yes** | Versioning/tracking block, mirroring `sdlc-context.json`'s `_meta` convention. See sub-table below. |
| `product` | string (minLength 1) | **Yes** | Human-readable product name (e.g. `"Data Estate Mapping and Compliance Intelligence"`). |
| `product_slug` | string, pattern `^[a-z0-9]+(-[a-z0-9]+)*$` | **Yes** | Set once at `/sdlc-start`. Becomes the prefix in every artifact ID for this product (see `artifact-manifest`'s ID scheme). Same naming pattern all components use. |
| `tech_stack_overrides` | object | No | Override-only map of Tech Stack Defaults rows this product sets differently. Absent/empty = every default used unchanged. |
| `compliance_frameworks` | array of strings | No | Frameworks and control families the product must satisfy. |
| `deployment_model` | string (minLength 1) | No | The specific deployment option this product/instance uses. |
| `methodology_parameters` | object | No | Product-specific overrides of narrow factory-wide calibration parameters. |

`additionalProperties: false` at the top level — no field outside this set is permitted. Only the three identity/tracking fields (`_meta`, `product`, `product_slug`) are required; every content field is optional, which is how the schema encodes the override-only principle (a product that overrides nothing still validates).

### `_meta` sub-fields

| Field | Type | Required | Meaning |
|---|---|---|---|
| `purpose` | string (minLength 1) | **Yes** | Why this file exists and what it governs. |
| `how_to_use` | string (minLength 1) | **Yes** | Numbered steps for how an agent should consult it. |
| `last_updated` | string, `format: date` | **Yes** | Date of the most recent change, `YYYY-MM-DD`. |
| `updated_by` | string (minLength 1) | **Yes** | A decision ID (e.g. `D012`) or the event that produced the most recent change. Every config change traces to a decision (see Versioning and Change Management). |

`_meta` is `additionalProperties: false` — exactly these four fields.

> **Validator caveat.** JSON Schema's `format: date` is annotation-only unless the validator explicitly enables format assertion (e.g. `jsonschema`'s `FormatChecker`). A schema-conformant validator that skips this silently accepts a malformed `last_updated` like `"2026-13-40"`.

### `tech_stack_overrides` — keys

The keys are **not a closed set**: they track whatever rows CLAUDE.md's Tech Stack Defaults table defines, which may grow over time. Two shapes are allowed:

- **`optional_database`** — a structured object, the one Tech Stack Defaults row CLAUDE.md exposes as an explicit *choice* rather than a fixed default. Required sub-fields (`additionalProperties: false`):

  | Sub-field | Type | Required | Meaning |
  |---|---|---|---|
  | `included` | boolean | **Yes** | Whether the optional database is used at all. |
  | `value` | string (minLength 1) | **Yes** | Which database (e.g. `"MongoDB"`). |
  | `rationale` | string (minLength 1) | **Yes** | Why, and for which bounded contexts. |

- **Any other row** (e.g. `graph_database`, `api_framework`, `primary_language`, `message_broker`) — matched by `additionalProperties`, a single string (minLength 1) naming the override value. Example: `"graph_database": "Neo4j Community"`.

A row appears here **only** if it differs from the CLAUDE.md default. The Tech Stack Defaults rows (all overridable) are:

| Concern | CLAUDE.md default | Override key |
|---|---|---|
| Backend language | Go | `primary_language` |
| API framework | `net/http` + `chi` | `api_framework` |
| Frontend | React + TypeScript | `frontend` |
| Primary database | PostgreSQL + `pgx` | `primary_database` |
| Message broker | Redpanda | `message_broker` |
| Graph database | Apache AGE | `graph_database` |
| CI/CD | GitHub Actions | `ci_cd` |
| IaC | OpenTofu + Helm | `iac` |
| Service mesh | Linkerd | `service_mesh` |
| Container orchestration | Kubernetes | `container_orchestration` |
| Observability | OTel + Prometheus + Tempo + Grafana | `observability` |
| Optional database | (none — explicit choice) | `optional_database` (structured object) |

### `compliance_frameworks`

Array of strings (each minLength 1). Each entry names a framework **and** its control families in scope — specific enough to act on. `"SOC 2 - CC6, CC7, A1"`, never just `"SOC 2"` (see the Vague-fields anti-pattern).

### `deployment_model`

Single string (minLength 1). Names the specific deployment option this product/instance uses — e.g. `"Option B — managed private cloud, dedicated tenant, no data commingling"`. Never vague (`"private"`).

### `methodology_parameters`

Object whose `additionalProperties` values may be **string or number** depending on the parameter (a cadence is a string, a coverage threshold is a number). Used only to tune a calibration point *within* one of the five non-negotiable methodologies — never to weaken whether a methodology applies.

| Parameter | Factory-wide default (set by the owning skill) | Example override |
|---|---|---|
| `mutation_test_cadence` | Periodic, not per-PR (per `go-mutation-test`, chosen for frugality) | `"weekly"` for a product with a compliance-critical rule engine |
| `unit_test_coverage_minimum` | No fixed factory-wide percentage; reviewed qualitatively per `methodology-review` | `85` for a bounded context handling PII classification |
| `contract_testing_scope` | Consumer-Driven Contracts on service-to-service boundaries only | `"all boundaries including third-party storage connectors"` |

---

## `/sdlc-start` questionnaire → config-field mapping

The `/sdlc-start` command asks Shafi a fixed set of questions — one per Tech Stack Defaults row, plus compliance scope and deployment model. For each, a "keep the default" answer writes **nothing**; an "override" answer writes exactly the overriding field. The file starts empty and grows only by explicit divergence.

| Questionnaire prompt (paraphrased) | Field written on override | Written on "keep default"? |
|---|---|---|
| "Product name?" | `product` | Always written (identity) |
| "Short slug for artifact IDs?" | `product_slug` | Always written (identity) |
| "Backend language — keep Go?" | `tech_stack_overrides.primary_language` | No |
| "API framework — keep net/http + chi?" | `tech_stack_overrides.api_framework` | No |
| "Frontend — keep React + TypeScript?" | `tech_stack_overrides.frontend` | No |
| "Primary database — keep PostgreSQL + pgx?" | `tech_stack_overrides.primary_database` | No |
| "Message broker — keep Redpanda?" | `tech_stack_overrides.message_broker` | No |
| "Graph database — keep Apache AGE?" | `tech_stack_overrides.graph_database` | No |
| "Include an optional (document/variable-schema) database?" | `tech_stack_overrides.optional_database` (object) | No (omitted if not included) |
| "CI/CD — keep GitHub Actions?" | `tech_stack_overrides.ci_cd` | No |
| "IaC — keep OpenTofu + Helm?" | `tech_stack_overrides.iac` | No |
| "Service mesh — keep Linkerd?" | `tech_stack_overrides.service_mesh` | No |
| "Container orchestration — keep Kubernetes?" | `tech_stack_overrides.container_orchestration` | No |
| "Observability — keep OTel/Prometheus/Tempo/Grafana?" | `tech_stack_overrides.observability` | No |
| "Which compliance frameworks and control families?" | `compliance_frameworks` | Written if any named |
| "Which deployment model for this instance?" | `deployment_model` | Written if narrowed |
| "Any methodology calibration to tune?" | `methodology_parameters.<name>` | No |

`_meta` is written by the command itself (not a question), stamped with the `/sdlc-start` event as `updated_by` and the current date as `last_updated`.

---

## Worked example — the data-estate product

`sdlc-config.json` for the running product (Data Estate Mapping and Compliance Intelligence). Per `sdlc-context.json → tech_stack`, no product-level tech-stack decisions have been overridden except the optional database (MongoDB), which `sdlc-context.json` explicitly calls out as "exposed as config option at `/sdlc-start`. Not default." The deployment model is narrowed from the two options named in `sdlc-context.json → first_product.deployment_model` to the one this pilot customer instance uses.

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

### Reading this config, field by field

Everything **not** listed — `primary_language`, `api_framework`, `primary_database`, `message_broker`, `graph_database`, `ci_cd`, `iac`, `service_mesh`, `container_orchestration`, `observability`, `frontend` — uses the CLAUDE.md default unchanged, and correctly does not appear in the file. When `backend-engineer` begins a service it resolves each fact independently against the two-tier order:

1. **API framework** — checks `tech_stack_overrides.api_framework`. Absent → falls back to `net/http` + chi.
2. **Optional database** — checks `tech_stack_overrides.optional_database`. Present, `included: true` → uses MongoDB for the entity-extraction and crawl-metadata bounded contexts per the rationale's stated scope; still uses PostgreSQL (the unoverridden default) everywhere else.
3. **Deployment model** — reads `deployment_model` when instrumenting anything tenant-isolation-sensitive, rather than assuming an option.

The `methodology_parameters` object is empty: this product tunes none of the factory-wide calibration points, so all five non-negotiable methodologies apply at their factory defaults.

---

## Validation checklist

Before treating a `sdlc-config.json` as valid, confirm:

- [ ] `_meta`, `product`, `product_slug` all present; no top-level field outside the permitted set.
- [ ] `product_slug` matches `^[a-z0-9]+(-[a-z0-9]+)*$`.
- [ ] Every `tech_stack_overrides` key actually differs from its CLAUDE.md default (no restated defaults).
- [ ] `optional_database`, if present, has all three of `included`, `value`, `rationale`.
- [ ] Every `compliance_frameworks` entry names its control families, not just the framework.
- [ ] `deployment_model`, if present, names a specific documented option.
- [ ] No `methodology_parameters` entry weakens whether a non-negotiable methodology applies — only tunes a value within one.
- [ ] `_meta.updated_by` points at a decision ID or event; `_meta.last_updated` is a real `YYYY-MM-DD` (assert `format: date` explicitly — see caveat).
- [ ] Validated against `schemas/sdlc-config.schema.json` with format assertion enabled.
