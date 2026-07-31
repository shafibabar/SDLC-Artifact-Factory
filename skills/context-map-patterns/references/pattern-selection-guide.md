# Pattern Selection Guide
## A worked decision tree for Context Map pattern selection

This file is self-contained — usable without the parent SKILL.md in context. It provides a
step-by-step decision tree that starts from the team relationship and arrives at 1–2 pattern
candidates, including the political signals that override technical preference.

Sources: Evans, *Domain-Driven Design* (2003), Ch. 14; Vernon, *Implementing Domain-Driven Design*
(2013), Ch. 3; Khononov, *Learning DDD* (2021), Ch. 4; Newman, *Building Microservices* (2021),
Ch. 4.

---

## How to Use This Guide

For each relationship line on the Context Map, answer the questions in order. Stop at the first
branch that matches — do not continue to later branches as if they might override an earlier match.

Record your answers in the Pattern Selection Rationale table in the Context Map artifact.

---

## Step 1: Is the Other System an External Third Party or a Legacy System You Cannot Modify?

**External third-party APIs** include: Google Drive API, AWS S3 API, Office 365 / Microsoft Graph,
any SaaS vendor API, any API owned by an organization other than your own.

**Legacy systems you cannot modify** include: existing systems with no living owner, systems with
no safe refactoring surface, systems whose API is effectively frozen.

**If YES to either →** The answer is **Anti-Corruption Layer (ACL)**.

This is not a judgment call. It is a rule. The upstream's vocabulary is, by definition, not
aligned with your downstream's Ubiquitous Language — the upstream was designed for its own
context, not yours. An ACL is the only pattern that protects the downstream's model integrity
against an upstream it cannot influence.

No further steps needed for this relationship. Go to the Output step.

**If NO →** The other system is an internal Bounded Context owned by a team you can reach.
Proceed to Step 2.

---

## Step 2: How Many Downstream Consumers Does the Upstream Serve?

Count the number of Bounded Contexts that consume from this upstream — including both current
consumers and committed future consumers planned within the next 6 months.

**If 3 or more consumers →** Private per-consumer contracts are unmanageable. The answer is
**Open Host Service (OHS) + Published Language (PL)**.

The upstream must publish a versioned protocol (OpenAPI for synchronous; JSON Schema / Avro
for event-driven) that any consumer can read. Each consumer registers a Consumer-Driven Contract
against the OHS. The schema in the Published Language is the cross-context contract.

No further steps needed for this relationship. Go to the Output step.

**If 1 or 2 consumers →** Proceed to Step 3.

**Edge case — 2 consumers considering OHS:** If a second consumer has arrived and private
Customer/Supplier contracts are becoming difficult to coordinate, this is the signal to escalate
to OHS. The decision boundary is not a hard rule at exactly 3 — it is a judgment about whether
private contract negotiation is still tractable. If the two teams' needs have diverged and contract
updates require cross-team coordination that is slowing delivery, escalate to OHS.

---

## Step 3: Does the Upstream Team Have an Obligation to the Downstream?

"Obligation" means: the upstream team has organizational standing to negotiate with, and a
business incentive to honor commitments toward, the downstream team. This is a political question,
not a technical one.

**Signals that an obligation EXISTS:**
- Both teams are in the same department or value stream
- The downstream team can escalate broken contracts to a shared manager or product owner
- The upstream team's roadmap is influenced by the downstream's needs (e.g., the downstream team
  is a paying internal customer in a platform model)
- A Consumer-Driven Contract test would be run and honored in the upstream's CI pipeline

**Signals that an obligation DOES NOT EXIST:**
- The upstream is a shared platform serving dozens of consumers — the downstream cannot demand
  priority
- The upstream team has consistently deprioritized the downstream's needs in past roadmap cycles
- The upstream team is in a different organizational unit with no shared accountability
- Consumer-Driven Contracts were proposed and refused

**If obligation EXISTS →** Proceed to Step 4 (Customer/Supplier path).

**If obligation DOES NOT EXIST →** Proceed to Step 5 (Conformist/ACL path).

---

## Step 4: Customer/Supplier Path

The upstream has an obligation to the downstream. The correct pattern is **Customer/Supplier**
with **Consumer-Driven Contracts** as the enforcement mechanism.

**Mandatory elements of this pattern:**
1. The downstream team writes the contract (what it reads from the upstream) and owns it
2. The upstream's CI pipeline runs the downstream's contract tests before every deployment
3. A failing contract test blocks the upstream's deployment — not a warning, a block
4. The downstream team has a process to update the contract when its own needs change, and the
   upstream commits to reviewing and incorporating those changes within an agreed SLA

**Check: Can Consumer-Driven Contracts be added to the upstream's CI immediately?**

If YES → Implement Customer/Supplier with Consumer-Driven Contracts. This is the strongest form
of the pattern; the relationship is fully governed.

