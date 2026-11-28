---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says one slow call that fails fast does not prove the breaker, because a plain timeout produces the same result. Instead the test drives consecutive failures up to the configured threshold of 5 and asserts the breaker is open at the 5th failure, and that while it is open calls fail fast and `carrier-rates` receives no calls.
2. It asserts the rest of the breaker's states: half-open after the 5-second reset, closed again after a successful call, and open again when the call in the half-open state fails.
3. It says tenacity's bare `@retry` retries forever with no wait, so the retry needs a stop condition (such as a maximum number of attempts or a time limit). The test asserts that bound, for example by counting the attempts that reach `carrier-rates`.
4. It says asserting that the client raised `TimeoutError` is not enough. The test must show the deadline is applied to the call to `carrier-rates` itself, for example that the call is cut off at the 2-second deadline as seen at the dependency.
5. It rejects the one semaphore shared by both downstream services and gives each its own limit, with a test that saturates one and shows calls to the other still succeed. It also bounds the wait to acquire a slot in time, because `asyncio.Semaphore.acquire()` takes no timeout by itself.
Fail if any of the 5 is missing.
