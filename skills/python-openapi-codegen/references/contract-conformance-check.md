# Contract Conformance Check

Full standard referenced from `SKILL.md`'s "The Process Fix" (step 4) — the CI step that diffs
FastAPI's derived schema against the approved, hand-authored contract (`api/openapi.yaml`, owned by
`api-contract-design`) and **fails the build on drift**. This is the mechanical discipline that
buys Python back the contract-first guarantee Go gets for free from its compiler + `go generate` +
`git diff --exit-code` freshness gate. Self-contained — usable without the parent `SKILL.md` body.

---

## Why a CI Step Is Load-Bearing Here, Not Optional

In Go, a handler that disagrees with the contract does not compile — the disagreement cannot reach
`main`. FastAPI derives the schema *from* the code, so the code and its derived schema are trivially
in agreement with each other; what can silently diverge is the **derived schema versus the approved
contract**. Nothing in the Python toolchain notices that divergence on its own. The conformance
check is therefore the *only* enforcement point. Remove it and "contract-first" is an unenforced
aspiration: the first engineer who renames a Pydantic field ships a contract change to every
consumer with a green build.

## The Two Inputs

1. **The approved contract** — `api/openapi.yaml`, authored and reviewed under
   `api-contract-design`, committed, the source of truth.
2. **The derived schema** — `openapi.gen.json`, produced by `scripts/export-openapi.py`
   (`fastapi-schema-generation.md`), a build artifact regenerated on every CI run and never
   committed as authoritative.

The check compares (2) against (1) and fails on any change that alters the contract's meaning.

## Tooling: `oasdiff`

Use **`oasdiff`** (`github.com/oasdiff/oasdiff`) — an open-source OpenAPI diff tool that classifies
changes and, critically, distinguishes **breaking** from **non-breaking** changes against the
additive-vs-breaking rules `api-contract-design` already defines. It reads YAML or JSON on either
side, so `api/openapi.yaml` (authored) diffs directly against `openapi.gen.json` (derived) with no
format conversion. It is a single static binary — no paid service, honouring the frugality
constraint, the same "no broker, no SaaS" posture `go-contract-test` takes.

```bash
# Breaking-change gate: exit non-zero if the derived schema breaks the approved contract.
oasdiff breaking api/openapi.yaml openapi.gen.json --fail-on ERR
```

`oasdiff breaking` reports removed endpoints, removed/renamed required fields, narrowed types,
tightened constraints, changed status codes, and removed enum values as `ERR`; `--fail-on ERR`
turns any of them into a non-zero exit that fails the pipeline. Additive changes (a new optional
field, a new endpoint) are reported as `INFO`/`WARN` and do not fail — matching
`api-contract-design`'s "additive = no version bump" rule.

For an *exact*-match posture (the derived schema must equal the approved contract with zero drift of
any kind, additive included), use the full changelog and fail on any entry:

```bash
# Zero-drift gate: any difference at all — additive or breaking — fails the build.
CHANGES=$(oasdiff changelog api/openapi.yaml openapi.gen.json)
if [ -n "$CHANGES" ]; then
  echo "FAIL: derived schema drifted from the approved contract:"
  echo "$CHANGES"
  exit 1
fi
```

## The CI Script

```bash
#!/usr/bin/env bash
# scripts/check-openapi.sh — CI conformance gate. Fails the build on contract drift.
set -euo pipefail

CONTRACT="api/openapi.yaml"          # authored source of truth (api-contract-design)
DERIVED="openapi.gen.json"           # build artifact

# 1. Regenerate the derived schema from the live app (never trust a stale checked-in copy).
python scripts/export-openapi.py > "$DERIVED"

# 2. The derived schema must itself be a valid OpenAPI 3.1 document.
openapi-spec-validator "$DERIVED"

# 3. Fail the build if the code's derived schema breaks the approved contract.
if ! oasdiff breaking "$CONTRACT" "$DERIVED" --fail-on ERR; then
  echo "FAIL: the implementation breaks the approved API contract ($CONTRACT)."
  echo "Fix the CODE to match the contract, or take the contract change through"
  echo "api-contract-design re-approval FIRST — never edit $CONTRACT to match the code."
  exit 1
fi

echo "PASS: derived schema conforms to the approved contract."
```

- **Step 1** regenerates from the running app so the gate can never pass on a stale artifact — the
  direct analog of Go's `go generate ./...` before `git diff --exit-code`.
- **Step 2** uses `openapi-spec-validator` (a real, open-source Python OpenAPI validator) to catch a
  derived document that is malformed independently of whether it matches the contract.
- **Step 3** is the conformance gate proper.

## Wiring Into the Pipeline

This is a GitHub Actions job (the repo CI/CD default), gating the same PR as the tests. It runs
alongside — not instead of — `mypy`/`pyright` (the static-type gate) and `schemathesis`
(`python-contract-test`, which property-tests the live app *against* the same OpenAPI schema).

```yaml
# .github/workflows/api-conformance.yml (excerpt)
- name: OpenAPI contract conformance
  run: bash scripts/check-openapi.sh
```

## The Non-Negotiable Direction of the Fix

When the gate fails, the contract is right and the code is wrong **by default**:

- **The code changes** to satisfy `api/openapi.yaml`. This is the common case and the whole point.
- If the *contract* is genuinely wrong, the fix goes upstream: change `api/openapi.yaml` through
  `api-contract-design`, get it re-reviewed and re-approved, *then* update the code. The contract is
  never quietly edited in the same PR to make a red gate green — that is precisely the inversion
  (code drives contract) this entire skill exists to prevent.

## Interaction With Versioning

`oasdiff breaking` classifies additive vs. breaking, but it does **not** decide the versioning
*policy* — that is `api-contract-design`'s. A breaking diff means one of two things: either the code
drifted and must be pulled back to the frozen `/v1/` contract, or a deliberate `/v2/` was authored
first and the check should run against `api/openapi-v2.yaml`. The gate enforces conformance to
*whichever contract is approved*; it never authorises a breaking change by itself.
