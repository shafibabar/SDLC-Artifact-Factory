---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects Docker Compose as the end-to-end environment and says the journeys run in a throwaway Kubernetes cluster (kind) created for the run, and that this holds for a lean product too (end-to-end decision of 2026-11-28: no Compose variant and no lighter lean environment).
2. It keeps the end-to-end journeys out of `make ci` and off pull requests, and says when they run instead: on a schedule such as nightly, by hand, or before a release (W3-D10 and the end-to-end timing rule). Naming at least one of those occasions is enough.
3. It says the staging check that POSTs and DELETEs a booking is not a smoke test, because a smoke test is read-only (gap W3C-26). It either makes the check read-only or moves the create-and-delete journey out of the smoke selection.
4. It says that only the read-only smoke selection may be pointed at staging or any other deployed environment, and that journeys which create or delete data run only against the run's own throwaway cluster (end-to-end decision of 2026-11-28: never a shared, staging, production or tenant environment).
5. It rejects the upsert seed: test data is created through the product's public API since Mossgate offers one, and no `ON CONFLICT ... DO UPDATE` write that can overwrite an existing row is used, least of all against the staging database (test-data decision of 2026-11-26). Allowing a plain direct insert inside the throwaway cluster does not fail.
Fail if any of the 5 is missing.
