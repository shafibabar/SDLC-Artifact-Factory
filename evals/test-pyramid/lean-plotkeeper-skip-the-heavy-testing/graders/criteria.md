---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. Full testing at lean: it does not leave out load, chaos or mutation testing. All three appear in the strategy (each may be narrow in scope for a small product), and it says that every product size gets the full testing treatment (D048, decision 2).
2. No ratio: it rejects 70/20/10 (or any fixed percentage split) as a target to hold the team to, and instead places each behaviour at the lowest test layer that can prove it, with the pyramid shape as a result of that (engineering default W3-D25; `unit-testing-khorikov.md`, "The test pyramid's shape is a consequence").
3. Coverage level: it replaces the 80% line gate with 100% of both lines (statements) and branches, where only machine-generated code is excluded automatically and any other exclusion is listed with a reason for the product owner to approve (D048, follow-up A).
4. Go measurement limit: it says Go's own coverage tool measures statement blocks only, not branches, so it enforces 100% of statements as a hard gate and adds the `gobco` branch coverage tool, to be tried out before being relied on (D048, follow-up A for Go; `go-coverage-official-docs.md`).
5. Honest gaps: it states that some cases remain unmeasured by branch coverage, naming at least `select` and `range` loops (including a loop that runs zero times), to be stated in reports; and it does not offer silently falling back to a statements-only gate if the `gobco` trial fails (that goes back to the product owner) (D048, follow-up A for Go).
6. Mutation bar: every planted fault must be caught by a test, or recorded with the reason it cannot be (the change does not alter behaviour). It does not set a mutation score target below that, such as 60% or 70% (D048, follow-up B).
7. Targets are cited, not invented: it does not adopt the 200 ms p99 page target as a gate on its own authority; it says no agreed NFR or SLO covers page response and that one must be agreed and recorded first, while performance or load testing is tied to NFR-PERF-01's 10-minute figure (engineering default: targets cited from NFR/SLO, never invented; batch A W3A-14).
Fail if any of the 7 is missing.
