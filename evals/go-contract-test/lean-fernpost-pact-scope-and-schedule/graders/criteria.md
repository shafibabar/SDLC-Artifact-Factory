---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It disagrees with skipping Pact: it says Pact is used for the direct `subscriptions` to `billing` call on the lean profile too, because every direct service-to-service request/response call gets it at every product size, and that no growth trigger or architecture decision record is needed to adopt it (product-owner decisions 5 and 10 of 2026-11-28; `.sdlc-memory/tree/self/decisions/D048.md`, point 2). Saying lean means fewer boundaries to cover does not fail.
2. It refuses PactFlow (or any paid or hosted service) unless the product owner approves it, and uses the open-source Pact Broker, self-hosted (decision 5; `research/testing/contract-testing-in-action-cruz-prescott.md`, Caveats; `research/testing/pact-go-official-docs.md`, header).
3. It says Pact does not run on every pull request: it runs as a daily scheduled run that produces a report of the impact of code changes on existing flows. It states the consequence plainly: a pull request is not blocked by Pact, so a breaking change can be merged and show up in the next day's report (decision 6). A reply that promises Pact will stop the merge fails this criterion.
4. It keeps the OpenAPI breaking-change check: Pact is added on top of the API-description checks and never replaces them, and those cheaper checks are what run on every pull request (decisions 5 and 6).
5. It says the deployment of a service checks the latest recorded Pact result with `can-i-deploy` and is refused when that result shows a broken caller (decision 7; `research/testing/pact-go-official-docs.md`, Core Concepts, can-i-deploy).
Fail if any of the 5 is missing.
