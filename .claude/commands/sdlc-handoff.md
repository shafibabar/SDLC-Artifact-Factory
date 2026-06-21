# Command: /sdlc-handoff

## Purpose
Produce a structured handoff package — a condensed, role-specific view of the product's artifacts, decisions, and state — for a new team member, an external auditor, an implementation partner, or a handoff to a different development team. Ensures all context is transferable without requiring access to the full conversation history.

## Usage
```
/sdlc-handoff                            # Full handoff for a developer joining the team
/sdlc-handoff --role {role}              # Role-specific handoff
/sdlc-handoff --audience {audience}      # Audience: developer | auditor | pm | executive | partner
/sdlc-handoff --phase {phase}            # Handoff focused on a specific phase
```

## Available roles / audiences
| Audience | Focus |
|----------|-------|
| `developer` | Architecture decisions, coding standards, repo structure, TDD/BDD specs, event contracts |
| `auditor` | Compliance controls, audit trail, data classification, retention policies, threat model |
| `pm` | Strategy, OKRs, user stories, acceptance criteria, roadmap, UAT plan |
| `executive` | Vision, North Star, OKRs, roadmap summary, compliance posture, risk register |
| `partner` | API contracts, event schemas, integration design, consumer-driven contracts |

## Execution

### Step 1: Load product state

```
Read: sdlc-manifest.json
Read: sdlc-config.json
Determine: which phases are complete; which artifacts exist
```

### Step 2: Generate audience-appropriate package

**For `developer` audience:**

```markdown
# Developer Handoff: {product_name}
**Date:** {date}
**Prepared for:** New developer / implementation partner

## What this product does
{Summary from vision.md — 2–3 sentences}

## Architecture at a glance
- **Bounded Contexts:** {list from bounded-contexts.md}
- **Communication:** Event-driven via Redpanda; no direct service-to-service HTTP
- **Key ADRs:** {list from ADR INDEX with one-line summary per ADR}
- **Repository map:** See artifacts/design/multi-repo-map.md

## Where to start
1. Read `artifacts/design/architecture/c4-container.md` — container diagram
2. Read `artifacts/implement/standards/coding-standards.md`
3. Read `artifacts/implement/standards/repo-structure.md`
4. Run `make test` in your BC repo to verify the TDD specs pass (they should — they're the failing tests)

## Non-negotiables
- TDD: No implementation without a failing test first
- Zero I/O in domain packages — no pgx, no net/http imports in `internal/domain/`
- Idempotency: every event handler checks `{bc}_processed_events` first
- Secrets: use credential_ref scheme (`vault://`, `aws-sm://`) — never raw values
- Tenant isolation: every DB query includes `tenant_id` filter

## Key contacts
{from stakeholders.md — product owner, tech lead}
```

**For `auditor` audience:**

```markdown
# Audit Handoff: {product_name}
**Date:** {date}
**Frameworks in scope:** {from sdlc-config.json}

## Evidence Index

| Control area | Artifact location | Last updated |
|-------------|------------------|-------------|
| Data classification | artifacts/design/data/data-classification.md | {date} |
| Data retention policy | artifacts/design/data/data-retention-policy.md | {date} |
| Access control model | artifacts/design/security/access-control-model.md | {date} |
| Threat model | artifacts/design/security/threat-model.md | {date} |
| Compliance design | artifacts/design/security/compliance-design.md | {date} |
| Audit trail spec | artifacts/design/security/privacy-design.md | {date} |
| Compliance test specs | artifacts/quality/compliance/ | {date} |
| Last compliance assessment | artifacts/core/reviews/compliance-{latest}.md | {date} |

## Compliance Posture Summary
{From last compliance assessment — control counts per framework}

## Known Gaps and Remediation Plans
{From compliance assessment gaps section}
```

**For `executive` audience:**

```markdown
# Executive Handoff: {product_name}
**Date:** {date}

## Why we're building this
{vision.md — 2 sentences}

## Our success metrics
{north-star.md — NSM definition}
{okrs.md — Objectives and Key Results summary}

## Where we are
{Phase progress from sdlc-manifest.json — visual progress}

## Top risks
{From risk-register.md if exists, or from threat-model.md residual risks}

## Compliance status
{From last compliance assessment — AUDIT READY / NEAR READY / GAPS}
```

### Step 3: Write handoff artifact

**File:** `artifacts/core/handoff-{audience}-{YYYY-MM-DD}.md`
**Registers in manifest:** yes

### Step 4: Output

```
Handoff package generated: artifacts/core/handoff-{audience}-{date}.md

This package is self-contained — it includes all references needed for 
a new {audience} to understand the product without access to this conversation.

Share the entire artifacts/ directory alongside this handoff document for full context.
```
