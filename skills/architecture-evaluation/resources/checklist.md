# Checklist: Architecture Evaluation

Resource for `architecture-evaluation`. Run after `./scripts/validate-architecture-evaluation.sh` is clean; the script checks structure, this list checks judgement.

## Honesty about what this is
- [ ] The record says it is a self-check by the designing agent, not independent, and not an ATAM; the word ATAM is never used as the method performed.
- [ ] No claim of an independent review anywhere, including the summary.

## Scenarios
- [ ] Every scenario evaluated came from `nfr-specification`'s Architecture Handoff and has a response measure; none was invented here.
- [ ] A wish or a scenario with no measure was sent back, not evaluated.
- [ ] Lean covers the top 2 or 3 scenarios; standard and enterprise cover every scenario rated high on architectural impact.

## Findings
- [ ] Every scenario has at least one questionnaire answer and a finding or a stated non-risk.
- [ ] Each risk names the scenario, the decision and the action; each non-risk names the reason it is safe.
- [ ] A sensitivity point governs one response; a trade-off point raises one attribute and lowers another.
- [ ] Every trade-off point the NFR handoff carried (`TP-n`) is resolved or carried on, with an owner.
- [ ] No trade-off point was relabelled a non-risk or left out.

## Routing
- [ ] Each trade-off point passes the ADR risk gate and has an ADR with a `Trade-off:` line, or is recorded as accepted with a reason, or goes to the user for a cost or scope decision.
- [ ] A finding that changes an approved artifact says it reopens it.

## Themes and fitness functions
- [ ] Risk themes appear at enterprise (and at standard only for a shared cause), each tied to a business driver; none at lean.
- [ ] Each fitness function names an objective automated check, where it runs and its owner; none is a one-time review or a wish.
- [ ] An existing repository check is pointed to where one fits.

## Confirmation and scope
- [ ] Enterprise: the product owner's confirmation of the risks is recorded.
- [ ] No implementation code appears in the record or the answer.
