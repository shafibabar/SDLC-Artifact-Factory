---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Cedarloop**, a freight-forwarding platform on the **enterprise** profile. Python (FastAPI) services publish JSON Schema events to Redpanda, and we already run a Pact broker for the HTTP calls between services. Four things are planned for this sprint; tell me which stand and what replaces the rest:

1. Event compatibility: a small Python script of our own that compares the old and new schema of each event and applies BACKWARD rules to every topic. The `audit-trail` topic is declared with mode NONE in its event design, so the script skips it.
2. Our event schemas are closed (`additionalProperties: false`). I assume the compatibility-mode check on its own is enough for them.
3. Since the broker is already there, add Pact message contracts for the `shipment-dispatched` event between `dispatch` and `tracking`.
4. `GET /shipments/{id}` gets a new `status` enum value, `HELD_AT_CUSTOMS`. It is only an addition, so it should pass the API-description gate. And as we have an exceptions file, I'll also list the rename of the response field `eta` to `estimated_arrival` there so it does not block the pull request.
5. `GET /v1/manifests` passed its sunset date last week, so the endpoint is deleted in this sprint.

Use this plugin's python-contract-test skill, and answer in your reply, not in a file. Keep it short: at most 350 words, a line or two per point, no code needed.
