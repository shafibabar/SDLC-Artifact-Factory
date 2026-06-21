# Hook: pre-uat

## Trigger
Fires when:
- The user advances to the Validate phase via `/sdlc-next` from Deploy
- The user runs `/sdlc-artifact validate/uat-plan`
- A message contains "begin UAT", "start user acceptance testing", or "customer validation"

## Purpose
Verify that all prerequisites for User Acceptance Testing are met: the system is deployed to the UAT environment, the quality gate has passed, and the UAT plan artifacts are in place. Ensure UAT is a deliberate, prepared activity — not an improvised exploration.

## Execution

### Step 1: Load state

```
Read: sdlc-manifest.json
Check: Deploy phase status = "complete" OR current_phase = "Validate"
```

### Step 2: Deploy prerequisite check

```
Verify: UAT / staging environment is specified in deploy/envs/
Verify: A successful CD pipeline run is recorded in the manifest OR the user confirms environment is live

If deploy/envs/ has no UAT environment config:
  WARN — "No UAT environment config found — add deploy/envs/uat.md before beginning UAT"
```

### Step 3: Quality gate prerequisite check

```
Verify: quality/test-plan.md exists
Verify: quality/reports/ contains at least one APPROVED test execution report
Verify: E2E test specs exist (quality/e2e/)
Verify: Acceptance test scenarios exist (quality/e2e/ or validate/scenarios/)

If quality gate not APPROVED:
  BLOCK — "UAT requires an APPROVED quality gate. Run /sdlc-artifact quality/test-execution-report first."
```

### Step 4: UAT artifact check

```
Required for UAT to begin:
  validate/uat-plan.md                     → FAIL if missing
  
Recommended before UAT:
  validate/scenarios/ (at least 1 file)    → WARN if missing
  validate/acceptance-checklist.md         → WARN if missing
  validate/feedback-template.md            → WARN if missing
```

### Step 5: Participant check

```
Read: validate/uat-plan.md (if exists)
Check: UAT plan lists at least one named participant (real user, not the development team)
Check: UAT plan lists a named facilitator
Check: UAT plan specifies the UAT environment URL or access method

If uat-plan.md missing or these elements absent:
  WARN — "UAT plan should include participants, facilitator, and environment access before beginning"
```

### Step 6: Output

```
Pre-UAT Check
────────────────────────────────────────────────────────────────

Deploy prerequisite: {PASS / WARN}
Quality gate: {PASS / FAIL}
UAT artifacts: {COMPLETE / INCOMPLETE}
Participants defined: {YES / NO}

{If BLOCKED:}
UAT BLOCKED:
  • Quality gate must be APPROVED before UAT begins
  • Run /sdlc-artifact quality/test-execution-report to generate the report

{If warnings only:}
UAT can begin. Recommended actions before starting:
  • {warning 1}
  • {warning 2}

{If all pass:}
Pre-UAT checks passed. UAT can begin.
Reminder: UAT tests the product with real users — not the development team.
Record feedback in validate/scenarios/ using /sdlc-artifact validate/uat-plan.
```
