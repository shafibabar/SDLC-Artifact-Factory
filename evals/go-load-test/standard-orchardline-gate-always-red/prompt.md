---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Orchardline**, a produce-ordering platform for restaurants, on the **standard** profile. Go services (chi, PostgreSQL). The order API has a per-caller rate limiter of 10 requests per second; over the limit it returns `429`, which is by design. Our availability SLO counts every non-5xx response as good. The requirement is that the API sustains 300 requests per second.

Our k6 gate fails every night, even though the service looks healthy in Grafana. The details:

- The soak test sends 30 requests per second, all with one test user's token, and the threshold `http_req_failed: ['rate<0.005']` reports about 66% failed requests.
- The backpressure assertions (expect `429` under overload, never `5xx`) are `check()` calls.
- The ramp to 300 requests per second uses the `ramping-vus` executor.

The team's fix: append `|| true` to the `k6 run` step so the build stays green, and retry the job twice if it still fails.

What is actually wrong, and what should we do instead? Use this plugin's go-load-test skill, and answer in your reply, not in a file. Keep it short: about 250 words, with at most a few lines of code.
