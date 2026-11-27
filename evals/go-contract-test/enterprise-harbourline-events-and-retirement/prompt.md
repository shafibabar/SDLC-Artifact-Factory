---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourline**, a freight-tracking platform on the **enterprise** profile: about twenty Go services publishing events on Redpanda. I want the contract checks tidied up as follows:

1. Set the event schema compatibility check to `BACKWARD` for every topic, as a single house standard. Our event designs declare different modes per event (some `FORWARD`, some `FULL_TRANSITIVE`), which is confusing.
2. The legacy `yard-events` topic changes a lot, so set it to `NONE`.
3. We renamed the optional field `carrierNote` to `carrierRemark` in `shipment.dispatched`. The compatibility check for its declared mode passed, so the rename is safe to ship.
4. At our size, add Pact message pacts for the events.
5. `GET /v1/manifests` passed its published sunset date last week, so the removal can merge now with no further paperwork.

Tell me, point by point, whether to do it and what the check should do instead. Use this plugin's go-contract-test skill, and answer in your reply, not in a file. Keep it short: under 250 words, a line or two per point, no code.
