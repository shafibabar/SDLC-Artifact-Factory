---
name: python-openapi-codegen
description: >
  Teaches the backend-engineer FastAPI OpenAPI generation — FastAPI
  auto-generates the OpenAPI schema FROM Pydantic models and route decorators
  (code-first, the reverse of Go spec-first oapi-codegen), and the explicit
  process decision this forces: author the contract first and treat the
  generated schema as a conformance check, so the OpenAPI contract stays the
  source of truth (per api-contract-design). The Python analog of
  go-openapi-codegen.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, fastapi, pydantic, openapi, code-first, contract-first, conformance, starlette]
related: [go-openapi-codegen, python-fastapi-handler, api-contract-design]
tools: [Bash]
---

# Python OpenAPI Codegen

## Purpose

The API contract is designed and approved before the code (contract-first — `api-contract-design`).
The OpenAPI 3.1 document is the single source of truth for routes, request/response shapes, and
error envelopes. In Go that truth is *enforced* by generating code from the spec: a handler that
does not match the contract fails to compile (`go-openapi-codegen`). **FastAPI works in the exact
opposite direction, and that reversal is the whole point of this skill.**

---

## The Direction Reversal — Read This First

FastAPI does not consume an OpenAPI document to emit server code. It **derives** the OpenAPI schema
*from* the running application — from the Pydantic request/response models, the type hints on each
`async def` route handler, and the `@app.get/post(...)` decorator metadata (path, status code,
tags, responses). `app.openapi()` returns that schema as a dict; `/openapi.json` serves it; Swagger
UI at `/docs` renders it. Nothing is code-generated *into* the repo.

```
Go   (go-openapi-codegen):   api/openapi.yaml  ──oapi-codegen──▶  generated Go types + interface
Python (this skill):         Pydantic models + route decorators  ──FastAPI──▶  generated openapi.json
```

This is a **genuine reversal**, not a looser flavour of the same thing, and it must be named
plainly rather than papered over. It is the same code-first-to-spec direction Node's
Fastify + `@fastify/swagger` takes. The claim "the contract is the single source of truth" still
holds — but *which artifact is generated from which flips*, and that flip creates a risk Go does not
have.

---

## The Risk: The Schema Becomes an Accidental First Draft of the Contract

Because the schema falls out of whatever models the engineer happens to write, the path of least
resistance is: write handlers, let FastAPI emit a schema, publish that schema, and call it "the
contract." Now the contract is a *downstream artifact of the implementation* — the precise
inversion `api-contract-design` forbids. There is no compiler forcing agreement with an authored
contract, so drift is silent: rename a Pydantic field, add an optional query param, change a status
code, and the "contract" changes underneath every consumer with nothing failing. In Go a contract
mismatch is a build break; in FastAPI, left unmanaged, it is invisible.

---

## The Process Fix: Author First, Conformance-Check in CI

The contract is still authored and approved first, by hand, under `api-contract-design`, and lives
at `api/openapi.yaml` as the reviewed source of truth. FastAPI's generated schema is then treated
as a **conformance check, never as the contract itself**:

1. **Author** `api/openapi.yaml` first (resource design, versioning policy, Field Mask /
   Long-Running Operation / Resource Revision patterns) — all owned by `api-contract-design`, not
   restated here.
2. **Implement** Pydantic models and routes to satisfy that contract. Pin metadata that FastAPI
   would otherwise auto-invent (operation ids, tags, examples, response models per status) so the
   emitted schema *can* match — see `references/fastapi-schema-generation.md`.
3. **Export** the generated schema deterministically (`app.openapi()` → `openapi.gen.json`) as a
   build step.
4. **Diff** the generated schema against the approved `api/openapi.yaml` in CI and **fail the build
   on drift** — the mechanical discipline that restores contract-first parity with Go's
   `go generate` + `git diff --exit-code` freshness gate. Full CI step, the diff tool, and what
   counts as breaking-vs-additive drift: `references/contract-conformance-check.md`.

