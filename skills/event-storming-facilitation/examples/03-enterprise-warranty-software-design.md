# Example 3 — Enterprise: Software Design across regions, aggregates versus contexts, hotspots routed (hardest case)

Self-contained. **Halden Appliances** runs warranty claims for its washing machines and ovens in the UK, Germany and Spain, at the **enterprise** profile. A human Big Picture was held with claims handlers from each region and the repair-network manager; Process Modelling covered "claim to repair". The domain-modeler now runs Software Design on that process. "Parts reimbursement to repair agents" has **not** been through Process Modelling.

## Input

> **User:** "We'd like one Claim aggregate per region that holds everything: the claim, the appliance, the repair visit, the parts and the payment to the agent. Same for parts reimbursement. And please give us the code structure."

## Working it

**Two boundaries, two forces.** An aggregate's boundary is a rule that must hold at every instant; a Bounded Context's is where the language changes. A region is neither: it is a deployment and legal concern.

**Aggregates, by true invariant** (Vernon's test: would a momentary violation do harm no later correction fixes?):

| Candidate | Invariant at every instant | Verdict |
|---|---|---|
| Claim | A claim is accepted only if the appliance is within warranty on the fault date; one open claim per appliance and fault | Aggregate |
| Repair Visit | One agent per visit; a visit can't be completed before it starts | Aggregate |
| Appliance (serial, purchase date) | Changes rarely; referenced by the claim | Referenced by identity, owned elsewhere |
| Agent payment | Must follow a completed visit, but can lag | Eventual consistency via `RepairCompleted`; not inside Claim |

**Contexts, by language.** Claims handlers say "claim", "fault", "cover". The repair network says "job", "visit", "agent", "part fitted". "Job" in Repair is what "claim" is in Claims, but with different rules: a job can be reassigned, a claim's acceptance can't be undone. So there are two **Bounded Context candidates**, Claims and Repair Network, confirming the Big Picture's pivotal event `RepairBooked`. Regions differ in rules (Germany's statutory warranty period), not in language, so they are configuration within Claims, not contexts of their own.

**Parts reimbursement:** not modelled yet, so no aggregates. It goes to Process Modelling first.

**Code:** none here. Design stays stack-neutral; the implementation skills produce code later.

**Hotspots from the session, routed:**
- "Who decides cover when the purchase date is missing?" → the product owner (a rule).
- "Claims handlers in Spain say 'garantía' for both statutory and extended cover" → the Claims Ubiquitous Language (a language question).
- "Peak load after a recall: 20× claims in a day" → `architecture-evaluation` (a quality-attribute risk).

## Output — the reply

> I'd split this differently. A Claim aggregate holds only what must be consistent at every instant: whether the appliance is covered on the fault date, and one open claim per fault. The repair visit is its own aggregate, the appliance is referenced by its serial number, and the agent payment follows the completed repair through an event rather than sharing a transaction. Regions aren't boundaries: the three countries share one language for claims and differ only in rules, so those rules are configuration inside the Claims context. The real boundary is between Claims and the Repair Network, where "claim" becomes "job" with different rules. Parts reimbursement hasn't been through Process Modelling yet, so I haven't designed it. That's the next session. Code comes later, from the implementation skills. Three hotspots go on: the missing-purchase-date rule to you, the Spanish "garantía" question to the Claims language, and the recall peak to the architecture evaluation.

**`artifacts/halden/design/event-storming/design-level.md`** (extract):

```markdown
## Aggregates (consistency units)

| Aggregate | Commands handled | Events emitted | Invariant that must hold at every instant | Source |
|---|---|---|---|---|
| Claim | SubmitClaim, AcceptClaim, RejectClaim | ClaimSubmitted, ClaimAccepted, ClaimRejected | Accepted only if within warranty on the fault date; one open claim per appliance and fault | session 2026-06-10 |
| RepairVisit | BookVisit, StartVisit, CompleteVisit, ReassignVisit | RepairBooked, VisitStarted, RepairCompleted | One agent per visit; completion only after start | session 2026-06-10 |

## Bounded Context Candidates

| Candidate | Aggregates inside | Language change that justifies the boundary | Big Picture hint it confirms |
|---|---|---|---|
| Claims | Claim | "claim", "cover", "fault"; acceptance can't be undone | Swimlane "claims handling" |
| Repair Network | RepairVisit | "job", "visit", "agent"; a job can be reassigned | Pivotal event RepairBooked |
```

## Why this is right

- "One aggregate per region" was refused on both counts: aggregates follow invariants, contexts follow language, and a region is neither.
- An unmodelled process got no aggregates; it was sent to Process Modelling.
- Every hotspot went somewhere specific: the product owner, the language, or the architecture evaluation.