If NO (e.g., the upstream's CI pipeline is locked and cannot be modified) → The relationship is
Customer/Supplier in name but has no enforcement mechanism. Document this as a governance gap and
treat it as a risk. Plan to add the CI gate as soon as the pipeline is accessible. In the interim,
treat the relationship as Conformist (the downstream cannot demand anything) and schedule a
follow-up to close the gap.

**Escalation trigger for Partnership:**
If the two contexts are so tightly coupled that *neither* can be upstream — if changes to either
context's interface require simultaneous changes in the other — and both teams genuinely agree to
coordinate releases, consider **Partnership** as a time-boxed transitional state. This is rare and
should have an explicit exit plan (a date by which the relationship matures to Customer/Supplier
or Shared Kernel).

---

## Step 5: Conformist/ACL Path — The Ubiquitous Language Collision Check

The upstream has no obligation to the downstream. The choice is between:
- **Conformist** — adopt the upstream model as-is; simpler but risks model pollution
- **ACL** — translate the upstream model; more costly to build and maintain, but insulates the
  downstream completely

**Run the Ubiquitous Language Collision Check** for every term the downstream must use from the
upstream:

For each upstream term T that the downstream would need to import:
1. Does the downstream's own Ubiquitous Language assign a different meaning to T?
2. Does adopting T as-is require the downstream's domain layer to carry a concept that does not
   exist in its own Ubiquitous Language?
3. Would adopting T as-is violate any of the downstream's own domain invariants?

**If ANY answer is YES → ACL is required.** Conformist is wrong. The upstream vocabulary is
semantically incompatible with the downstream's model.

**If ALL answers are NO → Conformist is correct.** The upstream model is safe to adopt as-is.
The ACL's translation overhead would be wasteful.

### Worked Example of the Check

**Upstream**: Internal Audit Platform API, exposing `AuditRecord` with fields `recordID`,
`actorID`, `actionType`, `timestamp`, `resourceID`.

**Downstream**: Classification Engine, with Ubiquitous Language terms `ClassificationAuditEntry`,
`Classifier`, `ClassificationAction`, `OccurredAt`, `DataAssetID`.

**Collision check:**
- `AuditRecord` vs. `ClassificationAuditEntry` — different names but structurally compatible.
  Does the classification domain assign a materially different meaning to "audit record"? No —
  an audit record is an audit record in both contexts.
- `actorID` vs. `Classifier` — `actorID` is a generic string; `Classifier` in the downstream is
  a specific concept (could be a user ID or an automated classifier ID). The downstream can safely
  treat `actorID` as the classifier's identifier without a collision.
- `actionType` vs. `ClassificationAction` — the Audit Platform defines a fixed enum of action
  types that does not include "classification" as a distinct value; it uses "UPDATE" for all
  classification events. The downstream needs `ClassificationAction` to distinguish initial
  classification from reclassification, which "UPDATE" does not capture.

**Result:** The `actionType` field fails the check — it carries less semantic precision than the
downstream needs, and adopting it would force the domain to use a concept that cannot represent
a key distinction in the Classification domain. **ACL is required** to translate
`AuditRecord.actionType = "UPDATE"` into the correct `ClassificationAction` enum value by
inspecting additional context fields.

---

## Step 6: Do the Two Contexts Share No Domain Concepts at All?

This check applies after eliminating ACL/OHS/Customer-Supplier paths — it ensures you have not
missed a Separate Ways opportunity.

**Ask:** If this integration were removed entirely, would either context's core use cases be
materially impaired?

**If NO to both sides →** The correct pattern may be **Separate Ways**. The contexts are
independently viable. The integration is a convenience, not a necessity.

**Validate with Event Storming first:** Separate Ways decisions are irreversible in the short term.
Confirm through Event Storming that no domain event from one context is actually required by the
other before committing.

**If YES →** There is a real dependency; one of the upstream patterns (Customer/Supplier, OHS,
Conformist, ACL) applies. Return to Step 2.

---

## Step 7: Is the Other System a Legacy System with No Clear Boundaries?

If the other system has accumulated coupling, has no owner, and cannot be refactored in the
current engagement → name it **Big Ball of Mud** on the Context Map.

This is an honest label, not a failure. The Big Ball of Mud is always accompanied by:
- A plan for how new services integrate with it (always via an ACL — never directly)
- A migration plan that names which capabilities will be extracted first (using Strangler Fig)
- A target-state pattern for each extracted capability (Customer/Supplier or OHS once extracted)

---

## Political Signals That Override Technical Preference

These political signals take precedence over technical judgment. If any apply, they determine the
pattern regardless of what the technical analysis suggests:

| Political Signal | Override |
|---|---|
| Upstream team has refused Consumer-Driven Contracts explicitly | Treat as no-obligation upstream → Conformist or ACL path |
| Upstream is a regulated external vendor with a fixed API | ACL — always; negotiation is impossible by definition |
| Two teams have a shared product manager / joint OKR | Both teams carry mutual obligation → Partnership or Customer/Supplier |
| Upstream team is being sunset / migrated away from | ACL with an explicit migration timeline; do not build any Conformist dependency on a system being decommissioned |
| Organizational restructuring imminent | Defer pattern to Shared Kernel or ACL; avoid any pattern that depends on stable team structure (Partnership) |
| Upstream API is versioned but has broken backward compatibility in the past | Treat as non-cooperative; escalate from Customer/Supplier to ACL |

---

## Output: Pattern Selection Rationale Table

Document each relationship using this format in the Context Map artifact:

```markdown
## Pattern Selection Rationale

| Relationship | Pattern selected | Rationale | CDC required? |
|---|---|---|---|
| [Upstream BC] → [Downstream BC] | [Pattern] | [Answer: why this pattern, what eliminated alternatives] | [Yes / No] |
```

**Required content per row:**
- The relationship direction matters — always state upstream → downstream
- The rationale must name at least one pattern that was considered and rejected, and why
- "CDC required?" is Yes for every Customer/Supplier and OHS relationship; No for all others
  (except note: ACL integrations use integration tests against the upstream API, not CDC, because
  external vendors will not run the downstream's test suite)

See `references/worked-example.md` for a complete filled-in example.
