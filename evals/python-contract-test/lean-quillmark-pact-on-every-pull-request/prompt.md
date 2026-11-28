---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quillmark**, an invoicing tool for freelance writers, on the **lean** profile. It is two Python (FastAPI) services: `invoicing` calls `payments` directly over HTTP (`POST /charges`, with a bearer token that `payments` checks in middleware). Both already compare their API description on every pull request. I'm now deciding what to do about Pact, and my plan is:

1. Skip Pact for now. We are lean, one person, two services; I'll write a decision record to adopt it if a second team ever appears.
2. If we do adopt it, use PactFlow's hosted plan so there is no broker to run.
3. Run provider verification on every pull request to `payments` and block the merge when it fails.
4. Deploy `payments` whenever its own pipeline is green; the description check is enough for deployment.
5. For provider verification, switch the token-checking middleware off with a test flag, or else save a long-lived service token in the pact file so the replayed request gets through.

Tell me which of these five stand and what replaces the ones that do not. Use this plugin's python-contract-test skill, and answer in your reply, not in a file. Keep it short: at most 300 words, one or two lines per point, no code needed.
