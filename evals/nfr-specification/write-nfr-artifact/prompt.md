---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Ideate on the **standard** profile for **Tidepool**, lesson-booking software for public swimming pools that run children's swimming lessons (about 30 pools on one shared service). Our functional requirements document (ideate/requirements.md) is approved. Its relevant parts:

- **Quality-Attribute Hand-off:** QA-1 "how quickly a swap shows in the instructor's register" (constrains FR-1.2; the coordinator said swaps must show up "instantly"); QA-2 "availability of booking and swaps" (all URs; the coordinator said "the system must be up 99.9% of the time"); QA-3 "parents of one pool must never see another pool's children" (FR-1.1, FR-2.1).
- **Business Rules:** BR-1 a class never exceeds 8 children; BR-2 a child may only swap into a class at their own level; BR-4 children's personal data is stored and processed only in the UK (the pools' data-protection policy).
- Context: swaps peak on Sunday evening 18:00–20:00 when the weekly lesson message goes out (up to 1,500 parents across all pools); lessons run 07:00–20:00.

Using this plugin's nfr-specification skill, write the NFR specification artifact (in your reply, not to a file).
