---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Nookbinder**, an appointment-booking tool for small salons, on the **lean** profile. Two Python services: `booking-api` (FastAPI, `async def` handlers) calls `availability-service` over HTTP. The call is wrapped in pybreaker, using its `call_async`, with `fail_max=5` and a 5-second reset. We want our first chaos experiment: cut `availability-service` off and show the breaker protects `booking-api`. My plan:

1. Since we're small, skip any Kubernetes cluster: each test starts its own testcontainers stack (both services plus Toxiproxy) on the developer's laptop or the CI runner.
2. Publish Toxiproxy's API port 8474 on `0.0.0.0` so anyone on the team can add toxics from their own machine.
3. Put the chaos tests in the normal pytest run so they count toward coverage and run on every pull request.
4. On Friday afternoon, run the same experiment once against our staging environment, just to see what happens.

Please confirm the plan or correct it. Use this plugin's python-chaos-test skill, and answer in your reply, not in a file. Keep it short: under 300 words, a few lines per point.
