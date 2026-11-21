---
name: handoff-record
product: [product slug]
version: 1.0.0
phase: [phase of the hand-over: design | implement | …]
owner: [the producing agent — same as from]
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: what passed from whom to whom, and whether it is accepted, blocked or paused]
from: [producing agent]
to: [receiving agent]
mode: [hand-over | joint review]
status: [open | accepted | blocked | paused | model-revision]
traces-to: [the artifacts handed over, by path]
---

# Hand-over: [from] → [to] ([phase])

<!-- One record per pair of agents per phase. Path: artifacts/<product>/<phase>/handoffs/<from>-to-<to>.md.
     The receiver never edits the producer's artifacts: defects go in Flags back. -->

## Concerns handed over

| Concern | Artifact | Definition of Done met | Note |
|---|---|---|---|
| [the concern, named precisely: "Aggregates for Ordering", not "domain model"] | [path] | [yes | no — what is missing] | [—] |

## Mode

- **Mode:** [hand-over | joint review]
- **Why:** [hand-over: the default | joint review: Core subdomain | personal or regulated data | disputed boundary | first hand-over of this kind — which, and where]
- **Changes:** [none | <date>: <from> → <to>, because <trigger>]

## Flags back

| # | Raised by | Artifact | What is wrong or missing, with evidence | Owner | Status |
|---|---|---|---|---|---|
| [1] | [agent] | [path] | [the defect and its evidence] | [owning agent] | [open | fixed | declined: <reason>] |

## Open questions

- [question — who answers it — blocking or not | none]

<!-- Delete Resumption if the work was never interrupted. -->
## Resumption

- **Interrupted:** [<date> — what was in progress]
- **Kind:** [operational pause | model found wrong]
- **Next step:** [operational pause: what continues and who does it | model found wrong: the model's owner revises <what>; downstream artifacts to review: <paths>]
