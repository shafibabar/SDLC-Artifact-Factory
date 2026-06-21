# Hook: pre-deploy

## Trigger
Fires when:
- The user runs any deploy-phase command that would push or apply infrastructure changes
- The `platform-engineer` agent is about to generate a deploy artifact that references real infrastructure
- Detected: a message contains "deploy to production", "apply infrastructure", "push release"

## Purpose
Enforce the pre-deployment checklist before any real infrastructure change is initiated. Verify that the quality gate has passed, the security gate has passed, and all deploy phase artifacts are present. Block accidental or premature deployments.

## Execution

### Step 1: Load state

```
Read: sdlc-manifest.json
Check: current_phase is "Deploy" or later
Check: phases.Quality.status = "complete"
Check: phases.Implement.status = "complete"
```

### Step 2: Quality gate check

```
Verify: artifacts/quality/reports/ contains at least one test execution report
Verify: Most recent test execution report has status = APPROVED or CONDITIONAL
  
If no report: BLOCK — "Quality phase test execution report required before deploy"
If most recent report = BLOCKED: BLOCK — "Test execution report must be APPROVED before deploy"
If most recent report = CONDITIONAL: WARN — "Test execution report is CONDITIONAL — review known issues before proceeding"
```

### Step 3: Security gate check

```
Invoke: security-gate hook (runs inline — see security-gate.md)
If security-gate returns BLOCK: BLOCK deploy
If security-gate returns WARN: surface warning and request acknowledgement
```

### Step 4: Deploy artifact check

```
Verify: deploy/ci/ has at least one CI pipeline file
Verify: deploy/cd/ has at least one CD pipeline file
Verify: operations/slos.md exists
Verify: operations/runbooks/ has at least one runbook

If any FAIL: WARN — "Missing deploy artifacts may indicate incomplete Deploy phase"
```

### Step 5: Production-specific check

If the deploy target is production:

```
Verify: deploy/envs/production.md exists
Verify: deploy/canary-plan.md OR deploy/blue-green-plan.md exists
Verify: operations/dr-plan.md exists
Verify: Quality phase was completed with APPROVED test execution report (not CONDITIONAL)

If any fail: BLOCK — production requires all deploy artifacts and an APPROVED quality gate
```

### Step 6: Output

```
Pre-Deploy Check
────────────────────────────────────────────────────────────────
Target environment: {environment}

Quality gate: {PASS / FAIL / CONDITIONAL}
Security gate: {PASS / FAIL / WARN}
Deploy artifacts: {COMPLETE / INCOMPLETE}
Production readiness: {READY / NOT READY} (if applicable)

{If all pass:}
Pre-deploy checks passed. Proceeding with deploy phase action.

{If blocked:}
DEPLOY BLOCKED — resolve the following before proceeding:
  • {blocking reason 1}
  • {blocking reason 2}

{If warnings only:}
Pre-deploy checks passed with warnings:
  • {warning 1}
Type 'acknowledge' to proceed despite warnings.
```
