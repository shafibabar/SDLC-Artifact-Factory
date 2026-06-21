# Hook: security-gate

## Trigger
Fires when:
- `pre-deploy` hook invokes it
- The user runs `/sdlc-review` in the Quality or Deploy phase
- A message contains "release", "ship", "production deploy", or "go live"
- Invoked directly by the `security-reviewer` agent

## Purpose
Enforce the security gate — a set of non-negotiable checks that must pass before any artifact is released or deployed to production. The security gate is the final automated security check in the delivery pipeline.

## Execution

### Step 1: Load security test evidence

```
Read: artifacts/quality/security-test-plan.md
Read: artifacts/quality/reports/ — find most recent test execution report
Read: artifacts/design/security/threat-model.md — open threats table
Read: sdlc-manifest.json — last security scan timestamps
```

### Step 2: Run security gate checks

#### Gate SG-01: Secret scanning (HARD BLOCK)
```
Check: gitleaks has been run (evidence in CI run or test report)
Check: gitleaks found 0 secrets
If: gitleaks not run OR findings > 0 → BLOCK
```

#### Gate SG-02: SAST (HARD BLOCK on HIGH+)
```
Check: gosec has been run
Check: gosec has 0 HIGH or CRITICAL findings unacknowledged
If: gosec not run OR unacknowledged HIGH+ findings → BLOCK
```

#### Gate SG-03: Dependency vulnerabilities (HARD BLOCK on CRITICAL)
```
Check: govulncheck has been run
Check: govulncheck has 0 CRITICAL findings
If: not run OR CRITICAL findings → BLOCK
```

#### Gate SG-04: Container image scan (HARD BLOCK on CRITICAL)
```
Check: trivy has been run on built images
Check: trivy has 0 CRITICAL findings
If: not run OR CRITICAL findings → BLOCK
```

#### Gate SG-05: Tenant isolation tests (HARD BLOCK)
```
Check: Security test cases ST-A01-01 through ST-A01-05 have passed
Check: Security test cases ST-ISO-01 through ST-ISO-05 have passed
If: not run OR any failure → BLOCK
```

#### Gate SG-06: Authentication tests (HARD BLOCK)
```
Check: ST-A07-01 (JWT signature verification) passed
Check: ST-A07-02 (JWT alg=none rejected) passed
If: not run OR any failure → BLOCK
```

#### Gate SG-07: Open CRITICAL threats (HARD BLOCK)
```
Read: threat-model.md → open threats table
If: any threat with residual_risk = CRITICAL is marked "OPEN" (no mitigation) → BLOCK
```

#### Gate SG-08: DAST scan (WARN — must be scheduled within 30 days)
```
Check: OWASP ZAP DAST scan has been run against staging
Check: No MEDIUM+ findings unresolved
If: not run in last 30 days → WARN
If: MEDIUM+ findings unresolved → BLOCK
```

### Step 3: Output

```
Security Gate
════════════════════════════════════════════════════════════════

SG-01 Secret scanning (gitleaks):         {PASS / BLOCK}
SG-02 SAST — gosec HIGH+:                {PASS / BLOCK}
SG-03 Dependency CVEs (govulncheck):      {PASS / BLOCK}
SG-04 Container image (trivy):            {PASS / BLOCK}
SG-05 Tenant isolation tests:             {PASS / BLOCK / NOT RUN}
SG-06 Authentication tests:               {PASS / BLOCK / NOT RUN}
SG-07 Open CRITICAL threats:              {PASS / BLOCK}
SG-08 DAST scan (ZAP):                    {PASS / WARN / BLOCK}

════════════════════════════════════════════════════════════════
Security Gate: {PASS / BLOCKED}

{If BLOCKED:}
RELEASE IS BLOCKED. Resolve the following before proceeding:
  • SG-{N}: {blocking reason}

{If PASS:}
Security gate passed. No blocking security findings.
```

### Step 4: Record in manifest

```json
{
  "last_security_gate_run": "{ISO 8601}",
  "security_gate_result": "PASS | BLOCKED",
  "blocking_gates": ["SG-01", "SG-05"]
}
```

## Non-Negotiable
The security gate **cannot be bypassed or silenced** by user acknowledgement. Every BLOCK is a hard stop. If a finding is incorrect, it must be resolved in the tool (gosec-ignore, trivy advisory, etc.) — not overridden here.

The only exceptions are SG-08 (DAST — WARN only for recency) and acknowledged LOW findings in gosec.
