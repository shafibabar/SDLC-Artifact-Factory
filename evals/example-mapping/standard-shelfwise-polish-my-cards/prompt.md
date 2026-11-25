---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Shelfwise**, a lending system for a group of town libraries, on the **standard** profile. Story US-12: "As a member, I want to place a hold on a book that is out, so that I get it when it comes back." I drafted these cards:

- Rule A: A member can have at most 5 active holds. Example: "A member within the limit places a hold and it works."
- Rule B: A returned book goes to the first member in the queue. Examples: Priya is first for "Dune", it is returned, Priya is offered it. Sam is first for "Emma", it is returned, Sam is offered it. Lee is first for "Ulysses", it is returned, Lee is offered it.
- Rule C: The hold button must respond within 2 seconds (our NFR-PERF-02). Example: click "Place hold", the page calls POST /holds, a spinner shows, it finishes in 1.4 s.

Please just polish the wording, keep every example as its own acceptance criterion, and number them AC-001 onwards. Keep it under 450 words.

Use this plugin's example-mapping skill, and give me the answer in your reply, not in a file.
