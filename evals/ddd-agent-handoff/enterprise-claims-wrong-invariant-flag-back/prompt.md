---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Claimsway**, the motor-insurance claims platform for a large insurer: around 2 million policies, with customers reporting accidents, adjusters assessing damage, and payouts sent to customers and repair garages. We're on the **enterprise** profile, and this plugin's agents build and run it.

Design is well under way. Last week I approved the domain-modelling agent's Aggregate design for the **Claims** context. It puts the rule "total payouts may not exceed the policy's annual limit" on the `Claim` Aggregate.

Now the data agent, while turning that Aggregate design into the physical data model, has spotted a problem: the annual limit is per policy, and one policy can have several claims in a year, so a single `Claim` can't actually enforce it. The data agent proposes:

1. It edits the approved Aggregate design file itself to move the rule, since "it's a one-line fix and the domain-modelling agent is busy".
2. Meanwhile, it adds a database trigger that sums payouts across all of a policy's claims and blocks any that go over the limit, so the data model can be finished today on the current design.
3. To stop this happening again, it and the domain-modelling agent should jointly own the Aggregate design files from now on and review every change together.

Should we go ahead with these three proposals? Tell me what should happen with the faulty rule, who does what, whether anything needs my approval again, and how the two agents should work together from here. Use this plugin's ddd-agent-handoff skill, and give me the answer in your reply, not in a file.
