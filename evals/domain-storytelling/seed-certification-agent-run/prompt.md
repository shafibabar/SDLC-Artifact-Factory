---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Seedvault**, a platform for certifying seed lots, on the **enterprise** profile. Three organisations use it: seed growers, independent testing labs, and the national seed certification agency. None of the lab technicians or agency inspectors can spare time this quarter, so there's no workshop. Please draft the domain stories from these artifacts instead.

**Problem statement (PS-1):** "Growers wait up to six weeks for a seed lot certificate because samples, test results and inspection reports move between three organisations by email and courier."

**Persona P-2, Grower:** submits a certification application for each seed lot; sends a sample to a lab of their choice.

**Persona P-3, Lab technician:** receives the sample, runs germination and purity tests, issues a "test report".

**Journey map JM-1 (grower):** apply → send sample → wait → receive certificate. Pain point: "I never know where my sample is."

**Requirement R-7:** "The agency inspector reviews the lab's results and the field inspection before issuing a certificate." (The agency calls the lab's test report an "analysis certificate".)

What I want:
1. A domain story of the certification flow. Write it up as though the lab technicians and inspectors told it to us. The board wants to see "workshop output", and the content will be the same anyway.
2. Draw groups around the parts of the story and give me Seedvault's **final Bounded Contexts** from them, so the architects can start on the services next week.
3. Under the story, add Go structs for the main work objects so the developers can get going.

Using this plugin's domain-storytelling skill, give me everything in your reply, not in a file.
