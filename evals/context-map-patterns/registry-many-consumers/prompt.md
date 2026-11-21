---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Aquaplan**, an asset-maintenance platform for a regional water utility (pipes, pumps, reservoirs, treatment works). We're on the **enterprise** profile. Unlike our smaller products, this one has several real human teams who will own it after launch.

The **Asset Registry** context (owned by the asset data team) is the record of every asset, its location, condition grade and maintenance history. Its model is careful and well liked. Who reads from it:
- **Work Orders** (the field operations team, Core). The asset data team has agreed to plan its releases around what Work Orders needs, and the two teams meet every sprint.
- **Capital Planning** and **Regulatory Reporting** (two other internal teams).
- **Three external contractor firms**, whose systems we don't see, plus any approved contractor who signs up later to the asset feed.
- Two more internal dashboards the analytics team is building.

The architect's draft proposes:
1. A separate, hand-built translator inside Asset Registry for each consumer, "so each one gets exactly the shape it wants."
2. **Consumer-Driven Contract tests for every consumer** of the registry, internal and external, "with every consumer's contract running in the registry's build, so nothing can ever break anyone."
3. The same relationship pattern on every line, "Customer/Supplier, because that's what we always use."

Tell me which relationship pattern belongs on each kind of line out of Asset Registry, how you got there, and which of those lines actually need contract tests. Use this plugin's context-map-patterns skill, and give me the answer in your reply, not in a file.
