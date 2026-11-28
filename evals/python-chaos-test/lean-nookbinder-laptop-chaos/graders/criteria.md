---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects the per-test testcontainers stack as the place for the chaos experiment and runs it in the run's own throwaway Kubernetes (kind) cluster instead, and it keeps that rule for a lean product rather than offering a lighter environment because the product is small.
2. It does not run the experiment against staging by default. It allows staging only if the product owner signs a statement saying exactly where the experiment runs and what it may affect, such as which faults, the blast radius, the abort conditions and the expected impact. A reply that simply refuses staging with no mention of the signed-statement exception fails; a reply that allows staging without such a signed statement fails.
3. It rejects publishing the Toxiproxy API on all interfaces, because that API is unauthenticated by default and can proxy to any upstream. It keeps the API reachable only inside the test environment, or requires a token, or both.
4. It says pybreaker's async support (`call_async`) depends on Tornado and does not fit an asyncio FastAPI service, and recommends a breaker that works natively with asyncio. If it names aiobreaker, it says aiobreaker is effectively unmaintained.
5. It keeps the chaos tests out of the everyday test run and out of the coverage gate, and does not run them on every pull request (for example a separate marker and a scheduled or separately started run instead).
Fail if any of the 5 is missing.