The generated schema is a *witness that the code obeys the contract* — not the contract. When they
disagree, the code changes to match the approved contract, never the reverse (a wrong contract is
fixed upstream in `api/openapi.yaml`, then re-approved).

---

## Type-Mapping Direction (Pydantic → OpenAPI)

Where Go maps OpenAPI *into* Go types, here the mapping runs Pydantic *out to* OpenAPI. `str` →
`string`, `uuid.UUID` → `string`/`format: uuid`, `datetime` → `string`/`format: date-time`,
`Optional[T]` / `T | None` → `nullable`, `Enum` subclass → `enum`, a nested `BaseModel` → a
`$ref` component. The three `api-contract-design` patterns need deliberate modelling so the emitted
schema matches the authored one — e.g. Field Mask's omitted-vs-explicit-null distinction requires
`model_config = ConfigDict(...)` plus `exclude_unset`, since a bare `Optional[T]` collapses both to
`None` (the same trap `go-openapi-codegen` calls out for `*T`). Full mapping table and the Field
Mask modelling: `references/fastapi-schema-generation.md`.

---

## Honest Python-vs-Go Divergences

- **Direction is reversed** (above) — the defining difference; the whole skill exists to manage it.
- **No compiler enforces the contract.** Go's build breaks on mismatch; Python's does not. The CI
  conformance diff is not an optional nicety here — it is the *only* thing standing in for the Go
  compiler, and without it there is no contract-first guarantee at all.
- **Type hints are runtime-erased.** FastAPI/Pydantic validate only the request/response
  *boundary*. Internal domain type hints are unchecked unless `mypy` (or `pyright`) runs as a
  mandatory CI gate — an independent gap, but one that compounds the above (`python-project-structure`).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Contract authored first | `api/openapi.yaml` reviewed/approved before models exist | Schema emitted from code, then published as "the contract" |
| Schema is a check, not the source | Generated `openapi.gen.json` diffed against the approved contract in CI | Generated schema committed *as* the contract |
| Drift fails the build | CI conformance step fails on any breaking diff | Drift merges silently; consumers discover it at runtime |
| Stable operation ids | Pinned so ids match the contract | FastAPI's auto-derived `funcname_path` ids leak into the published schema |
| Field Mask fidelity | omitted / explicit-null / value all distinguishable (`exclude_unset`) | Bare `Optional[T]` collapses omitted and null to one `None` |
| Code fixed to match contract | On disagreement, the code changes | The approved `api/openapi.yaml` quietly edited to match the code |

---

## Anti-Patterns

- **Publishing FastAPI's auto-emitted schema as the contract** — makes the contract a downstream
  artifact of the code, the exact inversion `api-contract-design` forbids.
- **No CI conformance diff** — without it there is *nothing* enforcing the contract in Python; drift
  is silent all the way to the consumer.
- **Editing `api/openapi.yaml` to match the code** — fixes the symptom by corrupting the source of
  truth; the contract change must go through re-approval upstream.
- **Letting FastAPI auto-name operation ids** — the derived ids are unstable and ugly, guaranteeing
  a perpetual, meaningless diff against a hand-authored contract.
- **Treating the generated schema as authoritative for versioning** — additive-vs-breaking
  classification is `api-contract-design`'s call on the *authored* contract, not a property read off
  the emitted schema.

---

## Output Format

```
api/openapi.yaml            (AUTHORED contract — source of truth; owned by api-contract-design)
app/api/models.py           (Pydantic request/response models — the schema is derived from these)
app/api/routes.py           (FastAPI route decorators; pinned operation ids, tags, responses)
app/main.py                 (FastAPI app; unique-id function wired — references/fastapi-schema-generation.md)
scripts/export-openapi.py   (dumps app.openapi() → openapi.gen.json — references/fastapi-schema-generation.md)
scripts/check-openapi.sh    (CI: diff openapi.gen.json vs api/openapi.yaml, fail on drift — references/contract-conformance-check.md)
```
