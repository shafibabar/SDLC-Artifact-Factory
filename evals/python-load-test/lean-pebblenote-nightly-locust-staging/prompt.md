---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pebblenote**, a shared shopping-list app for households, on the **lean** profile. It is one FastAPI service run by uvicorn on PostgreSQL. Our NFR-2 says: "the list API sustains 40 requests per second at p95 under 300 ms". The nightly CI run already deploys the service into a throwaway kind cluster. Here is my plan for load testing:

1. Keep our existing locust file. We're a Python team, so a Python load tool makes sense. It starts 200 users, each waiting `between(1, 3)` seconds between requests, which should come out at about 40 requests per second.
2. Run it nightly in the kind cluster. If it passes, we mark NFR-2 as met. Because we're lean, we don't need a separate performance environment.
3. Before launch, run the same file once against our shared staging environment to be extra sure, using the `STAGING_API_TOKEN` we keep in the repository's CI secrets.

Please review this plan and tell me what you would change. Use this plugin's python-load-test skill, and answer in your reply, not in a file. Keep it short: about 250 words, a short list of changes with a reason for each. No full script needed.
