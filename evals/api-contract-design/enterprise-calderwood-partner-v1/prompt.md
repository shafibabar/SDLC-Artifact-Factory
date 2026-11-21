---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Calderwood Telecom**'s partner API, which resellers use to look up and activate mobile subscriptions. It is a public, partner-facing API on the **enterprise** profile, with about 40 partner integrations, some of which release only twice a year. The Subscriptions API is live as v1. My requests:

1. Legal wants the `nationalIdNumber` field gone from the v1 subscription response. Just drop it from v1 so we are compliant today.
2. We then plan to retire the old shape. Give partners a two-week deprecation notice, since the business wants it done fast.
3. To be safe against double charges, require an `Idempotency-Key` header on every endpoint: GET, PUT, DELETE and POST alike.
4. Our team is busy, so they will build the endpoints first and generate the OpenAPI document from the code once the API is stable.

Please do the API contract design review for the Subscriptions API. Use this plugin's api-contract-design skill, and give me the answer in your reply, not in a file.
