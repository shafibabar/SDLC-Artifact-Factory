---
name: artifact-manifest
description: >
  Defines the canonical registry of every artifact type this plugin can produce
  — the master catalog hooks use to validate that an artifact type exists, the
  right agent produced it, and its path is correct — and the per-product
  manifest instance that tracks every artifact actually produced for a given
  product, with full traceability back to the requirement, decision, or event
  that caused it to exist. Consulted by the post-artifact-created hook, the
  generate-artifact-id tool, and any agent checking whether an artifact
  already exists before producing a new one. The full master catalog lives in
  references/artifact-type-catalog.md; a populated worked example lives in
  references/manifest-worked-example.md; a copyable empty starting shape for
  a new product's manifest lives in assets/manifest-instance-template.json.
version: 2.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, artifact-manifest, traceability, registry, cross-cutting]
---

# Artifact Manifest

## Purpose

Every artifact this plugin produces must be discoverable, uniquely identified, versioned, and traceable to why it exists. Without a manifest, artifacts are just files scattered across `artifacts/[product]/` — nothing can answer "does this artifact type exist," "did the right agent produce this," "what requirement caused this artifact to exist," or "is this artifact still current." This skill defines two related but distinct registries that answer those questions.

## Two Registries: Type Catalog vs. Product Manifest

These serve different purposes and must not be conflated.

| | **Artifact-Type Catalog** | **Product Manifest** |
|---|---|---|
| What it lists | Every artifact *type* the plugin can produce (a fixed, plugin-level schema) | Every artifact *instance* actually produced for one product |
| Scope | Plugin-wide, product-agnostic | One per product, at `artifacts/[product]/_manifest.json` |
| Changes when | A new skill is added, a component is restructured (rare) | Every time an artifact is created, updated, or superseded (constant) |
| Consumed by | Hooks validating "is this a real artifact type," agents checking where to write output | The `post-artifact-created` hook, `pre-phase-advance` (checking required artifacts exist), Shafi reviewing product state |
| Lives in | `references/artifact-type-catalog.md`, as a worked table | The product's own artifact tree |

The type catalog is the schema. The product manifest is the data. The full catalog table — one row per artifact type, covering every phase — is reference material consulted when an agent needs to look up a specific type's producing agent, path pattern, or required frontmatter; see `references/artifact-type-catalog.md`.

## Artifact ID Scheme

Every artifact instance in a product manifest gets a stable, human-readable ID:

```
<product-slug>-<artifact-type>-<sequence>
```

- **`product-slug`** — the product's short slug, set once at `/sdlc-start` (e.g. `dataestate`).
- **`artifact-type`** — the kebab-case artifact type name from the catalog (e.g. `adr`, `user-story`, `go-service`).
- **`sequence`** — a three-digit, zero-padded counter, scoped to `<product-slug>-<artifact-type>` and monotonically increasing. Never reused, even if the artifact is later deleted or superseded.

Examples: `dataestate-adr-001`, `dataestate-user-story-014`, `dataestate-go-service-003`.

IDs are assigned once, at creation, and never change — even across a rename, a path move, or a status change to `superseded`. The ID is the artifact's permanent handle; the `path` field in the manifest is what moves.

A future `generate-artifact-id` tool (see `sdlc-context.json → tools.planned`) mechanizes this scheme: given a product slug and artifact type, it reads the current manifest, finds the highest existing sequence for that type, and returns the next ID. Until that tool exists, the producing agent computes the next sequence by reading the manifest directly.

Artifact types that produce source trees rather than a single Markdown file (Go services, React components, Helm charts) still get one manifest entry per meaningful unit — see `references/manifest-worked-example.md` for how a directory-shaped artifact gets a stable ID.

## The Per-Product Manifest Instance

Every product has exactly one manifest, at `artifacts/[product]/_manifest.json`. It is the registry of every artifact actually produced for that product — not the catalog of what could be produced (`references/artifact-type-catalog.md`), but a record of what was. A copyable empty starting shape lives at `assets/manifest-instance-template.json`; a fully populated, illustrative instance lives at `references/manifest-worked-example.md`.

Each entry tracks:

| Field | Meaning |
|---|---|
| `id` | Stable ID per the scheme above |
| `type` | Artifact type, matching a row in the master catalog |
| `path` | Current file (or directory) path, relative to repo root |
| `version` | The artifact's own `version` frontmatter field (or, for source trees, the version of its design doc) |
| `status` | `draft` \| `approved` \| `superseded` |
| `phase` | The SDLC phase the artifact belongs to |
| `producing_agent` | Which agent produced it |
| `traces_to` | The requirement, decision, or event that caused this artifact to exist (see Traceability below) |
| `created` | ISO date the artifact was first produced |
| `updated` | ISO date of the most recent revision |

### Traceability

CLAUDE.md's Artifact Standards require every artifact be traceable — it must reference the requirement, event, or decision that caused it to exist. In the manifest, this is the `traces_to` field:

