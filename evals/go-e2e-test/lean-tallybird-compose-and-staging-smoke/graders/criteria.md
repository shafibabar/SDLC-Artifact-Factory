---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects Docker Compose and runs the end-to-end tests in a throwaway Kubernetes cluster created with kind for the run, and it says this applies to a lean product too (product-owner decision of 2026-11-28; decision D048 item 2). An answer that accepts Compose for the end-to-end tests, as the only option or as an alternative for lean, fails.
2. It rejects dropping user journeys because the product is lean: Tallybird still gets a small number of journeys through the deployed product, and each journey is traced to acceptance criteria (decision D048 item 2: lean means fewer journeys, never none).
3. It says a check run against staging must be read-only, and it moves the check that creates a member, records a payment and deletes the member out of the staging run so that it runs only in the throwaway cluster (finding W3-D10: live-environment smoke is read-only; destructive tests refuse a non-throwaway address). Keeping the health and version check against staging does not fail.
4. It replaces the seeding step: the test member is created through the product's public API (`POST /v1/members`), and nothing is written to the staging database (test-data decision of 2026-11-26: throwaway databases only). It also rejects the `ON CONFLICT ... DO UPDATE` upsert because it can overwrite an existing row.
5. It gives the end-to-end files the `e2e` build tag (a `//go:build e2e` line, or the same tag combined with others), and says this keeps them out of `make ci` or the everyday check (finding W3-D10). An answer that leaves the files untagged so `make ci` runs them fails.
Fail if any of the 5 is missing.
