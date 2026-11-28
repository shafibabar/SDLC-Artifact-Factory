---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says one slow call that fails fast does not prove the circuit breaker, because a plain timeout produces the same result, and it has the test drive consecutive failures up to the configured threshold of 5 and assert that the breaker opens there. Noting that a library's default threshold may differ from the configured one does not fail.
2. It has the breaker test assert the breaker's state transitions: open after the threshold, failing fast while open with the `rates` dependency receiving no calls, half-open after the 5-second reset, and closed again after a successful call.
3. It says the error returned when adding the fault (the `AddToxic` call) must be checked, so a fault that was never applied cannot let the test pass.
4. It says the deadlock test proves nothing about the product because it reverses its own two locks, and has it exercise the lock order the shipped code actually uses instead.
5. It puts a build tag on the chaos test file so the everyday check and the coverage gate never compile it, and says chaos tests do not run on pull requests.
Fail if any of the 5 is missing.
