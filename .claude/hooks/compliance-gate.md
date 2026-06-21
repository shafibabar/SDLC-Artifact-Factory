# Hook: compliance-gate

## Trigger
Fires when:
- `pre-deploy` hook invokes it (for production deploy)
- The user runs `/sdlc-compliance --gate`
- A message contains "release to production" or "go-live" and compliance frameworks are configured
- Phase advances from Quality to Deploy

## Purpose
Verify that all compliance controls required for the product's declared compliance frameworks are either IMPLEMENTED or have a documented, time-bounded remediation plan. Block production release if there are unmitigated compliance gaps. This is the compliance equivalent of the security gate.

## Execution

### Step 1: Load compliance configuration

```
Read: sdlc-config.json → compliance_frameworks
If compliance_frameworks is empty: OUTPUT "No compliance frameworks configured. Gate passes by default." EXIT

Read: artifacts/design/security/compliance-design.md → control status table
Read: artifacts/quality/compliance/ → all compliance test specs
Read: sdlc-manifest.json → last compliance assessment
```

### Step 2: For each compliance framework, evaluate control status

```
For each framework in compliance_frameworks:
  Count controls with status = IMPLEMENTED
  Count controls with status = DOCUMENTED (design exists; code not yet verified)
  Count controls with status = GAP (missing entirely)
  Count controls with status = NOT APPLICABLE (must have justification)
```

### Step 3: Apply gate thresholds

#### Threshold CG-01: No unmitigated GAPsfor CRITICAL controls (HARD BLOCK)
```
CRITICAL controls (always CRITICAL regardless of framework):
  - Encryption at rest for C4 data
  - Tenant isolation (cross-tenant data access prevention)
  - Data sovereignty (PII must not transit product infrastructure)
  - Secret management (no hardcoded credentials)
  - Audit trail (immutable, append-only)
  - Right to Erasure workflow (for GDPR)

If any CRITICAL control = GAP: BLOCK
```

#### Threshold CG-02: Maximum DOCUMENTED threshold (WARN at 20%, BLOCK at 40%)
```
documented_ratio = DOCUMENTED_count / (IMPLEMENTED + DOCUMENTED)
If documented_ratio >= 0.40: BLOCK — "Too many controls are designed but not verified by tests"
If documented_ratio >= 0.20: WARN — "Some controls are documented but not yet tested"
```

#### Threshold CG-03: Compliance test coverage (WARN if any framework has no test spec)
```
For each framework:
  If artifacts/quality/compliance/{framework}.md does not exist:
    WARN — "No compliance test spec for {framework}"
```

#### Threshold CG-04: Last compliance assessment recency (WARN if > 30 days)
```
If last_compliance_assessment is more than 30 days ago:
  WARN — "Last compliance assessment was {N} days ago — re-run /sdlc-compliance before release"
```

### Step 4: Output

```
Compliance Gate
════════════════════════════════════════════════════════════════

Frameworks: {list from sdlc-config.json}

Framework: GDPR
  IMPLEMENTED: {N}/{total}
  DOCUMENTED:  {N}/{total}
  GAPS:        {N}/{total}

Framework: SOC 2
  IMPLEMENTED: {N}/{total}
  DOCUMENTED:  {N}/{total}
  GAPS:        {N}/{total}

────────────────────────────────────────────────────────────────
CG-01 Critical controls (no GAPs):   {PASS / BLOCK}
CG-02 Implementation ratio:           {PASS / WARN / BLOCK}
CG-03 Test spec coverage:             {PASS / WARN}
CG-04 Assessment recency:             {PASS / WARN}
════════════════════════════════════════════════════════════════
Compliance Gate: {PASS / BLOCKED}

{If BLOCKED:}
RELEASE IS BLOCKED. Resolve the following:
  • {blocking reason 1}
  • {blocking reason 2}

{If WARN only:}
Compliance gate passed with warnings. Acknowledge to proceed:
  • {warning 1}

{If PASS:}
Compliance gate passed.
Note: This gate verifies control documentation and test coverage.
External compliance certification requires an independent audit.
```

### Step 5: Record in manifest

```json
{
  "last_compliance_gate_run": "{ISO 8601}",
  "compliance_gate_result": "PASS | BLOCKED | CONDITIONAL",
  "frameworks_evaluated": ["gdpr", "soc2"],
  "critical_gaps": [],
  "documented_ratio": 0.12
}
```

## Non-Negotiable
Compliance gate BLOCK findings for CG-01 (critical control gaps) cannot be bypassed by acknowledgement. Every critical control gap is a hard stop.

CG-02 and CG-03 findings can be acknowledged with a rationale, but the rationale is recorded in the manifest and surfaced in all subsequent compliance assessments.

The phrase "compliant with {framework}" must not be used in any artifact or response — use "controls implemented for" or "audit-ready for" instead.
