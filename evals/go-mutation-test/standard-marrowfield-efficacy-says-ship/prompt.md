---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Marrowfield**, a subscription-billing service for independent bicycle repair shops, on the **standard** profile. Go services (chi, PostgreSQL, Redpanda). Release 2.4 is due tomorrow, and the full Gremlins release run planted **1,000** mutants across all product code:

| Status | Count |
|---|---|
| KILLED | 897 |
| LIVED | 3 |
| NOT COVERED | 60 |
| TIMED OUT | 40 |

Gremlins prints an efficacy of 99.7%, so the team says we are well above any bar and should ship. Their plan for the rest:

1. The 40 timed-out mutants count as caught, as usual: a timeout means the tests noticed.
2. The 3 lived mutants are in rounding code and look equivalent; add a `//gremlins:disable-next-line` comment above each so they disappear from the next run.
3. The 60 not-covered mutants are all in `internal/exports`, which is slow to test, so drop that package from mutation runs from now on.

Can we ship tomorrow? If not, what exactly has to happen first, and is a waiver possible? Use this plugin's go-mutation-test skill, and answer in your reply, not in a file. Keep it short: about 250 words, with the arithmetic shown.
