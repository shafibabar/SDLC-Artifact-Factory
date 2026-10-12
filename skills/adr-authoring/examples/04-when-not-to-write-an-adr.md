# Example 4 — Triage: which decisions get an ADR (and which deliberately don't)

Self-contained. Applies the risk-driven gate (Fairbanks, *Just Enough Software Architecture*). It weighs cost of changing the decision later, how many other decisions and components depend on it, and how uncertain it is. The case is one Design-phase session's list of candidate decisions for a multi-tenant SaaS platform.

## Input — six candidate decisions

1. Which JSON logging library the Go services use.
2. Synchronous REST versus events between the Billing and Usage Bounded Contexts.
3. Whether tenant isolation is pooled, siloed or a bridge.
4. The page size default for list endpoints (50 versus 100).
5. Which message broker carries all Domain Events.
6. Whether the admin console's container diagram shows the gateway inside or outside the trust boundary.

## Triage

| # | Cost to change later | Breadth of dependency | Uncertainty | Verdict |
|---|---|---|---|---|
| 1 | Low: one adapter package | Low: hidden behind the logging interface | Low | **No ADR.** Write the code. If it's wrong, swap it. |
| 2 | High: contracts, retries, consistency model | High: both contexts, their consumers, tests | Medium | **ADR** |
| 3 | Very high: data migration, security model | Very high: every repository and query | Medium, rising with enterprise demand | **ADR** (see Example 3) |
| 4 | Low: a config value, still overridable per call | Low | Low | **No ADR.** It belongs in `api-contract-design`'s conventions. |
| 5 | Very high: every publisher and consumer | Very high | Low (tech stack default: Redpanda) | **No new ADR when following the default.** Write one only to deviate from it. |
| 6 | Low: a diagram edit | Low | Low | **No ADR.** One sentence of view rationale in the diagram's own documentation (Clements). |

## Output — what gets written

- **ADRs:** #2 and #3.
- **Nothing, deliberately:** #1 and #4. Code and conventions record them adequately, and they are cheap to reverse.
- **A view-rationale note, not an ADR:** #6. Clements (*Documenting Software Architectures*) separates a diagram's own short rationale ("why this view looks this way") from an ADR's cross-cutting decision rationale. Merging them would make a mega-record with mismatched lifecycles.
- **A deviation-only rule:** #5. The tech-stack default is already the recorded decision; an ADR is written only when deviating from it.

## Why this matters

Writing an ADR for everything "non-obvious" is over-investment. Fairbanks puts it this way: rim-of-the-bullseye elements get no ADR by default. The volume also buries the decisions that matter. The gate gives explicit permission to skip.