```json
"traces_to": { "kind": "requirement", "ref": "dataestate-user-story-014" }
"traces_to": { "kind": "decision",    "ref": "D009" }
"traces_to": { "kind": "domain-event", "ref": "SensitivityLevelChanged" }
```

An artifact with no `traces_to` value is an orphan — see Anti-Patterns.

### Status Lifecycle

`draft` → `approved` → (optionally) `superseded`. A `superseded` entry is never deleted from the manifest — it stays, with its `status` updated and, where applicable, a `superseded_by` field pointing at the ID that replaced it. This mirrors the ADR rule in `adr-authoring`: the record of what existed before is part of the traceability chain, not clutter to be removed.

## Connection to `sdlc-context.json` and the `post-artifact-created` Hook

`sdlc-context.json` is the factory's own memory — build position, decisions, phase checklist. The product manifest is the same idea applied per-artifact, per-product: instead of one JSON file tracking the plugin's own build, each product gets one JSON file tracking every artifact that product's SDLC run has produced.

Once the `post-artifact-created` hook is built, its job is exactly this: whenever an agent writes an artifact file, the hook appends (or updates) the corresponding entry in `artifacts/[product]/_manifest.json`, assigns the ID via `generate-artifact-id` if one was not already assigned, and stamps `created`/`updated`. This is analogous to how `sdlc-context.json`'s own `_meta.last_updated` and `_meta.updated_by` fields are maintained by hand today and will be governed the same way once the hook exists.

The manifest schema is formalized machine-readably as `schemas/sdlc-manifest.schema.json` (see `settings.json → env.SDLC_MANIFEST_SCHEMA`) — it validates the per-product manifest INSTANCE (the JSON shape in `references/manifest-worked-example.md` and `assets/manifest-instance-template.json`); the master artifact-type catalog stays a prose table in `references/artifact-type-catalog.md`, since it is described as extended by new skills over time and `type` is deliberately not a closed enum in the schema.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Every artifact registered | Every file under `artifacts/[product]/` has a corresponding manifest entry | Files exist on disk with no manifest entry (untracked artifact) |
| IDs are unique and stable | No two entries share an ID; an artifact's ID never changes across revisions | ID collision, or an ID reassigned after a rename |
| Traceability populated | Every entry has a non-empty `traces_to` | Entries with no requirement/decision/event reference (orphaned manifest entry) |
| Status accurate | `status` reflects the artifact's actual review state | An artifact marked `approved` that Shafi has not reviewed |
| Manifest matches filesystem | Every `path` in the manifest resolves to a real file; no manifest entry for a deleted file without `status: superseded` | Manifest drift — entries pointing at files that no longer exist, with no supersession recorded |
| Type catalog conformance | Every entry's `type` matches a row in `references/artifact-type-catalog.md`, and its `path` matches that type's path pattern | An artifact type not represented in the catalog, or a path that deviates from the pattern without a documented reason |

## Anti-Patterns

- **Untracked artifacts** — an agent writes a file to `artifacts/[product]/` without a corresponding manifest entry. The artifact becomes invisible to `pre-phase-advance` and to Shafi's review of "what exists so far."
- **Colliding IDs** — two artifacts assigned the same ID because the sequence counter was read stale (e.g. two agents producing artifacts of the same type concurrently without re-reading the manifest first). IDs must be assigned atomically against the current manifest state.
- **Orphaned manifest entries** — a file is deleted from disk but its manifest entry is left in place with `status: approved`, so the manifest lies about what currently exists. Deletion must either supersede the entry (if replaced) or explicitly remove it (if it was created in error and never approved).
- **Manifest drift** — the manifest is updated by hand occasionally instead of on every artifact write, so it silently falls out of sync with the filesystem. This is why the manifest update is a hook responsibility, not a manual step an agent might skip.
- **Traceability theater** — populating `traces_to` with a vague or generic reference ("requirements") instead of a real ID. A `traces_to` entry must resolve to an actual requirement, decision, or event.
- **Type catalog sprawl** — inventing a new artifact type in the manifest without adding a corresponding row to `references/artifact-type-catalog.md` first. Every type in use must be catalogued; the catalog is the schema, not an afterthought.

## Output Format

This skill's output is a machine-readable JSON file consumed by hooks and commands, not a Markdown artifact — the usual `name`/`version`/`phase`/`owner`/`created` frontmatter does not apply to it. The product manifest follows `sdlc-context.json`'s own `_meta` convention for versioning and tracking metadata within the JSON itself, with top-level `product`, `product_slug`, and an `artifacts` array of entries shaped per the Per-Product Manifest Instance table above.

- **Starting a new product's manifest** — copy `assets/manifest-instance-template.json` as-is.
- **Seeing the shape fully populated** — read `references/manifest-worked-example.md`.
- **Looking up an artifact type's producing agent, skill, path pattern, or required frontmatter** — read `references/artifact-type-catalog.md`.
