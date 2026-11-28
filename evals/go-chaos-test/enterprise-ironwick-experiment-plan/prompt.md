---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ironwick Payments**, a merchant payments ledger on the **enterprise** profile. Go services, PostgreSQL, Redpanda. Chaos experiments run in a kind cluster created for each run. Here is the plan for our first network experiment on the `ledger` service's calls to `fraud-scoring`:

1. Inject 30% packet loss for 10 minutes. Afterwards we look at the Grafana dashboards to judge whether things were fine.
2. An abort watcher polls the error rate every 10 seconds and exits once it goes above 5%.
3. The Chaos Mesh 2.x `NetworkChaos` manifest repeats weekly using `scheduler: { cron: "@weekly" }` in its spec.
4. During the experiment we also send poison messages to prove the Dead Letter Queue works, since this is a good place to test it.
5. The integration design lists a circuit breaker on `fraud-scoring`. I'm not sure it is in the code yet; if it isn't, just add a simple one inside the test so the experiment can check it.

Please correct the plan. Use this plugin's go-chaos-test skill, and answer in your reply, not in a file. Keep it short: under 350 words, with little or no code.
