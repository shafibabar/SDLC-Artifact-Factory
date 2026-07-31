# Privacy by Design — The Seven Foundational Principles, and the FIPPs Beneath Them

Reference for `privacy-design`. The body names the seven Privacy by Design (PbD)
principles and the Fair Information Practice Principles (FIPPs) as pointers; this file
gives each principle in depth with a concrete application in this repo (the data-estate
/ compliance platform: Go + chi + pgx, Redpanda, per-tenant physical isolation, Linkerd
mTLS, PII entity extraction where raw file contents are never persisted — only entity
types and counts), and maps the FIPPs forward to GDPR and CCPA/CPRA obligations.

Attribution: the seven principles are **Ann Cavoukian's** Privacy by Design framework.
The FIPPs are an OECD / US-FTC lineage. Neither is original to *The Privacy Engineer's
Manifesto* (Dennedy, Fox, Finneran) — that book operationalises them, and its
contribution used here is turning each principle into a lifecycle control and a metadata
artifact rather than a policy assertion. Cite the principles by their standard names.

---

## The Seven Principles, in depth

### 1. Proactive not reactive; preventative not remedial

Privacy risk is identified and designed out *before* code exists, not patched after an
incident. The forcing function in this repo: privacy misuse cases are authored during the
Design phase and fed into the `threat-modeling` STRIDE-per-element pass, so
re-identification and over-retention are surfaced as modelled threats, not discovered in
production. A DPIA (see `pii-lifecycle-controls.md`) is a Design-phase artifact — a DPIA
run after go-live can only document risk, never design it out.

**In this repo:** the "raw file contents are never persisted" decision is the archetypal
proactive control — it removes an entire class of disclosure risk at the schema level
before a single handler is written.

### 2. Privacy as the default setting

The strictest privacy posture is what a user gets with zero configuration; a lower
posture requires a deliberate opt-in, never an opt-out. No PII category is retained
longer, shared wider, or used for more purposes than the default unless someone
explicitly widens it and records why.

**In this repo:** retention defaults to the shortest defensible window (90 days for file
metadata and extracted entity summaries); a longer window is a per-tenant override with a
recorded basis, not a global default. Extraction defaults to types-and-counts only.

### 3. Privacy embedded into design

Privacy controls live *inside* the domain model and the infrastructure, not in a bolt-on
`privacy-service` beside them. Retention lives on the `DataAsset` Aggregate; purpose tags
live on the pgx data-access layer; minimisation lives in the type that represents an
extracted finding. Principle 3 is architectural, not organisational — there is no separate
"privacy module" to forget to call.

### 4. Full functionality — privacy *and* utility, both, never traded

Cavoukian frames this as a rejection of the false trade-off that privacy must cost
functionality. The product must achieve its compliance-detection purpose *and* its privacy
posture simultaneously. This is the "positive-sum, not zero-sum" principle: the design goal
is both goods at once, not a negotiated balance between them.

**In this repo:** storing entity *types and counts* instead of raw text loses no
compliance-detection capability ("this file contains 3 national-ID numbers" is exactly what
the compliance use case needs) while eliminating the disclosure risk of raw PII. Utility and
privacy rise together — the minimisation *is* the feature.

### 5. End-to-end security — full lifecycle protection

Personal data is protected across its entire lifecycle: collect → use → retain → disclose
→ destroy. Encryption in transit (Linkerd mTLS between services), Encryption at Rest
(Postgres), Attribute-Based Access Control on every read, and an immutable audit trail
together cover every stage. Note the boundary: these are *security* controls that protect
data **that exists** — they do not decide whether the data *should* exist (that is
principle 2 and data minimisation). See `pii-lifecycle-controls.md` for the per-stage map.

### 6. Visibility and transparency — keep it open

Processing activities are documented, auditable, and disclosable to data subjects. The
GDPR Article 30 record of processing activities (see `pii-lifecycle-controls.md`) is the
artifact; the audit log is the machine-readable proof. Transparency is a *system output*,
not a static PDF — the design must be able to answer "what is processed, for what purpose,
for how long" from live metadata.

