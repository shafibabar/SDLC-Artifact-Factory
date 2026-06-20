# Skill: core/artifact-manifest

## Purpose

Maintains `sdlc-manifest.json` for the current product run. Tracks phase state, artifact inventory, DoD gaps, warnings, and acknowledged risks. This is the authoritative record of what has been produced, what is missing, and what the user has accepted.

## Invocation

Invoked by:
- `/sdlc-start` — to initialise the manifest
- Every skill after producing an artifact — to register the artifact
- `/sdlc-status` — to read and summarise current state
- `/sdlc-next` — to run DoD check and advance phase on approval
- `/sdlc-review` — to surface all gaps and warnings for the current phase
- The `pre-phase-advance` hook — to enforce DoD before phase transition

---

## Manifest Location

```
{product-root}/sdlc-manifest.json
```

The product root is the directory created by `/sdlc-start`, named after `product_name` in `sdlc-config.json`.

---

## Actions

### Initialise
Called by `/sdlc-start` after the questionnaire is complete.

1. Create the product root directory: `{product_name}/`
2. Write `sdlc-config.json` with questionnaire answers (validated against `schemas/sdlc-config.schema.json`).
3. Create `sdlc-manifest.json` with:
   - `current_phase`: `"strategy"`
   - All phases set to `status: "not_started"` except strategy (`"in_progress"`)
   - `created_at` and `updated_at` set to current timestamp
4. Validate the manifest against `schemas/sdlc-manifest.schema.json` before writing.
5. Create the artifact directory structure (top-level directories only; subdirectories created on demand by skills).

### Register artifact
Called after every skill writes an artifact file.

1. Read the current manifest.
2. Add the artifact's relative path to `phases.{current_phase}.artifacts`.
3. Update `updated_at`.
4. Write the manifest back.

**Input:** artifact path (relative to product root)

### Check DoD
Called by `/sdlc-next` and the `pre-phase-advance` hook.

1. Read the current phase from the manifest.
2. Read the DoD checklist for that phase from `CLAUDE.md` under `## Phase Definitions of Done`.
3. Read `phases.{current_phase}.artifacts` from the manifest.
4. For each DoD item, determine whether the required artifact(s) exist and are non-empty.
5. Return:
   - `satisfied`: list of DoD items confirmed met
   - `gaps`: list of DoD items not yet met
   - `warnings`: active warnings not yet acknowledged
   - `pass`: true only if `gaps` is empty OR all gaps are in `acknowledged_risks`

**DoD item → artifact mapping is defined per phase in CLAUDE.md.**

### Advance phase
Called by `/sdlc-next` after DoD check passes (or gaps are acknowledged).

1. Set `phases.{current_phase}.status` to `"approved"` and record `approved_at`.
2. Determine the next phase (order: strategy → ideate → design → implement → data → quality → deploy → validate → complete).
3. Set `current_phase` to the next phase.
4. Set `phases.{next_phase}.status` to `"in_progress"` and record `started_at`.
5. Update `updated_at`.
6. Write manifest.
7. Confirm to the user: "Phase `{previous}` approved. Now in `{next}` phase."

### Record warning
Called by hooks (post-artifact-created, security-gate, compliance-gate) when a warning is raised.

1. Read the current manifest.
2. Append to `phases.{current_phase}.warnings`:
   ```json
   { "code": "...", "message": "...", "artifact": "...", "raised_at": "..." }
   ```
3. Update `updated_at`.
4. Write manifest.

### Record acknowledged risk
Called when the user explicitly acknowledges a DoD gap or warning before advancing.

1. Append to `phases.{current_phase}.acknowledged_risks`:
   ```json
   { "item": "...", "justification": "...", "acknowledged_at": "..." }
   ```
2. Write manifest.

### Status report
Called by `/sdlc-status`.

Produce a formatted summary:

```
═══════════════════════════════════════════
  SDLC Artifact Factory — Status Report
  Product: {product_name}
  Date:    {updated_at}
═══════════════════════════════════════════

Current Phase: {current_phase} ({status})

Phase Summary:
  ✓ strategy   — approved  ({artifact_count} artifacts)
  ✓ ideate     — approved  ({artifact_count} artifacts)
  ● design     — in_progress ({artifact_count} artifacts, {gap_count} DoD gaps)
  ○ implement  — not_started
  ○ data       — not_started
  ○ quality    — not_started
  ○ deploy     — not_started
  ○ validate   — not_started

Current Phase DoD Gaps:
  ✗ {gap_1}
  ✗ {gap_2}

Active Warnings:
  ⚠ [TERM_DRIFT] {artifact}: "{term}" is not defined in ubiquitous language
  ⚠ [TDD_MISSING] {feature}: no TDD spec found before code generation

Run /sdlc-review for full methodology compliance report.
Run /sdlc-next to advance (DoD check will run first).
═══════════════════════════════════════════
```

---

## Schema Validation

All reads and writes to `sdlc-manifest.json` are validated against `schemas/sdlc-manifest.schema.json`. A write that would produce an invalid manifest is rejected with an error describing the violation.

All reads and writes to `sdlc-config.json` are validated against `schemas/sdlc-config.schema.json`.
