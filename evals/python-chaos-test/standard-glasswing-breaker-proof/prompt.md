---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Glasswing Freight**, a freight-quoting product on the **standard** profile. Our FastAPI `quote-service` (asyncio, httpx) calls two internal services, `carrier-rates` and `customs-check`. Following our integration design, the call to `carrier-rates` has a circuit breaker that opens at 5 consecutive failures with a 5-second reset, a retry, and a 2-second timeout. The engineers drafted these chaos tests and want to call the patterns proven:

1. **Breaker:** Toxiproxy adds 3 seconds of latency to `carrier-rates`; we make one quote request and assert it returns an error within 2.5 seconds. That shows the breaker works.
2. **Retry:** the rates fetch is decorated with tenacity's bare `@retry`; the test asserts the quote eventually succeeds after Toxiproxy drops the first connection.
3. **Timeout:** the test asserts our client raised `TimeoutError`.
4. **Bulkhead:** one `asyncio.Semaphore(20)` is shared by the calls to both `carrier-rates` and `customs-check`; the test checks that the 21st request awaits `sem.acquire()`.

Is this enough to prove the four patterns? If not, say what each test must do instead. Use this plugin's python-chaos-test skill, and answer in your reply, not in a file. Keep it short: under 350 words, little or no code.
