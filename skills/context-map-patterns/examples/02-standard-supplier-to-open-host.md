# Example 2 — Standard: Customer/Supplier with contract tests, moving to Open Host Service at the fourth consumer

Self-contained. **Fleetwise** runs maintenance for a city's bus fleet, at the **standard** profile. The agents build it, but after launch two of the operator's own teams own parts of it: the fleet records team owns the **Vehicle Register**, and the depot team owns **Workshop Scheduling**. The **Vehicle Register** context is the record of every bus and its fitments. Today two contexts read it: **Workshop Scheduling** (Core) and **Parts Ordering**. Next quarter a **Fuel Reporting** context and the transport authority's **inspection portal** (external) will read it too.

## Input

> **User:** "Make everything Customer/Supplier with contract tests on every reader, including the authority's portal."

## Working it

- **Question one, who has to cooperate:** two real teams on the Register–Workshop line, and the fleet records team has agreed to plan around the depot's needs. That's a Customer/Supplier commitment. Parts Ordering and Fuel Reporting belong to no separate team, so nobody negotiates there: those lines are decided on model quality. The authority's portal is a separate organisation with no commitment either way.
- **Question two:** Vehicle Register's model is clean, but Workshop Scheduling is Core and needs fitments described in its own terms (a "bay-ready" state the register doesn't have): it translates. Parts Ordering can conform.
- **Question three, consumers:** two today, four next quarter, one of them external and not under our control. Private per-consumer arrangements won't scale to that; at the fourth consumer the register publishes **one protocol** (Open Host Service with a Published Language), separating its internal model from its public one.
- **Contracts:** contract tests only where a named consumer has agreed terms (Workshop Scheduling today). The authority's portal gets the versioned, documented protocol; it won't run our tests, and we can't run theirs.
- **Contract strictness** (Ford): the published vehicle schema is strict and typed; Parts Ordering reads three fields with a tolerant reader, so it isn't coupled to the rest of the structure.

## Output — the Relationships rows, today and after the trigger

```markdown
| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| Vehicle Register | Workshop Scheduling | Customer/Supplier | Workshop Scheduling is Core and has needs the register commits to; Conformist rejected because its "bay-ready" state isn't in the register's model | Consumer-driven contract tests from Workshop Scheduling, run in the register's pipeline |
| Vehicle Register | Parts Ordering | Conformist | The register's model is good enough and Parts Ordering isn't Core; Customer/Supplier rejected as unneeded negotiation | None; reads three fields with a tolerant reader |
```

**Trigger, recorded in the reason column now:** "Move Vehicle Register to Open Host Service with a Published Language when the fourth consumer (the authority's portal) signs." After it:

```markdown
| Vehicle Register | (all consumers) | Open Host Service | Four consumers, one external; one public protocol instead of a translator per consumer; Customer/Supplier per consumer rejected as unmanageable at this count | Versioned protocol with deprecation windows for all consumers; contract tests kept for Workshop Scheduling, a named consumer |
```

## Why this is right

- Contract tests went where a named consumer has agreed terms, not to every reader; the external portal relies on versioning.
- The move to Open Host Service has a stated trigger, rather than being built early or discovered late.
- Strictness was judged separately from the pattern: a tolerant reader keeps Parts Ordering loosely coupled.
