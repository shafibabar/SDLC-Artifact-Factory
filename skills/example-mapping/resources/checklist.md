# Checklist: Example Map

Run after `validate-example-map.sh` (the skill's script) is clean. The script checks structure; this list checks judgement.

## Inputs and honesty
- [ ] The card and seed example match the backlog; every cited BR-n, fit criterion and NFR ID exists and is not reworded in meaning.
- [ ] Every source named was actually read; anything else is `assumption (Q-n)`.
- [ ] No session, participant or agreement is claimed that did not happen.
- [ ] No answer was written by the agent; each answered or moved row quotes the product owner's reply to that question.

## Rules and examples
- [ ] Each rule says one thing, in business language, with no screen, endpoint or storage mechanics.
- [ ] Each example shows one rule, with values a reader can check, and its outcome is observable.
- [ ] Each Negative example would catch a real bug; limits are tried on the boundary and either side where they matter.
- [ ] Who may not do this, nothing to show, maximum volume, two at once, and a dependency being down were each considered; so was tenant isolation if the product has tenants.
- [ ] Removing any example would change what is proven.

## Questions and readiness
- [ ] Each question is one decision the product owner can make, with why it matters.
- [ ] Quality numbers cite an NFR ID or are open questions.
- [ ] A moved case is gone from this map's rules and the new story is proposed to `user-story-writing`.
- [ ] The split decision gives a reason.
- [ ] The reply states the verdict, blockers, run mode, assumptions and next step.
- [ ] The map has no Given/When/Then, criterion IDs or scenario names.
