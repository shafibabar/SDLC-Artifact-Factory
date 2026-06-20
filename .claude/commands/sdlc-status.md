# Command: /sdlc-status

Display a full status dashboard for the current product run: phase state, artifacts produced, DoD gaps, active warnings, and suggested next actions. This command is read-only — it never modifies the manifest.

---

## Step 1: Locate the active product run

1. Search for `sdlc-manifest.json` in subdirectories of the current working directory.
2. If multiple exist, ask: "Multiple product runs found: {list}. Which would you like to check?"
3. If none: "No product run found. Run `/sdlc-start` to initialise a new product run."
4. Read `sdlc-manifest.json` and `sdlc-config.json`.

---

## Step 2: Run DoD check for current phase

Invoke core/artifact-manifest → check DoD for the current phase. Collect:
- Satisfied DoD items
- Gaps
- Active unacknowledged warnings
- Acknowledged risks

---

## Step 3: Render the status dashboard

```
═══════════════════════════════════════════════════════════════
  SDLC Artifact Factory — Status Dashboard
  Product:  {product_name}
  Updated:  {manifest.updated_at}
═══════════════════════════════════════════════════════════════

  Problem:
  "{problem_statement — truncated to 120 characters if longer}"

  Config: language={target_language} | compliance={frameworks} |
          tenancy={tenancy_model} | cloud={cloud_providers}

───────────────────────────────────────────────────────────────
  PHASE OVERVIEW
───────────────────────────────────────────────────────────────

  ✓ strategy    APPROVED    {artifact_count} artifacts  {approved_at date}
  ● ideate      IN PROGRESS {artifact_count} artifacts  {started_at date}
  ○ design      not started
  ○ implement   not started
  ○ data        not started
  ○ quality     not started
  ○ deploy      not started
  ○ validate    not started

───────────────────────────────────────────────────────────────
  CURRENT PHASE: {current_phase} — DoD Status
───────────────────────────────────────────────────────────────

  Satisfied:
    ✓ {DoD item 1}
    ✓ {DoD item 2}

  Gaps (must resolve or acknowledge before /sdlc-next):
    ✗ {DoD gap 1}
    ✗ {DoD gap 2}

───────────────────────────────────────────────────────────────
  ACTIVE WARNINGS
───────────────────────────────────────────────────────────────

  ⚠ [TERM_DRIFT]  {artifact path}: "{term}" is not defined in ubiquitous language
  ⚠ [TDD_MISSING] {feature}: no TDD spec exists — create before generating code

  (No warnings → "✓ No active warnings")

───────────────────────────────────────────────────────────────
  ARTIFACTS PRODUCED — {current_phase} phase
───────────────────────────────────────────────────────────────

  {artifact path 1}
  {artifact path 2}
  {artifact path 3}

───────────────────────────────────────────────────────────────
  SUGGESTED NEXT ACTIONS
───────────────────────────────────────────────────────────────

  {If gaps exist:}
  To close DoD gaps, run:
    /sdlc-artifact {skill/name}    → {artifact description}
    /sdlc-artifact {skill/name}    → {artifact description}

  {If no gaps:}
  ✓ {current_phase} DoD is satisfied. Ready to advance.
    /sdlc-next                    → Advance to {next_phase} phase

  Always available:
    /sdlc-review                  → Full methodology compliance review
    /sdlc-glossary [term]         → Look up or validate a glossary term
    /sdlc-artifact [skill/name]   → Generate any artifact for the current phase

═══════════════════════════════════════════════════════════════
```

---

## Optional: Verbose mode

If the user runs `/sdlc-status --verbose` or `/sdlc-status -v`, also include:

```
───────────────────────────────────────────────────────────────
  ALL PHASES — ARTIFACT INVENTORY
───────────────────────────────────────────────────────────────

  STRATEGY (approved {date})
    ✓ artifacts/strategy/vision.md
    ✓ artifacts/strategy/north-star.md
    ✓ artifacts/strategy/okrs.md
    ...

  IDEATE (in progress since {date})
    ✓ artifacts/ideate/requirements/functional.md
    ✗ artifacts/ideate/requirements/nfrs.md        [MISSING]
    ...

───────────────────────────────────────────────────────────────
  ACKNOWLEDGED RISKS
───────────────────────────────────────────────────────────────

  {current_phase}:
  • {item acknowledged} — "{justification}" — {acknowledged_at}
```
