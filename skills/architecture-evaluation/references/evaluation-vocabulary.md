# Evaluation Vocabulary

Reference for `architecture-evaluation` steps 3, 6 and 7. Grounded in Bass, Clements and Kazman (*Software Architecture in Practice*): the outcomes of an ATAM-style evaluation, and the utility tree behind the scenarios. The definitions are the book's, in our words; no page or chapter numbers are cited because the research notes give none.

## What is being evaluated against

A **scenario** is the unit: a stimulus, its source, an artifact, an environment, a response and a **response measure** (the six parts). The architecturally significant ones are rated on two scales, usually High, Medium or Low: **business value** (how much it matters if unmet) and **architectural impact** (how much it shapes the design). The utility tree, which ranks them, belongs to `nfr-specification`, as do the scenarios. This skill consumes them from the NFR's **Architecture Handoff**: each scenario rated high on architectural impact, with its trade-off points (`TP-n`) and tactic families as pointers.

A scenario with no response measure cannot be evaluated: "fast" has no pass or fail. Send it back to `nfr-specification`.

## The five outcomes

| Outcome | Definition | What the record shows |
|---|---|---|
| **Risk** | An architectural decision that may lead to an unmet quality attribute | The scenario, the decision, why it may fail, and the action |
| **Non-risk** | A decision judged safe | The scenario, the decision, **and the reason** it is safe: a non-risk with no reason is an assertion |
| **Sensitivity point** | A property of one or more components that is critical for achieving one particular response | The property, the response it governs, and the value or limit that matters (for example, a connection pool's size sets latency under load) |
| **Trade-off point** | A property that is a sensitivity point for more than one attribute, in opposite directions | The property, the attribute it raises, the attribute it lowers, and how it was resolved (for example, the level of encryption improves security and costs latency) |
| **Risk theme** | A group of risks that points to a systemic weakness, tied to the business goals it threatens | The risks grouped, the weakness they share, and the business driver at stake |

## Telling them apart

- A **sensitivity point** concerns one response; a **trade-off point** concerns two attributes pulled in opposite directions. Every trade-off point is a sensitivity point for each attribute, but a sensitivity point is not a trade-off unless a second attribute moves the other way.
- A **risk** is about a decision that may fail; a **trade-off point** is a decision that is always a trade, and the design must choose explicitly. A trade-off point can also be a risk if the chosen balance leaves one scenario unmet.
- A **risk theme** needs two or more risks with a shared cause; one risk alone is not a theme.

## The NFR handoff's trade-off points

`nfr-specification` lists candidate trade-off points (`TP-n`) between highly rated scenarios, without choosing. This evaluation takes each one and either resolves it (an ADR), accepts it with a reason, or carries it on with an owner. A trade-off point the evaluation finds that the NFR did not list is added to the record as found here.

## Routing to ADRs

A trade-off point that is costly to reverse and widely depended on passes `adr-authoring`'s risk gate (cost of change times breadth of dependency times uncertainty) and becomes an ADR whose rationale carries a `Trade-off:` line naming two or three characteristics. One that is cheap and narrow is recorded in the evaluation as accepted, with the reason. One that changes cost or scope goes to the user.
