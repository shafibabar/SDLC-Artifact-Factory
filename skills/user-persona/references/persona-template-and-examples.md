# Persona Template and Worked Examples

Reference material for the `user-persona` skill. This file holds the copyable persona artifact template
and two fully worked personas for this repo's first product — the **Data Steward** and the **Compliance
Officer** — each with goals, behaviors, pains, and jobs, and each traceable to a job-to-be-done. It also
shows how to extend to secondary personas (buyer, champion) and closes with a filled-in review checklist
so an agent can see what "done" looks like.

Field definitions and the grounding standard live in `persona-fields-and-grounding.md`; this file is the
template-and-examples companion.

---

## 1. The persona artifact template

Every persona document opens with a frontmatter block (per the repo's Artifact Standards — key is
`name:`, never `artifact:`) and one persona block per modeled role. Copy this and fill it in.

```markdown
---
name: user-personas
version: 1.0.0
phase: strategy
created: [date]
owner: requirements-analyst
primary-persona: [name of the primary]
grounding: [proto | research | mixed]
---

# User Personas — [product name]

## Persona 1: [Name], [Role Title] — PRIMARY   [PROTO — assumption-based | RESEARCH — interview-grounded]

### Segment / role
- **Company:** [size, industry, regulatory exposure — consistent with the ICP from gtm-strategy]
- **Technical literacy:** [1-5 with a one-line description]
- **Domain expertise:** [shallow | working | deep]

### Goals
- **Primary:** [the one outcome they most want]
- **Secondary:** [2-3 others]
- **Success metric:** [what gets them recognized or promoted]

### Behaviors
- **Current approach:** [how they do it today, without your product]
- **Decision-making style:** [analytical | relational | spontaneous | methodical]
- **Information sources:** [where they learn about new tools]

### Pain points
- **Primary frustration:** [the biggest pain with the current approach]
- **Secondary frustrations:** [2-3 others]

### Relationship to product
- **Trigger:** [the specific event that makes them start looking]
- **Expected time to first value:** [how fast before they revert]
- **Adoption barrier:** [most likely reason they'd abandon after trying]

### Jobs to be done  → jtbd-analysis
- **Core job:** [When <trigger/situation>, I want to <motivation>, so I can <expected outcome>]
- [links each attribute above to at least one job story]

---

## Persona 2: [Name], [Role Title] — [PRIMARY | BUYER | CHAMPION]
[repeat the block]

---

## Anti-Persona: who this product is NOT for
[the user type explicitly excluded from the primary design target]
```

Per-attribute grounding note: in a `mixed` persona, tag individual lines `(proto)` or `(research)` so a
reviewer sees which attributes are still assumptions.

---

## 2. Worked persona — The Data Steward (PRIMARY)

**Devi Rao, Data Steward — PRIMARY**  ·  `RESEARCH — interview-grounded` (goals/current approach
validated with 3 design partners; trigger still `proto`)

### Segment / role
- **Company:** 150-employee B2B SaaS SMB; SOC 2 Type II in progress; data spread across Google Drive,
  an AWS S3 data lake, and exported PDF/DOCX/XLSX reports. Consistent with the ICP from `gtm-strategy`.
- **Technical literacy:** 4/5 — comfortable in cloud admin consoles and SQL, will not maintain a custom
  scanning script long-term.
- **Domain expertise:** deep on the company's own data layout, working knowledge of data-governance
  frameworks.

### Goals
- **Primary:** maintain an accurate, current inventory of *where every category of sensitive data
  actually lives* across all connected sources, without re-surveying colleagues by hand.
- **Secondary:** classify new sources within a day of connection; hand the Compliance Officer an
  export she can act on without re-work.
- **Success metric:** zero "we didn't know that data was there" surprises during an audit or incident.

### Behaviors
- **Current approach:** a manually maintained spreadsheet cross-referenced with ad-hoc `aws s3 ls`
  dumps and Google Drive folder spelunking — accurate the day she finishes it, stale a week later.
- **Decision-making style:** analytical — wants to see the tool find something her spreadsheet missed
  before she trusts it.
- **Information sources:** data-governance practitioner communities, vendor technical docs.

### Pain points
- **Primary frustration:** no single source of truth — the inventory is only ever as fresh as the last
  manual pass, and she cannot prove completeness.
- **Secondary frustrations:** classification is subjective and inconsistent between passes; every new
  source means starting the reconciliation over; exports to the Compliance Officer need hand-cleanup.

### Relationship to product
- **Trigger:** a new data source is connected, or the Compliance Officer asks "is *this* covered?" and
  she cannot answer with evidence.
- **Expected time to first value:** one working session — the first scan must surface at least one real
  finding, or she reverts to the spreadsheet.
- **Adoption barrier:** anything that makes the inventory *less* trustworthy than her spreadsheet — a
  scan she can't verify, or silent misclassification.

### Jobs to be done  → `jtbd-analysis`
- **Core job:** *When a new data source is connected to our estate, I want an automatic, verifiable
  classified inventory of what sensitive data it holds, so I can keep a single trustworthy source of
  truth without re-surveying the whole company by hand.*
