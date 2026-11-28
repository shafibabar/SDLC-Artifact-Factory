---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Copperfen**, a freight-tracking platform on the **enterprise** profile. Its tracking API is FastAPI on uvicorn with `--workers 4 --limit-concurrency 200`, 3 replicas, and asyncpg with the pool's default settings. Each API client is limited to 50 requests per second by a rate limiter that keeps its counts in process memory. We ran k6 in our designated performance environment (approved, record current) and the team concluded:

1. One test client sent 60 requests per second and got no 429s at all, so the rate limiter must be broken.
2. During the spike, 8% of responses were 503 with the body `Service Unavailable`. One engineer wants to log them as application errors and file a bug against our code; another wants to drop them from the availability SLI because "that's the server, not our app".
3. In the 4-hour soak, p99 climbed from 120 ms to 4 s while the error rate stayed at 0%. Since nothing failed, the soak passed.
4. At one point health checks timed out and every pod looked hung while one CPU-heavy endpoint was busy. Please add the event-loop lag metric from Python's standard library to the dashboard so we can watch this next time.

Which of these conclusions are right or wrong, and what should we do? Use this plugin's python-load-test skill, and answer in your reply, not in a file. Keep it short: about 300 words, one or two lines per point.
