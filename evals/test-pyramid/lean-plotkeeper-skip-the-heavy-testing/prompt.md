---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Plotkeeper**, an app that rents out allotment plots and collects the rent, on the **lean** profile. It is one Go modular monolith on PostgreSQL with a third-party payment provider. We have two agreed NFRs:

- NFR-PERF-01: the quarterly rent run issues invoices to 2,000 plot holders within 10 minutes.
- NFR-REL-01: if the payment provider is down, no payment is lost or recorded twice.

I need a short test strategy outline. My instructions:

1. We are tiny, so leave out load, chaos and mutation testing.
2. Split the tests 70% unit, 20% integration, 10% end-to-end, and hold us to that.
3. Make 80% line coverage the merge gate.
4. Add a p99 page response target of 200 ms as a performance gate.

Please use this plugin's test-pyramid skill, and give me the answer in your reply, not in a file. Keep it under about 600 words.
