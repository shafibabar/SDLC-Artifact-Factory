---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Driftwell**, a marina berth-booking platform on the **standard** profile. Its quote service is FastAPI on uvicorn and has its own rate limiter. Our SLO for `POST /quotes` is: "99.5% of requests complete in under 800 ms, and fewer than 0.5% fail". Last night's load gate went green, but customers reported slow quotes. Our team set it up like this:

1. In the locust script, the `/quotes` task uses `catch_response=True` and calls `response.success()` on a 429, "because rate limiting is expected behaviour".
2. The gate checks p99 under 800 ms, since our tool's report has no 99.5 column.
3. Users use `wait_time = constant_throughput(2)`, which the team says makes this an open-model test.
4. The gate script reads the results of our "ramp" run, the one that pushes load up until the service breaks, because it has the most data.
5. The CI step is `locust ... || true` with up to three retries, so a noisy night doesn't turn the build red.

Why could the gate pass while customers saw slow quotes, and what should change? Use this plugin's python-load-test skill, and answer in your reply, not in a file. Keep it short: about 300 words, one or two lines per point. No full script needed.
