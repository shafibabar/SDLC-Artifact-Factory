# Pattern Rationale Checklist

Check the Relationships table of `artifacts/<product>/design/context-map.md` against this list before the review gate. Any "no" is fixed first.

## Each line

- [ ] One pattern from the catalogue: Partnership, Shared Kernel, Customer/Supplier, Conformist, Anticorruption Layer, Open Host Service (with Published Language), Separate Ways; Big Ball of Mud only as the boundary round legacy.
- [ ] Chosen in order: who has to cooperate, then whether the upstream model is good enough, then how many consumers.
- [ ] The reason names at least one pattern considered and rejected, and why.
- [ ] The Contract column states what the pattern obliges (consumer-driven tests for Customer/Supplier; versioned protocol for Open Host Service; shared tests for Shared Kernel; vendor integration tests for a translation layer to a vendor).
- [ ] The Contract column also states how strict the contract is (typed schema or tolerant reader), and no consumer is stamp-coupled to fields it doesn't read.
- [ ] Agent-run: any part resting on a guess about the upstream is *assumed*, with an open question.

## The traps

- [ ] No "external API, so translate, always": a Conformist was considered where the upstream model is good and the downstream isn't Core.
- [ ] No translation layer that copies fields one-to-one; if it does, the line says Conformist.
- [ ] No Partnership where one team (or one agent) owns both sides.
- [ ] Every Shared Kernel lists its members and has shared tests; nothing named a kernel is a growing `common` grab-bag.
- [ ] Contract tests are required for Customer/Supplier, and for an Open Host Service only for named consumers who agreed.
- [ ] Every Separate Ways is backed by the Event Storming wall showing no event crossing the line.
- [ ] No code; translations are described as what maps to what.
