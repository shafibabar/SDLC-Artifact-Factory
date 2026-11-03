# Event Storming Session Checklist

Check each transcript under `artifacts/<product>/design/event-storming/` against this list before the domain-modeler's review gate. Any "no" is fixed first.

## Every format

- [ ] The frontmatter says the mode: agent-run (with `traces-to`) or a human session (date, roles).
- [ ] Every event is a past-tense business fact; none describes the technology.
- [ ] Every card has a Source: an artifact path, a session, or *assumed*. Agent-run: no unsupported card is presented as fact.
- [ ] Unhappy paths were asked for (failures, no-shows, timeouts, nobody acting).
- [ ] Every disagreement or gap is a hotspot, with a question for the product owner and the assumption used meanwhile. None is marked resolved without an answer.
- [ ] Each hotspot names where it goes: language, the product owner, `architecture-evaluation`, or the backlog.

## Big Picture

- [ ] The reverse narrative was run and found nothing missing, or its findings were added.
- [ ] Pivotal events and swimlanes are marked with their reasons.
- [ ] Bounded Context candidates are recorded with evidence, **at lean too**, and marked as candidates.
- [ ] No aggregates are named.
- [ ] Hotspots are ranked, and the next step is stated (processes chosen, or subdomain classification for lean).

## Process Modelling

- [ ] Every event traces back to a command issued by an actor or a policy.
- [ ] Every path reaches a stable end.
- [ ] Every policy reads "whenever …, then …".
- [ ] Every break in the chain is a hotspot, not a filled-in guess.

## Software Design

- [ ] Every command is handled by exactly one aggregate.
- [ ] Every aggregate states the invariant that must hold at every instant.
- [ ] Every context candidate states its language change; no "one aggregate per context".

## At the gate

- [ ] The reply says whether the wall is a hypothesis from documents, how many cards are *assumed*, and lists the top hotspots as questions.
