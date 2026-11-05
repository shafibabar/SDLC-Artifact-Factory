# Example 3 — Enterprise: a pass-through translator diagnosed, and a `common` "kernel" dissolved (hardest case)

Self-contained. **Corbel Freight** runs container terminals in three ports, at the **enterprise** profile, with three human teams after launch. A review of the existing design finds two problems. First, a "translation layer" between the **Berth Planning** context (Core) and the port authority's vessel-call system (external, unstable, changes its feed twice a year) that maps every field one-to-one. Second, a `terminal-common` package that every context imports, with 22 types and growing.

## Input

> **User:** "Review these two. The translator is our ACL, and `terminal-common` is our Shared Kernel, so both are fine, aren't they?"

## Working it

**The translator.** It copies `VesselCall`, `ETA` and `Berth` from the authority's feed into identically named types with the same meanings. That is Conformist with extra code: it translates nothing. Here the line *does* need a real translation:
- Berth Planning is Core;
- the authority's feed churns;
- "ETA" in the feed is the vessel's own estimate, while Berth Planning's plan works from "pilot-on-board time", a different moment.

So the fix is to make it a real Anticorruption Layer, mapping the feed's ETA to Berth Planning's arrival window with the rule between them, not to delete it. (Had nothing differed, the fix would be to call it Conformist and remove the layer.)

**`terminal-common`.** A Shared Kernel is small, listed, changed only by agreement and covered by shared tests. This one has 22 types that anyone extends, used by contexts owned by three different teams. Weighing duplication against coordination:
- **Keep shared:** only `ContainerNumber` (an international standard format) and `PortCode`. Both are stable, used everywhere, and costly to get wrong if duplicated.
- **Move back into each context:** the rest. `Container`, `Booking` and `Yard Slot` mean different things in Yard Operations and in Gate.
- **Write down the kernel's membership:** two members, with shared tests, changed only by agreement of all three owning teams.

## Output — the reply, and the Relationships rows

> Neither is what its name says. The translator copies every field one-to-one, so it protects nothing: it's Conformist with extra code. This line needs real translation, though. Berth Planning is Core, the authority's feed changes twice a year, and the feed's "ETA" isn't the moment Berth Planning plans from. So I'd keep the layer and make it translate ETA into the arrival window, rather than delete it. `terminal-common` isn't a Shared Kernel either. A kernel is small and listed, and this one has 22 types anyone can extend. I'd keep two genuinely shared ones (`ContainerNumber`, `PortCode`) with shared tests, and move the rest back into the contexts that mean different things by them.

```markdown
| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| Port Authority Vessel Feed | Berth Planning | Anticorruption Layer | Berth Planning is Core, the feed churns twice a year, and the feed's ETA means a different moment than Berth Planning's arrival window; Conformist rejected because those meanings differ. The existing pass-through translator is replaced by one that translates ETA to the arrival window | Integration tests against the authority's feed; the authority won't run our tests. Loose at the feed (tolerant reader, since it changes twice a year), strict inside the translation |
| Yard Operations | Gate | Shared Kernel | `ContainerNumber` and `PortCode` only: stable, used by both, and costly to get wrong if duplicated; the wider `terminal-common` was rejected as a growing grab-bag | Shared tests both sides run; members listed; changed only by agreement. Strict: two typed value formats |
```

## Why this is right

- The pass-through test was applied both ways: the layer was kept and made real here because the meanings differ, and the alternative (call it Conformist) was stated for the case where they don't.
- The kernel was cut down by weighing duplication against coordination, with the survivors listed and given shared tests.
- Every row names what was rejected and states the contract the pattern obliges.
