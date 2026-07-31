# Risk-Driven Design — Fairbanks' Method and How the Register Feeds Design

Reference material for the `risk-register` skill. Load this when deciding how much design and
mitigation effort a risk deserves, whether a risk is architecturally significant, and how a
register entry connects to `adr-authoring` and downstream design decisions. Grounded in George
Fairbanks, *Just Enough Software Architecture: A Risk-Driven Approach*, applied to this repo's
Go / chi / pgx / Redpanda / Apache AGE, physically multi-tenant, compliance-oriented stack.

---

## 1. The central thesis: scale effort to risk

Fairbanks' argument is that most architecture guidance pushes toward one of two wrong defaults:
exhaustive up-front design (Big Design Up Front) or reflexive "just start coding." Both are wrong
as universal rules. The right discipline is a **decision, made per risk**, about how much
deliberate design and mitigation effort it warrants.

Two failure modes sit at the extremes, and the register guards against both:

- **Under-investment:** hacking on a decision that turns out expensive to unwind.
- **Over-investment:** heavy modeling and mitigation on a risk that is cheap to reverse and
  narrowly depended-upon — "over-engineering is as much a risk-management failure as
  under-engineering."

This is the sharpened mechanism behind this repo's Budget and Frugality principle ("prefer simpler
solutions when outcomes are equivalent"): outcomes are *equivalent enough* to take the cheap path
precisely when the risk is cheap to change and narrowly depended-upon.

## 2. The Risk-Driven Model (RDM): identify → select → evaluate

Fairbanks' concrete loop, applied to a register entry:

1. **Identify risks.** For a candidate decision or condition, ask what could go wrong, how
   expensive it would be if it did, and how much is genuinely unknown or contested about the
   right answer. This is where a register entry is born — likelihood and impact are the two
   quantities being weighed. Fairbanks draws this directly from Barry Boehm's spiral model
   (risk-driven iteration), narrowed to the question of *architectural* effort.
2. **Select proportional techniques.** Choose the *cheapest* technique that actually reduces the
   risk. Fairbanks' point is that the technique is chosen to match the risk, not applied
   uniformly. A high-severity, high-uncertainty risk earns a model, a prototype/spike, and a
   documented decision (an ADR); a low-severity risk earns a note and nothing more.
3. **Evaluate.** Confirm the technique actually reduced the risk — did the spike resolve the
   uncertainty, did the mitigation lower likelihood or impact? If a risk still sits at the same
   severity after the chosen technique, either the technique was wrong or the risk is being
   accepted. This maps onto the register's status lifecycle: `open` → `mitigated` is exactly
   "we evaluated and the exposure dropped but did not vanish."

The register is the persistent record of this loop running continuously across phases, rather than
a one-time up-front exercise.

## 3. The architecturally-significant-risk criterion

An element or decision is **architecturally significant** when either:

- **(a) it would be expensive to change** once other work depends on it, or
- **(b) many other decisions depend on it**, so getting it wrong propagates broadly.

Applied to risks: **an architecturally-significant risk is one that, if left unmitigated, could
force a costly re-design.** That is the criterion that promotes a register entry from "watch it"
to "invest deliberate mitigation and record the decision." Subject matter does not decide
significance — cost-of-change and breadth-of-dependency do. A flashy-sounding risk that is cheap
to reverse is *not* architecturally significant; a mundane-sounding schema choice that a dozen
consumers depend on *is*.

### The Architecture Bullseye

Fairbanks' well-known **Architecture Bullseye** makes this a picture: concentric rings with the
highest-priority-for-design-effort elements at the **center** (broadly depended-upon, expensive to
change, poorly understood, or risk-bearing) and progressively lower-priority elements toward the
**rim**, where "just write it and see" is the correct, deliberate choice. The bullseye is a triage
tool, not a completeness checklist — its point is to justify spending *less* effort on the outer
rings just as much as more on the center. Run it as a literal pass: for each register entry, place
it in a ring before deciding how much mitigation, modeling, or ADR effort it gets. A rim entry
that gets an ADR anyway is the over-investment Fairbanks explicitly warns against.

The severity matrix in `references/register-template-and-scoring.md` is this repo's operational
proxy for the bullseye: `Critical`/`High` severity ≈ center rings (deliberate mitigation + ADR),
`Low` ≈ rim ("hack it, watch it, don't over-engineer").

## 4. How the register feeds `adr-authoring`

The register and the ADR log are complementary records that reference each other:

- **A `Critical`/`High` register entry is the usual trigger for an ADR.** When a
  architecturally-significant risk is mitigated by a design decision (choosing physical isolation
  to bound a tenant-breach risk; choosing idempotent consumers to bound a duplicate-event risk),
  that decision is recorded as an ADR, and the ADR's context section cites the `RISK-NNN` it
  addresses. `adr-authoring`'s "When to Write an ADR" gate (non-obvious / consequential /
  contested / cross-cutting) is sharpened by Fairbanks' quantities: a decision that is cheap to
  change and narrowly scoped should *not* get an ADR even if mildly non-obvious.
- **The register cites the ADR back.** A risk's mitigation strategy names the ADR that implements
  it (e.g. RISK-004's "idempotent consumers per ADR-002"), so a reader moving in either direction
  can trace risk ↔ decision.
- **Numbering discipline is shared.** `RISK-NNN` is product-scoped, sequential, and never reused —
  the same discipline as ADR numbering. Closed/accepted risks stay in the register just as
  superseded ADRs stay in the log; both are part of the auditable record.

## 5. How the register feeds downstream design decisions

- **Design phase (`enterprise-architect`, `security-architect`):** severity is a budget signal for
  the architecture. A `Critical` compliance or tenant-isolation risk justifies proportional
  design investment (isolation verification, control mapping); a `Low` technical risk justifies a
  note, not a re-architecture. The granularity and coupling stress-tests from *Software
  Architecture: The Hard Parts* are the kind of proportional technique the RDM's step 2 selects
  when a boundary or integration carries a high-severity risk — run the disintegrator/integrator
  checklists against a service boundary that a `High` risk flags, not against every boundary.
- **Quality phase:** a high-severity risk should be traceable to a test or fitness function that
  detects its materialization (RISK-001's adversarial fixtures; RISK-003's synthetic-large-estate
  load test). "Evaluate" (RDM step 3) is where that test earns its place.
- **Deploy / operations:** operational risks (RISK-004) map to runbooks, alerts, and SLOs — the
  mitigation is monitoring, and the review cadence is where an on-call reality-check happens.

## 6. Cautions when applying Fairbanks here

- Fairbanks predates this repo's DDD/Bounded-Context vocabulary; his examples are generic
  OO/UML. The mapping of his risk criterion onto Bounded Contexts, Domain Events, and Aggregates
  is this repo's own extrapolation, not literal book content.
- The book is light on multi-tenant, cloud-native, and distributed-systems-specific risk examples.
  Use Fairbanks for the **decision procedure** (when to invest), and this repo's own NFR,
  multi-tenancy, and integration content for **which** risks the product context should weigh.
- "Hacked, not designed" is a legitimate, *conscious* choice for a `Low`-severity risk — record it
  as a deliberate low-investment decision (even a one-line note in the entry), not a silent skip,
  so the risk-driven decision itself stays auditable.
