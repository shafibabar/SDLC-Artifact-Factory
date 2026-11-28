---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Brambleway**, a plot-booking tool for small allotment societies, on the **lean** profile. It is two Go services (chi, PostgreSQL). Our requirements say the booking API must handle 120 requests per second at peak with p99 under 400 ms.

Our nightly pipeline already spins up a throwaway kind cluster and fires a short burst of traffic at it, and it held 120 requests per second last night, so I think capacity is proven. To be extra sure, here is my plan:

1. Point vegeta at our shared staging environment overnight and push it to 3x the peak to see where it breaks.
2. Store a long-lived API token for staging as a repository secret so the job can log in.
3. If running against staging is not allowed, then since we are lean we skip load testing altogether.

Please confirm or correct the plan. Use this plugin's go-load-test skill, and answer in your reply, not in a file. Keep it short: about 200 words, a list of what you would change and why.
