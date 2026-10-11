# Example 2 — A growing SaaS skill: references, templates, examples

Self-contained. Shows a **mid-sized** skill whose content earns three folders, plus the pointer sentences that make each one reachable.

## Input — the content inventory

A skill for designing a REST API contract in a multi-tenant SaaS product:

- when to use REST versus events versus gRPC (decision table, ≈30 lines);
- naming, versioning and error-shape rules (≈60 lines);
- the full OpenAPI 3.1 conventions document: pagination, idempotency keys, problem+json (≈250 lines);
- a fill-in contract summary document with frontmatter (≈60 lines);
- three worked contracts: a single-tenant CRUD resource, a tenant-scoped resource with row-level isolation, and a bulk import endpoint with idempotency and async status polling.

## Decision, content by content

| Content | Folder test | Result |
|---|---|---|
| Style decision table; naming/versioning/error rules | Decision-shaping, most invocations need it | Body |
| OpenAPI conventions (250 lines) | Prose you look up as needed | `references/` |
| Contract summary document | A file you copy and fill in | `templates/` |
| Three worked contracts | Input → output demonstrations, increasing in difficulty | `examples/`, one file each |

## Output — the layout and its pointers

```
skills/api-contract-design/
├── SKILL.md
├── references/openapi-conventions.md
├── templates/contract-summary.md
└── examples/
    ├── single-tenant-crud.md
    ├── tenant-scoped-resource.md
    └── bulk-import-idempotent.md
```

The body lines that make each file reachable, each stating **when**:

> To write the contract document, copy `./templates/contract-summary.md` and fill every field.
> For pagination, idempotency keys or the error body, read `./references/openapi-conventions.md`.
> If the resource belongs to a tenant, follow `./examples/tenant-scoped-resource.md`; for a bulk or long-running operation, `./examples/bulk-import-idempotent.md`.

`lint-skill-layout` passes: every file is reachable and every pointer is relative.
