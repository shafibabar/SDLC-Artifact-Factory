---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Fernpost**, a newsletter billing tool on the **lean** profile. It has two Go services: `subscriptions` calls `billing` directly over HTTP to create a charge. Both have OpenAPI descriptions and a breaking-change check on every pull request.

An engineer friend told me a lean product should skip Pact until it grows, and that adopting it would need a written architecture decision first. If you disagree, here is how I would want it:

1. Use PactFlow's hosted service so we do not have to run a broker ourselves.
2. Run the Pact verification on every pull request, so a breaking change can never be merged.
3. Once Pact is in, delete the OpenAPI breaking-change check, since Pact covers the same ground.

Also tell me what stops a version of `billing` that breaks `subscriptions` from being deployed.

Use this plugin's go-contract-test skill, and answer in your reply, not in a file. Keep it short: under 250 words, a line or two per point, no code.
