# Facilitation Guide: Running a Real Session

For when the product owner holds a human Event Storming session; agent-run mode is in `./agent-run-mode.md`. Grounded in Brandolini (*Introducing EventStorming*), as summarised in `research/domain-driven-design/introducing-eventstorming-brandolini.md`. Timings marked *house* are this plugin's guidance, not Brandolini's.

## 1. Who to invite

Brandolini's rule above all others: **invite the people with questions and the people with answers.** A session without the knowledge holders produces a confident-looking wall of guesses.

| Format | Room |
|---|---|
| Big Picture | Large and mixed (often 10–30+): domain experts from every department the flow crosses, decision makers, the technical people |
| Process Modelling | The people who run the process, the people who will change it, the people who build the software |
| Software Design | Mostly developers, with domain experts on hand to answer rule questions |

**The facilitator runs the process, not the content:** prepares the room, keeps the legend visible, introduces notation when it's needed, asks about vague stickies, protects hotspots from turning into debates, keeps time, and writes few stickies themselves.

## 2. Space

- **Unlimited modelling space:** a long paper roll on a wall, not a whiteboard. A small surface quietly limits how much people say.
- **Remove tables and chairs:** people stand, move and write.
- **The legend on the wall** where everyone can see it, and enough sticky notes of each kind that nobody rations them.

## 3. Big Picture, phase by phase

| Phase | Facilitator's moves | Timebox (*house*) |
|---|---|---|
| Chaotic exploration | "Write every event that happens in this business, past tense, one per sticky. No talking yet." Orange only | 20–40 min |
| Enforce the timeline | Order left to right; merge duplicates; ask which near-duplicates are really different. Mark pivotal events and swimlanes | 40–60 min |
| People and systems | Add actors and external systems where they cause or receive events | 20 min |
| Walkthrough | One person tells the story along the timeline; the room corrects. Then the reverse narrative, end to start | 30–45 min |
| Problems and opportunities | Hotspots on pain, risk and disagreement; opportunities for ideas | 20 min |
| Pick the problem | Each person gets two or three arrow votes for hotspots | 10 min |

Throughout: ask "what goes wrong here?" and "what happens if nobody acts?", and turn every argument into a hotspot instead of settling it.

## 4. Process Modelling and Software Design

- **Process Modelling:** pick one process, usually between two pivotal events, chosen by the vote. Walk every path through the chain (read model → actor → command → system → event → policy → …) until each reaches a stable end. Each break becomes a hotspot. Half a day per process (*house*).
- **Software Design:** on a modelled process, ask which rules must hold at every instant, and cluster the commands and events around each such rule into a consistency unit. Then group by language into Bounded Context candidates. Half a day (*house*).

## 5. Remote sessions (recalled with less confidence)

Brandolini's later notes, as recalled, treat remote as a different workshop, not the same one online. An online canvas loses much of the parallel chaos and the body language. Use shorter sessions spread over several days, smaller groups, more preparation, and a prepared board with the legend and the timeline axis.

## 6. After the session

- **Transcribe the same day** into the format's template. The transcript records element types, not colours.
- **Hotspots** go where the skill's § 6 routes them. The ranked list is presented to the product owner at the review gate.
- **Replace assumptions.** If an agent-run wall existed before the session, every card the session confirmed loses its *assumed* label, and every card it contradicted is removed or changed.
