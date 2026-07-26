# Coverage Expectations by Complexity Quadrant

Full grounding for `go-unit-test`'s "What Deserves a Unit Test" section — numeric guidance where Khorikov's research actually supports a number, honest heuristic framing where it doesn't. Self-contained: restates the quadrant table below rather than assuming the parent body is in context.

---

## The Governing Caveat First

Khorikov is explicit and repeated on this point: **coverage metrics are a lagging, gameable indicator — never a target.** Line/branch coverage proves code *executed*, not that a meaningful assertion ran; a test with zero assertions inflates coverage to 100% while catching nothing. Every number below describes what tends to *fall out* of doing thorough, quadrant-appropriate testing correctly — never a CI percentage gate to chase for its own sake, and never a substitute for `go-mutation-test`'s mutation score, which is what actually verifies assertion quality where a coverage percentage cannot.

---

## Quadrant Table (restated)

| Quadrant | Domain complexity | Collaborators | Test strategy |
|---|---|---|---|
| 1 — Domain logic | High | Few | Thorough table-driven unit tests |
| 2 — Overcomplicated | High | Many | Decompose first; then quadrant 1 + quadrant 3 apply to the pieces |
| 3 — Controllers | Low | Many | Humble Object + integration/e2e tests, not unit coverage |
| 4 — Trivial | Low | Few | Often no dedicated test at all |

---

## Numeric Guidance, Quadrant by Quadrant

**Quadrant 1 — Domain logic (high complexity, few collaborators).** This is where a number is meaningful: exhaustive table-driven coverage of every branch, invariant, and boundary on an exported mutating method typically lands **90%+ statement coverage as a byproduct**, because `go-domain-model`'s own Domain-Model Unit-Test Standard already requires a table case per invariant, per rejection path, and per success path for every mutating method (error-match, immutability-on-reject, event-count — see `go-domain-model`'s `references/aggregate-invariant-enforcement.md`). If a quadrant-1 package sits well below that figure, treat it as a negative signal worth investigating — a likely sign of an untested branch or an invariant with no corresponding rejection case — not as a gate that blocks the build by itself.

**Quadrant 2 — Overcomplicated (high complexity, many collaborators).** No coverage figure applies here, and chasing one is actively counterproductive — it would mean writing exhaustive unit tests around code that is, by definition, structurally resistant to being unit-tested cleanly. The correct move is Khorikov's decomposition: extract the complex decision logic into a quadrant-1 shape first, apply quadrant 1's guidance to the extracted piece, and cover what's left with the handful of integration tests quadrant 3 calls for.

**Quadrant 3 — Controllers (low complexity, many collaborators).** A unit-coverage expectation of effectively **0% is correct and intentional**, not a gap. This is Humble Object territory (`go-chi-handler`, `go-repository-pattern`) — the wrapper is deliberately thin enough that its correctness lives in wiring, verified by `go-integration-test`'s real-dependency tests, not by mocking every collaborator to hit a unit-coverage number. Forcing unit coverage onto quadrant-3 code is the "Right-sized" Quality Criterion's named failure mode in `go-unit-test`'s main body.

**Quadrant 4 — Trivial (low complexity, few collaborators).** No coverage figure is meaningful; a getter or a simple mapper often earns no dedicated test at all, and a coverage tool flagging it as "uncovered" is not a defect.

---

## How to Use a Coverage Tool Here, Precisely

Run `go test -cover` (or `-coverprofile` plus `go tool cover -html`) to find **under-tested quadrant-1 code** — that is its one legitimate use in this repo: a negative signal pointing at domain logic that might be missing a table case. Never wire a blanket coverage percentage into a CI gate that applies uniformly across quadrants; a repository package (quadrant 3, Humble Object) sitting at 20% unit coverage is correct and expected, and a gate that doesn't know the difference will either block correct code or get silently disabled the first time it does.
