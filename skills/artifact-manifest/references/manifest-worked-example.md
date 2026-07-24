# Manifest Worked Example

A full, populated `_manifest.json` instance for the running product (Data Estate Mapping and Compliance Intelligence), illustrating the shape `SKILL.md`'s Per-Product Manifest Instance section describes. This file is illustrative and populated — distinct from `assets/manifest-instance-template.json`, which is the empty skeletal shape a command copies in when initializing a new product's manifest.

Four entries are shown, each illustrating a different state or artifact shape:

1. An **approved ADR** — the common case: a single Markdown artifact, reviewed and current.
2. A **superseded user story** — showing the `superseded_by` field and the Status Lifecycle rule that a superseded entry is never deleted.
3. A **draft artifact awaiting review** — showing that `status: draft` entries are registered the moment they're written, not held back until Shafi approves them; the manifest tracks what exists, not only what's finished.
4. A **Go Service** — a directory-shaped artifact (source tree, not a single file), illustrating the Artifact ID Scheme's "one manifest entry per meaningful unit" rule from `SKILL.md`: the entry's `path` points at the service's root directory, and its `version` tracks the service's own design doc version rather than any individual source file's state.

## Worked Example

```json
{
  "_meta": {
    "purpose": "Registry of every artifact produced for this product. Read before producing a new artifact to check whether it already exists; updated by the post-artifact-created hook on every artifact write.",
    "how_to_use": "1. Look up an artifact by id or type before creating a new one. 2. Check status before treating an entry as current — superseded entries are historical only. 3. Follow traces_to to find the requirement, decision, or event behind any artifact.",
    "last_updated": "2026-07-24",
    "updated_by": "post-artifact-created hook"
  },
  "product": "Data Estate Mapping and Compliance Intelligence",
  "product_slug": "dataestate",
  "artifacts": [
    {
      "id": "dataestate-adr-001",
      "type": "adr",
      "path": "artifacts/dataestate/design/decisions/ADR-001-transactional-outbox.md",
      "version": "1.0.0",
      "status": "approved",
      "phase": "design",
      "producing_agent": "enterprise-architect",
      "traces_to": { "kind": "decision", "ref": "D009" },
      "created": "2026-07-21",
      "updated": "2026-07-21"
    },
    {
      "id": "dataestate-user-story-014",
      "type": "user-story",
      "path": "artifacts/dataestate/ideate/stories/dataestate-user-story-014.md",
      "version": "1.1.0",
      "status": "superseded",
      "superseded_by": "dataestate-user-story-014-r2",
      "phase": "ideate",
      "producing_agent": "requirements-analyst",
      "traces_to": { "kind": "requirement", "ref": "dataestate-epic-002" },
      "created": "2026-07-15",
      "updated": "2026-07-22"
    },
    {
      "id": "dataestate-risk-register-entry-003",
      "type": "risk-register-entry",
      "path": "artifacts/dataestate/governance/risk-register.md",
      "version": "0.1.0",
      "status": "draft",
      "phase": "cross-cutting",
      "producing_agent": "security-architect",
      "traces_to": { "kind": "domain-event", "ref": "SensitivityLevelChanged" },
      "created": "2026-07-23",
      "updated": "2026-07-23"
    },
    {
      "id": "dataestate-go-service-003",
      "type": "go-service",
      "path": "artifacts/dataestate/implement/services/entity-extraction/",
      "version": "1.2.0",
      "status": "approved",
      "phase": "implement",
      "producing_agent": "backend-engineer",
      "traces_to": { "kind": "requirement", "ref": "dataestate-epic-004" },
      "created": "2026-07-10",
      "updated": "2026-07-19"
    }
  ]
}
```

The `dataestate-go-service-003` entry's `version` (`1.2.0`) tracks the service's own design doc — not any individual `.go` source file's git history — matching the parenthetical in `references/artifact-type-catalog.md`'s Go Service row ("source tree; design doc uses standard frontmatter"). If a future service has no single design doc to version against, a service-level `VERSION` file fills the same role.
