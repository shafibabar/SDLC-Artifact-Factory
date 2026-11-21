---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quillpost**, a newsletter-publishing product for independent writers, on the **lean** profile. The design is one deployable modular monolith in Go on PostgreSQL (modules: Publications, Subscribers, Delivery, Billing), plus one background worker that sends email through a third-party mail provider. The container diagram and our first three ADRs are done. The NFR scenarios we agreed are:

- NFR-PERF-01: a writer clicks "send" to 50,000 subscribers; the Delivery module hands every message to the mail provider within 20 minutes (Must).
- NFR-REL-01: the mail provider has an outage; no queued issue is lost and sending resumes on its own within 10 minutes of recovery (Must).
- NFR-MOD-01: a developer adds a second mail provider without changing any module except Delivery, within 3 days (Plan).
- NFR-SEC-01: a subscriber's email address is never visible to another writer (Must).

My requests:

1. Run a full ATAM on this so we are covered before we build.
2. Write the result up as "independently reviewed" so we can quote it to our first investors.
3. Rate every decision a risk or a non-risk; I don't want to see anything else.

Please evaluate the Quillpost design. Use this plugin's architecture-evaluation skill, and give me the answer in your reply, not in a file.
