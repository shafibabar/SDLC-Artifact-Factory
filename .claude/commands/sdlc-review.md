# Command: /sdlc-review

## Purpose
Trigger a methodology compliance check on the current phase's artifacts. Invokes the appropriate reviewer agents (architecture-reviewer, security-reviewer, compliance-assessor, ux-strategist) and consolidates their findings into a single review report. The structured gate between "we built it" and "it is ready to advance."

## Usage
```
/sdlc-review                         # Review current phase artifacts
/sdlc-review --artifact {path}       # Review a specific artifact
/sdlc-review --agent {agent-name}    # Run only a specific reviewer agent
/sdlc-review --full                  # Run all agents across all produced artifacts
```

## Available agents
- `architecture-reviewer` — DDD, CQRS, hexagonal, ADR compliance
- `security-reviewer` — OWASP, threat model, tenant isolation, secrets
- `compliance-assessor` — GDPR, SOC 2, HIPAA control coverage
- `ux-strategist` — JTBD alignment, flow completeness, accessibility

## Execution

### Step 1: Determine review scope

```
If --artifact {path}: review that artifact with all applicable agents
If --agent {name}: run only that agent on all current-phase artifacts
If no flags: review all artifacts in artifacts/{current_phase}/
  Dispatch agents by phase:
    Design → architecture-reviewer + security-reviewer + compliance-assessor + ux-strategist (if UX artifacts)
    Implement → architecture-reviewer + security-reviewer
    Data → compliance-assessor (data quality, retention)
    Quality → architecture-reviewer (test coverage) + security-reviewer (security test plan)
    Deploy → platform-engineer (CI/CD, IaC, Helm review)
```

### Step 2: Run terminology drift detector

```
Invoke: terminology-drift-detector hook (full scan of current phase)
Collect: drift report path
```

### Step 3: Run ADR conflict detector

```
Invoke: adr-conflict-detector hook (scan current phase artifacts against ADRs)
Collect: conflict findings
```

### Step 4: Run contract compliance checker (if Design or Implement phase)

```
Invoke: contract-compliance-checker hook
Collect: contract gap findings
```

### Step 5: Invoke reviewer agents

For each applicable agent:
```
Read: all artifacts in scope
Apply: agent's review checklist (from agent SKILL.md file)
Collect: findings by severity (BLOCKING | WARNING | ADVISORY)
```

### Step 6: Consolidate and output

```markdown
# Phase Review: {Phase Name}
**Date:** {date}
**Product:** {product_name}
**Reviewer agents:** {list of agents run}
**Artifacts reviewed:** {N}

---

## Summary

| Severity | Count |
|----------|-------|
| BLOCKING | {N} |
| WARNING | {N} |
| ADVISORY | {N} |

**Review result:** APPROVED | BLOCKED | CONDITIONAL

---

## Blocking Findings

{If any BLOCKING findings:}
### [ARCH-BLOCK-001] Domain package imports infrastructure package
**Agent:** architecture-reviewer
**Artifact:** artifacts/implement/scaffolds/file-domain/internal/domain/aggregates/storage_location.go
**Rule:** Hexagonal architecture — domain layer must not import infrastructure packages
**Fix:** Move the pgx import to the infrastructure layer; use the repository interface in the domain

---

## Warnings

{If any WARNINGS:}
...

## Terminology Drift
{Summary from terminology-drift-detector}

## ADR Conflicts
{Summary from adr-conflict-detector}

## Contract Compliance
{Summary from contract-compliance-checker (if applicable)}

---

## Next Steps

{If APPROVED:}
Review complete — no blocking findings. Phase artifacts are methodology-compliant.
You can advance with /sdlc-next.

{If BLOCKED:}
Review complete — {N} blocking finding(s) require resolution before phase can advance.
Fix the issues above and re-run /sdlc-review.

{If CONDITIONAL:}
Review complete — no blocking findings but {N} warnings.
Acknowledge warnings with 'acknowledge' to advance, or resolve them first.
```

### Step 7: Write review report artifact

**File:** `artifacts/core/reviews/methodology-{YYYY-MM-DDTHH-MM}.md`
**Registers in manifest:** yes (under core/reviews/)
