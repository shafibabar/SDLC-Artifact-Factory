# Command: /sdlc-next

Advance the current product run to the next SDLC phase. Runs a DoD check on the current phase before advancing. Any DoD gaps are surfaced as advisory warnings and require explicit acknowledgment before the phase transition is permitted.

---

## Step 1: Locate the active product run

1. Look for `sdlc-manifest.json` in subdirectories of the current working directory.
2. If multiple manifests exist, ask: "Multiple product runs found. Which product do you want to advance? {list product names}"
3. If none found: "No active product run found. Run `/sdlc-start` to begin a new product run."
4. Read `sdlc-manifest.json` and `sdlc-config.json`.

---

## Step 2: Identify current phase

Read `current_phase` from the manifest.

If `current_phase` is `"complete"`:
> "This product run is already complete. All phases have been approved."
Stop.

---

## Step 3: Run DoD check (invoke core/artifact-manifest → check DoD)

1. Read the DoD checklist for the current phase from `CLAUDE.md` under `## Phase Definitions of Done`.
2. Read `phases.{current_phase}.artifacts` from the manifest.
3. For each DoD item, check whether the required artifact(s) exist and are non-empty.
4. Read `phases.{current_phase}.warnings` for any active unacknowledged warnings.
5. Read `phases.{current_phase}.acknowledged_risks` for items already accepted.

Produce the DoD report:

```
═══════════════════════════════════════════════
  DoD Check — {current_phase} phase
  Product: {product_name}
═══════════════════════════════════════════════

Satisfied (✓):
  ✓ {satisfied DoD item 1}
  ✓ {satisfied DoD item 2}

Gaps (✗):
  ✗ {gap 1 — e.g. North Star Metric artifact missing}
  ✗ {gap 2 — e.g. Stakeholder Map artifact missing}

Unacknowledged Warnings (⚠):
  ⚠ [TERM_DRIFT] strategy/vision.md: "active scan" is not defined in ubiquitous language
  ⚠ [TERM_DRIFT] strategy/gtm.md: "SaaS" is not defined in ubiquitous language

Previously Acknowledged Risks:
  ✓ {item acknowledged in a prior /sdlc-next call}

═══════════════════════════════════════════════
```

---

## Step 4: Handle gaps and warnings

**If there are NO gaps and NO unacknowledged warnings:**
Proceed directly to Step 5 (advance phase).

**If there are gaps or unacknowledged warnings:**

```
The following items must be resolved or acknowledged before advancing:

GAPS:
  1. {gap 1}
  2. {gap 2}

WARNINGS:
  3. {warning}

Options:
  (a) Close gaps — run the missing skills, then call /sdlc-next again
  (b) Acknowledge all — accept these risks and advance anyway
  (c) Acknowledge specific items — choose which to accept (enter numbers)
  (d) Cancel — stay in current phase

What would you like to do? (a/b/c/d)
```

**If user selects (b) or (c):**
- Ask for a justification: "Please provide a brief justification for accepting these risks:"
- For each acknowledged item, call core/artifact-manifest → record acknowledged risk with the justification and timestamp.
- After acknowledgment, re-run DoD check. If now clear (all gaps either satisfied or acknowledged), proceed to Step 5.

**If user selects (a):**
- List the skills needed to close the gaps:
  ```
  To close the gaps, run:
    /sdlc-artifact strategy/north-star-metric
    /sdlc-artifact strategy/stakeholder-map
  Then run /sdlc-next again.
  ```
- Stop.

**If user selects (d):**
- Stop.

---

## Step 5: Advance phase (invoke core/artifact-manifest → advance phase)

The phase order is: `strategy → ideate → design → implement → data → quality → deploy → validate → complete`

1. Set `phases.{current_phase}.status` to `"approved"`, record `approved_at` timestamp.
2. Determine next phase. Set `current_phase` to next phase.
3. Set `phases.{next_phase}.status` to `"in_progress"`, record `started_at` timestamp.
4. Write manifest.

---

## Step 6: Confirmation and orientation

```
═══════════════════════════════════════════════
  ✓ Phase Advanced
  Product: {product_name}
═══════════════════════════════════════════════

{previous_phase} phase → APPROVED ✓
{next_phase} phase → IN PROGRESS ●

{next_phase} phase artifacts to generate:
  {list the skills for the next phase from CLAUDE.md skill catalogue}

Suggested first steps:
  /sdlc-artifact {next_phase}/{first_skill}
  /sdlc-status    → to see the full {next_phase} DoD checklist
═══════════════════════════════════════════════
```

If advancing into the **Design** phase, add:
```
  ⚡ The Design phase begins with Event Storming.
     Run /sdlc-event-storm to start the domain modelling session.
```

If advancing into the **Implement** phase, add:
```
  ⚡ TDD is enforced in the Implement phase.
     TDD specs must exist before any code generation skills run.
     Start with: /sdlc-artifact implement/tdd-spec
```
