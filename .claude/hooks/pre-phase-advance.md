# Hook: pre-phase-advance

## Trigger
Fires when the user runs `/sdlc-next` to advance to the next SDLC phase.

## Purpose
Enforce the Definition of Done for the current phase before allowing advancement. Surface gaps as advisory warnings with explicit acknowledgement required. This hook is the quality gate between phases.

## Execution

### Step 1: Read current state
```
Read: sdlc-manifest.json → current_phase, artifacts produced, DoD checklist state
Read: sdlc-config.json → product configuration
```

### Step 2: Evaluate DoD for current phase

Run the DoD checklist for the current phase (from CLAUDE.md Phase Definitions of Done). For each item:
- Check whether the required artifact file exists at the expected path
- Check whether the artifact is registered in `sdlc-manifest.json` with status = "complete"
- Check whether any required sub-items (e.g. "at least one per epic") are met

**DoD evaluation per phase:**

#### Strategy DoD checks
```
vision.md exists?                           → FAIL if missing
north-star.md exists?                       → FAIL if missing
okrs.md exists?                             → FAIL if missing
roadmap.md exists?                          → FAIL if missing
gtm.md exists?                              → FAIL if missing
stakeholders.md exists?                     → WARN if missing
terminology scan passed?                    → WARN if not run
```

#### Ideate DoD checks
```
requirements/functional.md exists?          → FAIL
requirements/nfrs.md with measurable targets → FAIL
personas/ has at least 1 file?              → FAIL
story-map.md exists?                        → FAIL
epics/ has at least 1 file?                 → FAIL
stories/ has at least 3 per epic?           → WARN (count check)
examples/ has at least 2 per epic?          → WARN
moscow.md exists?                           → WARN
terminology scan passed?                    → WARN
```

#### Design DoD checks
```
design/domain/context.md exists?            → FAIL
design/domain/events.md exists?             → FAIL
design/bounded-contexts.md exists?          → FAIL
design/language/ has at least 1 file?       → FAIL
design/architecture/c4-context.md exists?   → FAIL
design/architecture/c4-container.md exists? → FAIL
design/adrs/ has at least 1 ADR?           → WARN
design/contracts/ has API contract?         → WARN
design/contracts/event-schemas.md exists?   → FAIL
design/data/data-architecture.md exists?    → FAIL
design/security/threat-model.md exists?     → FAIL
design/security/compliance-design.md?       → WARN (FAIL if compliance_frameworks > 0)
design/platform/deployment-architecture.md? → WARN
terminology scan passed?                    → WARN
```

#### Implement DoD checks
```
implement/standards/coding-standards.md?    → FAIL
implement/standards/repo-structure.md?      → FAIL
implement/specs/ has at least 1 TDD spec?  → FAIL
implement/features/ has at least 1 BDD file? → WARN
implement/scaffolds/ has at least 1 service? → WARN
implement/guides/api-implementation-guide.md? → WARN
terminology scan passed?                    → WARN
```

#### Data DoD checks
```
data/models/ has at least 1 file?          → FAIL
data/analytics-requirements.md exists?     → FAIL
data/dashboards/ has at least 1 file?      → WARN
data/quality-rules.md exists?              → FAIL
terminology scan passed?                   → WARN
```

#### Quality DoD checks
```
quality/test-plan.md exists?               → FAIL
quality/unit/ has at least 1 file?         → FAIL
quality/integration/ has at least 1 file?  → FAIL
quality/contracts/ has at least 1 file?    → WARN
quality/e2e/ has at least 1 file?          → WARN
quality/performance-test-plan.md exists?   → FAIL
quality/load-test-plan.md exists?          → WARN
quality/security-test-plan.md exists?      → FAIL
quality/chaos-test-plan.md exists?         → WARN
terminology scan passed?                   → WARN
```

#### Deploy DoD checks
```
deploy/ci/ has at least 1 pipeline file?   → FAIL
deploy/cd/ has at least 1 pipeline file?   → FAIL
deploy/iac/ has at least 1 module?         → WARN
deploy/helm/ has at least 1 chart?         → WARN
deploy/envs/ has at least 1 env config?    → WARN
deploy/canary-plan.md exists?              → WARN
operations/runbooks/ has at least 1 file?  → WARN
operations/slos.md exists?                 → FAIL
terminology scan passed?                   → WARN
```

#### Validate DoD checks
```
validate/uat-plan.md exists?               → FAIL
validate/scenarios/ has at least 1 file?   → WARN
validate/acceptance-checklist.md exists?   → FAIL
validate/metrics-plan.md exists?           → WARN
validate/feedback-template.md exists?      → WARN
terminology scan passed?                   → WARN
```

### Step 3: Collect results

```
HARD_FAILS = items marked FAIL that are missing
WARNINGS = items marked WARN that are missing
```

### Step 4: Present results and request acknowledgement

```
If HARD_FAILS is empty and WARNINGS is empty:
    "Phase {N} DoD: All checks passed. Advancing to Phase {N+1}."
    → Update sdlc-manifest.json: current_phase = next phase
    → Continue

If HARD_FAILS is not empty:
    "Phase {N} DoD: {N} required items are missing.
    
    MISSING (required — phase cannot advance without these):
    {list each missing item with artifact path}
    
    Use /sdlc-artifact {skill-name} to generate the missing artifacts, then run /sdlc-next again."
    
    → BLOCK advancement. Do NOT update manifest.

If HARD_FAILS is empty AND WARNINGS is not empty:
    "Phase {N} DoD: All required items are present. {N} optional items are incomplete.
    
    INCOMPLETE (optional — can advance but note these gaps):
    {list each incomplete item with artifact path}
    
    Type 'acknowledge' to advance despite these gaps, or generate the missing artifacts first."
    
    → Wait for acknowledgement
    → On 'acknowledge': record gap list in manifest under dod_gaps; advance phase
    → On other input: do not advance
```

### Step 5: Update manifest on success

```json
{
  "current_phase": "{next_phase}",
  "phases": {
    "{completed_phase}": {
      "status": "complete",
      "completed_at": "{ISO 8601}",
      "dod_gaps": ["{gap 1}", "{gap 2}"]
    }
  }
}
```
