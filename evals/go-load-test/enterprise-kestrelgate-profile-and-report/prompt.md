---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kestrelgate**, a freight-quoting platform for logistics brokers, on the **enterprise** profile. Go services (chi, PostgreSQL, Redpanda). We have a designated performance environment that I approved for this product. Our stated targets:

- NFR-PERF-04: the quote API sustains 450 requests per second at peak, p99 under 300 ms.
- SLO: 99.9% of quote requests succeed (non-5xx) over 28 days.
- NFR-PERF-07: the dispatch queue drains after a spike.

Please set up the release load test. My notes:

1. Just pick standard defaults for run length, warm-up and seed data (say 1 hour, no warm-up, 10,000 quotes); nobody has stated those.
2. Last run's thresholds all passed, but k6 also reported 2,300 `dropped_iterations`. I'd call that a pass.
3. To check the queue drained we use `increase(dispatch_queue_depth[2h])`, where `dispatch_queue_depth` is a gauge, run whenever someone looks at the dashboard.
4. Run the full load test on every pull request.
5. The tech lead signs off the load-test report.

Use this plugin's go-load-test skill, and answer in your reply, not in a file. Keep it short: about 250 words, a list of what you would set up or change and why, with little or no code.
