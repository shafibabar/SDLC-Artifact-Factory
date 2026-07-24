# Master Artifact-Type Catalog

One row per artifact type this plugin can produce: Artifact Type, Producing Agent, Skill Used, File Path Pattern, Phase, and Required Frontmatter Fields. This is a representative cross-section across phases, not an exhaustive list of the ~130 skills — it exists to demonstrate the pattern. Every skill in `skills/*/` that produces a distinct output artifact has a row of this shape; the full catalog is maintained by extension as new skills are added.

## The Catalog

| Artifact Type | Producing Agent | Skill Used | File Path Pattern | Phase | Required Frontmatter Fields |
|---|---|---|---|---|---|
| Vision Statement | product-strategist | `strategy/vision-statement` | `artifacts/[product]/strategy/vision-statement.md` | strategy | name, version, phase, owner, created |
| Roadmap | product-strategist | `strategy/roadmap-authoring` | `artifacts/[product]/strategy/roadmap.md` | strategy | name, version, phase, owner, created |
| OKR Set | product-strategist | `strategy/okr-authoring` | `artifacts/[product]/strategy/okrs/[cycle].md` | strategy | name, version, phase, owner, created |
| User Story | requirements-analyst | `discovery/user-story-writing` | `artifacts/[product]/ideate/stories/[story-id].md` | ideate | name, version, phase, owner, created |
| Epic | requirements-analyst | `discovery/epic-definition` | `artifacts/[product]/ideate/epics/[epic-id].md` | ideate | name, version, phase, owner, created |
| Acceptance Criteria | requirements-analyst | `discovery/acceptance-criteria` | `artifacts/[product]/ideate/stories/[story-id]-ac.md` | ideate | name, version, phase, owner, created |
| Event Storm Board | domain-modeler | `domain-modeling/event-storming-facilitation` | `artifacts/[product]/design/event-storms/[domain].md` | design | name, version, phase, owner, created |
| Bounded Context Map | domain-modeler | `domain-modeling/bounded-context-mapping` | `artifacts/[product]/design/context-map.md` | design | name, version, phase, owner, created |
| ADR | enterprise-architect | `architecture/adr-authoring` | `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md` | design | adr-id, title, status, date, deciders |
| API Contract | enterprise-architect | `architecture/api-contract-design` | `artifacts/[product]/design/api/[service].openapi.yaml` | design | (OpenAPI `info` block; no SKILL.md frontmatter — see api-contract-design) |
| Event Schema | data-architect | `data-architecture/event-schema-design` | `artifacts/[product]/data/schemas/[event-name].json` | data | (JSON Schema envelope; see event-schema-design) |
| Data Model | data-architect | `data-architecture/data-model-design` | `artifacts/[product]/data/data-model.md` | data | name, version, phase, owner, created |
| Go Service | backend-engineer | `backend-engineering/go-service-skeleton` + related | `artifacts/[product]/implement/services/[service]/` | implement | (source tree; design doc uses standard frontmatter) |
| BDD Feature File | test-strategist | `test-engineering/bdd-feature-file` | `artifacts/[product]/implement/features/[story-id].feature` | implement | (Gherkin; traceability tag references story-id) |
| React Component | frontend-engineer | `frontend-engineering/react-component-design` + related | `artifacts/[product]/implement/web/src/components/[Name]/` | implement | (source tree; design doc uses standard frontmatter) |
| Test Strategy | test-strategist | `test-engineering/test-pyramid` | `artifacts/[product]/quality/test-strategy.md` | quality | name, version, phase, owner, created |
| Helm Chart | platform-engineer | `platform/helm-chart` | `artifacts/[product]/deploy/charts/[service]/` | deploy | (chart tree; `Chart.yaml` carries chart-level metadata) |
| Runbook | platform-engineer | `platform/runbook-authoring` | `artifacts/[product]/deploy/runbooks/[scenario].md` | deploy | name, version, phase, owner, created |
| UAT Plan | requirements-analyst | `validation/uat-plan` | `artifacts/[product]/validate/uat-plan.md` | customer-validation | name, version, phase, owner, created |
| Risk Register Entry | any agent | `governance/risk-register` | `artifacts/[product]/governance/risk-register.md` | cross-cutting | name, version, phase, owner, created |
| Methodology Review Report | any agent, hooks | `governance/methodology-review` | `artifacts/[product]/governance/reviews/[artifact]-review.md` | cross-cutting | name, version, phase, owner, created, reviewed_artifact, result |

## Directory-Shaped Artifact Types

Three rows above (Go Service, React Component, Helm Chart) produce source trees rather than a single Markdown file. These still get exactly one manifest entry per meaningful unit — one service, one component, one chart — not one entry per file inside the tree. `references/manifest-worked-example.md` includes a worked Go Service entry showing this in practice: the entry's `path` points at the service's root directory, and its `version` tracks the service's own design doc version (or a service-level `VERSION` file, if the service has no single design doc) rather than any individual source file's state.