- Traceability: *current approach* → the switching story; *primary frustration* (no single source of
  truth) → the job's motivation; *trigger* (new source connected) → the job's situational front;
  *time-to-first-value* → a first-run usability NFR.

---

## 3. Worked persona — The Compliance Officer (PRIMARY)

**Maya Chen, Compliance Officer — PRIMARY**  ·  `RESEARCH — interview-grounded`

### Segment / role
- **Company:** same 150-employee SMB as above; two of its largest customers require SOC 2 Type II.
- **Technical literacy:** 3/5 — fluent in SaaS admin consoles; will not run CLI tools or read API docs.
- **Domain expertise:** deep on compliance frameworks (SOC 2, data-protection obligations), shallow on
  where data physically lives — that is the Data Steward's territory.

### Goals
- **Primary:** walk into audit prep and quarterly board briefings knowing exactly what sensitive data
  exists and which controls are at risk, with evidence.
- **Secondary:** answer inbound customer security questionnaires quickly; brief the CISO without
  chasing engineering.
- **Success metric:** a clean SOC 2 report with zero surprise findings — that is what earns her trust
  internally.

### Behaviors
- **Current approach:** a spreadsheet built by interviewing team leads twice a year — outdated the day
  it is finished, and she cannot independently verify it.
- **Decision-making style:** methodical — waits for proof; will not stake an audit on an unverified tool.
- **Information sources:** compliance peer networks, auditor guidance, analyst reports.

### Pain points
- **Primary frustration:** cannot answer "where does customer PII actually live?" with evidence — only
  with folklore inherited from the last round of interviews.
- **Secondary frustrations:** every security questionnaire is a fire drill; gap reports are stale on
  arrival; she depends on the Data Steward's manual export and cannot self-serve.

### Relationship to product
- **Trigger:** an approaching SOC 2 Type II audit window, or an inbound customer security questionnaire.
- **Expected time to first value:** one working session — a gap report she can take to a meeting, or she
  reverts to the interview-and-spreadsheet routine.
- **Adoption barrier:** anything that requires her to file an engineering ticket to see her own
  compliance posture.

### Jobs to be done  → `jtbd-analysis`
- **Core job:** *When a SOC 2 audit window or a customer security questionnaire approaches, I want a
  current, evidence-backed gap report across the entire estate, so I can brief my CISO and answer
  auditors without relying on stale interview folklore.*
- Traceability: *primary frustration* (no evidence for "where does PII live") → the job's motivation;
  *trigger* (audit window / questionnaire) → the situational front; *adoption barrier* (no engineering
  ticket to see her own data) → an onboarding self-service constraint.

---

## 4. Why two primaries, not one blended persona

The Data Steward and the Compliance Officer share a company and a data estate, but their goals,
technical literacy, and success metrics differ enough that a single averaged persona would serve
neither. Devi wants a *verifiable, always-current inventory* and will run scans herself; Maya wants a
*defensible gap report for an audience* and will not touch a CLI. A blended "compliance user" persona
would hide exactly the differences that drive different requirements — this is the "single blended
persona for a multi-role product" anti-pattern. Model each distinct role separately; if a Delighter for
Devi is Indifferent to Maya, two personas make that visible and one hides it.

---

## 5. Extending to secondary personas

A multi-stakeholder B2B deal usually needs the buyer and the champion modeled too, even when they are
not the design anchor. Draw the roles from `stakeholder-mapping`'s "Manage Closely" quadrant:

| Role | Persona type | Why model it |
|---|---|---|
| Data Steward | PRIMARY user | Day-to-day operator; the product is designed for her first. |
| Compliance Officer | PRIMARY user | Owns the audit story; the second design anchor. |
| CISO / VP Engineering | BUYER (secondary) | Economic decision-maker; needs the assurance/viability story. Missing the buyer means the product never converts. |
| IT / DevOps Lead | CHAMPION (secondary) | Deploys and maintains it; a technical blocker if unconvinced. |
| Anti-persona | excluded | e.g. "a large enterprise wanting a fully on-prem air-gapped install" — stated so scope creep is resisted. |

Each secondary persona gets the same template block, but attributes need only be as deep as the deal
requires — the buyer's *adoption barrier* and *success metric* usually matter more than their
day-to-day behaviors.

---

## 6. Filled-in review checklist (what "done" looks like)

For the Data Steward persona above:

- [x] Labeled `RESEARCH` with per-attribute grounding noted (trigger still proto).
- [x] Goals, current approach, primary frustration, and trigger all present.
- [x] Current approach (manual spreadsheet + `aws s3 ls`) traces to a real observed workaround, not a
      hypothetical.
- [x] No decorative demographics — company size, industry, and regulatory exposure are included because
      they scope the compliance requirements; no age/photo/hobbies.
- [x] Links to a core JTBD and reads cleanly as "As a Data Steward, I want an automatic classified
      inventory of a newly connected source, so that I keep one trustworthy source of truth."
- [x] Distinct from the Compliance Officer persona — not blended into one "compliance user."