### 7. Respect for user privacy — keep it user-centric

Individuals can see what is processed about them and act on it (access, correct, delete).
For this B2B product the participation right routes through the controller/processor split
(see below): a customer's employee (a *user* of the product) exercises rights against us
directly; a person merely *named in a scanned document* exercises rights against the
customer, who is the controller of that in-document PII.

---

## The controller / processor split (why principle 7 is not uniform here)

| Data | Controller | Processor | Who fields a data-subject request |
|---|---|---|---|
| User account data (customer's employees) | The customer | Us | We do — direct erasure/access path |
| Extracted entity summaries (people named in files) | The customer | Us | The customer does — we route requests to them |
| Access / audit logs | Us (for security) | — | Declined under legal-retention basis; anonymise the actor |

Routing an in-document-PII erasure request to the processor short-circuits the legal chain.
The customer holds the relationship with those data subjects; we act only on the customer's
documented instruction.

---

## The FIPPs — the substrate beneath every regulation

Modern privacy regimes descend from a common ancestor: the Fair Information Practice
Principles. Mapping a control back to its FIPP shows *why* it exists, before mapping it
forward to *which* regulation names it — one FIPP unifies what otherwise look like
unrelated GDPR and CCPA rows.

| FIPP | What it requires | GDPR expression | CCPA / CPRA expression |
|---|---|---|---|
| **Collection limitation** | Collect only what is needed, lawfully | Art 5(1)(c) data minimisation; Art 6 lawful basis | §1798.100(c) collection limited to disclosed purpose |
| **Purpose specification** | State the purpose at/before collection | Art 5(1)(b) purpose limitation | §1798.100(b) notice of purpose at collection |
| **Use limitation** | Use only for the specified purpose | Art 5(1)(b); Art 6(4) compatibility test | §1798.100(c) no incompatible secondary use |
| **Data quality** | Keep data accurate and current | Art 5(1)(d) accuracy | Right to correct (CPRA §1798.106) |
| **Security safeguards** | Protect data proportionate to risk | Art 5(1)(f) integrity & confidentiality; Art 32 | §1798.100(e) reasonable security |
| **Openness / transparency** | Disclose practices openly | Arts 13–14 information duties; Art 30 records | §1798.130 notice at collection |
| **Individual participation** | Access, correct, delete | Arts 15–17 (access, rectification, erasure) | §§1798.100/105/106 (know, delete, correct) |
| **Accountability** | Be able to *demonstrate* compliance | Art 5(2) accountability; Art 24 | §1798.185 audit/risk-assessment duties |

**How to use this table:** in a coverage matrix, add a FIPP column *before* the regulation
column. "Purpose limitation" as one FIPP row then unifies GDPR Art 5(1)(b), CCPA
§1798.100(b), and SOC 2's Privacy criteria as three expressions of a single principle —
collapsing duplicate controls and, crucially, revealing any FIPP with **zero** controls
mapped to it (a genuine gap that a regulation-first matrix hides).

**Accountability is the FIPP that makes the others testable.** It demands that compliance
be *demonstrable*, not asserted on faith — a documented 90-day retention proves nothing;
the *audited execution* of the deletion job is the evidence. This is the principle that
turns every other privacy obligation into an engineering requirement with an acceptance
criterion (see `pii-lifecycle-controls.md`, retain and destroy stages).

---

## Caveat on regulatory citation

The PbD principles and FIPPs are stable and citable by their standard names. Do **not**
attribute specific GDPR article numbers or CCPA section numbers to *The Privacy Engineer's
Manifesto* (2014) — it pre-dates GDPR (2018) and CCPA (2020). The article/section mappings
above are grounded in the regulations themselves; the *principles* map forward cleanly
because GDPR and CCPA codified exactly what the FIPPs and PbD already taught.
