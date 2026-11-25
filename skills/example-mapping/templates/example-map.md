---
name: example-map
product: <product>
story-id: US-<n>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: which story, how many rules, ready or what blocks it>
profile: <lean | standard | enterprise>
run: <agent-run | workshop>
readiness: <ready | not-ready>
traces_to: ideate/user-stories.md (US-<n>); <other artifacts and IDs this map draws on>
---

<!-- Copy to ideate/example-maps/US-n.md, fill every field, delete these comments.
     No Given/When/Then, no criterion IDs, no scenario names. -->

# Example Map: US-<n> <Story title>

## Story

As a <persona>, I want to <action>, so that <change in the user's world>.

- Seed example: <copied from the backlog>
- Cited rules and targets: <BR-n, NFR-ID | none>

## How This Map Was Made

<!-- agent-run: keep the first sentence. workshop: replace it with "Participants: names and roles". -->
Agent-run: one agent (requirements-analyst) played all three perspectives in turn; no workshop was held.

- Read: <artifact paths and IDs>

| Perspective | What it raised |
|---|---|
| Customer | <rules, examples or questions it added, by ID> |
| Developer | <...> |
| Tester | <...> |

## Rules and Examples

<!-- One "### Rn:" block per rule. Source: an artifact path and ID, "product owner, yyyy-mm-dd (Q-n)",
     or "assumption (Q-n)". Type: Happy, Negative or Edge. Each rule: at least one Happy and one
     Negative; the story: at least one Edge. An outcome nobody knows yet: "unknown (Q-n)". -->

### R1: <rule in business language>
- Source: <source>

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | <who, what they do, real values> | <what is then true> | <source> |
| R1.E2 | Negative | <the case that breaks the rule> | <what is then true> | <source> |
| R1.E3 | Edge | <exactly on the limit> | <what is then true> | <source> |

## Questions for the Product Owner

<!-- Status: open (Answer "—"), answered ("answer — product owner, yyyy-mm-dd"), or
     moved ("moved to US-n — agreed by product owner, yyyy-mm-dd"). Never delete a row.
     No questions: keep the header row only. -->

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | <one question> | <R-n or story> | <what changes with the answer> | <your suggestion> | <open> | <—> |

## Split Check

- Rules: <count> · Open questions: <count>
- Decision: <keep, with the reason | split proposed: the children | split agreed: US-n>

## Readiness

**Verdict:** <Ready | Not ready>
- Blocking: <Q-n, Q-m | none>
