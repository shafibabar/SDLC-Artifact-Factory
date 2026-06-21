# Command: /sdlc-threat-model

## Purpose
Create, update, or review the STRIDE threat model for the product. Walks through each service boundary, applies STRIDE analysis, and produces a threat model artifact. Can also be used to review a specific threat or add a new threat to an existing model.

## Usage
```
/sdlc-threat-model                      # Full STRIDE analysis — create or update threat model
/sdlc-threat-model --review             # Review existing threat model for completeness
/sdlc-threat-model --add "{threat}"     # Add a new threat entry to the existing model
/sdlc-threat-model --threat {T-ID}      # Show details for a specific threat
/sdlc-threat-model --open               # List all open (unmitigated) threats
```

## Execution

### `/sdlc-threat-model` (full analysis)

```
Pre-flight:
  Read: artifacts/design/architecture/c4-container.md (service boundaries)
  Read: artifacts/design/architecture/c4-context.md (external actors)
  Read: artifacts/design/security/security-architecture.md
  Read: artifacts/design/security/access-control-model.md
  
  If artifacts/design/security/threat-model.md exists:
    Prompt: "Threat model already exists. Update it or start fresh?"
    On 'update': add to existing; retain previous threats
    On 'fresh': archive existing to threat-model-{timestamp}.md; create new
```

**STRIDE analysis framework:**

For each trust boundary (derived from C4 container diagram):
```
Trust boundaries to analyse:
  External actor → API Gateway
  API Gateway → Service (via Linkerd mTLS)
  Service → PostgreSQL
  Service → Redpanda
  Service → Elasticsearch
  Platform → Worker Node (outbound connection)
  Worker Node → Customer Infra (file systems, drives)
```

For each boundary, apply:
| STRIDE category | Question asked |
|----------------|---------------|
| Spoofing | Can an attacker impersonate a legitimate actor at this boundary? |
| Tampering | Can data in transit or at rest be modified? |
| Repudiation | Can an actor deny having performed an action at this boundary? |
| Information Disclosure | Can data be read by an unauthorised party? |
| Denial of Service | Can this boundary be overwhelmed to deny service? |
| Elevation of Privilege | Can an actor gain more access than intended? |

**Invoke skill:** `design/threat-model` to generate the artifact if creating new.

**Output:** Link to `artifacts/design/security/threat-model.md`

---

### `/sdlc-threat-model --review`

```
Read: artifacts/design/security/threat-model.md
Invoke: security-reviewer agent → threat model review checklist
Check:
  - All service boundaries are covered (compare with C4 container diagram)
  - All STRIDE categories have at least one threat per major boundary
  - Every threat has: attack vector, mitigation, residual risk, DREAD rating
  - Open threats (no mitigation) are in the open threats table

Output:
Threat Model Review
───────────────────────────────────────────────────────────────
Total threats: {N} ({N} mitigated, {N} open)
Boundaries covered: {N}/{N}
STRIDE coverage: {S/T/R/I/D/E — each checked}

Gaps:
  • Boundary "Worker Node → Customer File System" has no Tampering threat defined
  • Threat T-I-03 has no DREAD rating
  • {N} threats marked OPEN with no mitigation

Run /sdlc-threat-model --add "{threat}" to add missing threats.
```

---

### `/sdlc-threat-model --add "{threat}"`

Interactive threat entry:

```
Adding new threat. Answer the following:

1. STRIDE category: [S/T/R/I/D/E]
2. Trust boundary affected: [list from C4 diagram]
3. Attack description: {what the attacker does}
4. Impact: {what happens if the attack succeeds}
5. Mitigation: {what controls prevent or detect this}
6. Residual risk: [CRITICAL/HIGH/MEDIUM/LOW]
7. Status: [MITIGATED/OPEN/ACCEPTED]

Generated threat ID: T-{category}-{sequence}
Writing to: artifacts/design/security/threat-model.md
```

---

### `/sdlc-threat-model --open`

```
Read: artifacts/design/security/threat-model.md → open threats table

Output:
Open Threats (no mitigation) — {product_name}
───────────────────────────────────────────────────────────────
ID        Category  Boundary                    Residual risk  Age
T-D-04    DoS       API Gateway → Services      HIGH           14 days
T-I-06    Info Disc  Platform → Worker Node     MEDIUM         3 days

{N} open threats. CRITICAL threats block the security gate.
Run /sdlc-threat-model --threat {ID} for full details.
Run /sdlc-threat-model --add to add mitigations.
```
