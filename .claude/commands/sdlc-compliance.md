# Command: /sdlc-compliance

## Purpose
Run a compliance assessment against the configured frameworks. Invokes the compliance-assessor agent, surfaces gaps, tracks control status over time, and produces a compliance readiness report. The command that drives compliance as code — turning regulatory requirements into verifiable states.

## Usage
```
/sdlc-compliance                         # Full assessment — all configured frameworks
/sdlc-compliance --framework {name}      # Assess a specific framework (gdpr, soc2, hipaa)
/sdlc-compliance --gaps                  # List only the gaps (no IMPLEMENTED controls)
/sdlc-compliance --gate                  # Run the compliance gate (deploy-blocking check)
/sdlc-compliance --history               # Show compliance assessment history
```

## Execution

### `/sdlc-compliance` (full assessment)

```
Read: sdlc-config.json → compliance_frameworks
If empty: "No compliance frameworks configured. Add frameworks to sdlc-config.json."

For each framework:
  Invoke: compliance-assessor agent with framework as argument
  Collect: control status table (IMPLEMENTED | DOCUMENTED | GAP | NOT APPLICABLE)
  
Produce: compliance readiness report
Write: artifacts/core/reviews/compliance-{YYYY-MM-DDTHH-MM}.md
Update: sdlc-manifest.json → last_compliance_assessment
```

**Output format:**

```
Compliance Assessment — {product_name}
════════════════════════════════════════════════════════════════
Frameworks: GDPR, SOC 2
Date: {date}

────────────────────────────────────────────────────────────────
GDPR
────────────────────────────────────────────────────────────────

Control Status:
  ✓ IMPLEMENTED  (12) Art. 5(1)(c) Data minimisation, Art. 5(1)(e) Storage limitation...
  ◐ DOCUMENTED   (4)  Art. 15 Right to Access [design complete; not yet in code]
  ✗ GAP          (1)  Art. 20 Data Portability [not documented or implemented]
  — N/A          (2)  Art. 46 Cross-border transfer [justified: single-region only]

Readiness: NEAR READY (1 gap to close)

────────────────────────────────────────────────────────────────
SOC 2
────────────────────────────────────────────────────────────────

Control Status:
  ✓ IMPLEMENTED  (9)  CC6.1, CC6.2, CC7.1, CC7.2, A1.1...
  ◐ DOCUMENTED   (3)  CC7.3, CC9.1, PI1.1
  ✗ GAP          (0)
  — N/A          (0)

Readiness: NEAR READY (3 controls documented but not yet test-verified)

════════════════════════════════════════════════════════════════
Overall: NEAR READY

Next steps:
  1. Close GDPR gap: Run /sdlc-artifact validate/data-portability-spec
  2. Move DOCUMENTED → IMPLEMENTED: Run /sdlc-artifact quality/compliance-test-spec gdpr
  3. Re-run /sdlc-compliance to update status

Full report: artifacts/core/reviews/compliance-{timestamp}.md
```

---

### `/sdlc-compliance --gaps`

```
COMPLIANCE GAPS — {product_name}
─────────────────────────────────────────────────────

GDPR
  ✗ Art. 20: Data Portability
    Status: Not designed or implemented
    Severity: HIGH (required for GDPR compliance)
    Recommended artifact: validate/data-portability-spec
    Suggested skill: /sdlc-artifact validate/data-portability

No gaps in SOC 2.

Total: 1 gap across 2 frameworks.
```

---

### `/sdlc-compliance --gate`

```
Invoke: compliance-gate hook
Output: gate result (PASS | BLOCKED | CONDITIONAL)
(see compliance-gate.md for full gate logic)
```

---

### `/sdlc-compliance --history`

```
Read: sdlc-manifest.json → compliance assessment history
Read: artifacts/core/reviews/compliance-*.md

Output:
Compliance Assessment History — {product_name}
──────────────────────────────────────────────

Date                   Frameworks   IMPL  DOC  GAPS  Result
2026-06-21 09:00       GDPR, SOC2    21    7     1   NEAR READY
2026-06-14 14:30       GDPR, SOC2    18    9     3   SIGNIFICANT GAPS
2026-06-07 11:00       GDPR          10   12     5   SIGNIFICANT GAPS

Trend: GDPR gaps: 5 → 3 → 1 (improving)
       SOC 2 gaps: N/A → 2 → 0 (resolved)
```
