# Lightweight Evaluation versus a Full ATAM

Reference for `architecture-evaluation` steps 2 and 11. Grounded in Bass, Clements and Kazman, and in the research notes' own caveat: both the Quality Attribute Workshop and the ATAM assume many stakeholders and an outside team, so here the evaluation is a self-check and the record must say so.

## The full ATAM, in outline

The Architecture Tradeoff Analysis Method is the SEI's scenario-based evaluation: present the method, present the business drivers, present the architecture, identify the architectural approaches, build the utility tree, analyse the approaches against the highest-priority scenarios, brainstorm and prioritise more scenarios with a wider group, analyse again, and present the results. A full ATAM takes a team several days and a large group of stakeholders, usually with an outside evaluation team.

## The lighter method

The book also describes a **Lightweight Architecture Evaluation**: an in-house, much shorter version, about a day, run by the team itself, using the same utility tree and scenario analysis. The research notes mark the method's exact name in the fourth edition, and its hour budget, as less certain, so this skill describes the shape and does not quote a duration.

## What is kept, and what is dropped

| Step or feature | In this skill |
|---|---|
| Scenarios and a utility tree as the basis | Kept, but owned by `nfr-specification`; consumed through the Architecture Handoff |
| Identify the architectural approaches | Kept: step 4 |
| Analyse each high-priority scenario against the approaches | Kept: steps 5 and 6, with a tactics questionnaire |
| The five outcomes (risk, non-risk, sensitivity point, trade-off point, risk theme) | Kept: the record's sections |
| Brainstorming more scenarios with a wider group | Dropped: there is one stakeholder, the product owner; the NFR stage already drafted and ranked the scenarios |
| An outside evaluation team | Dropped: the designing agent evaluates its own design |
| Several days | Dropped: sized to the profile |

## Why the record says "self-check"

The designer evaluating its own design shares its assumptions and blind spots, and there is no group to challenge them. That limits what the record can claim. It is honest to present it as a structured check that makes the design's risks and trade-offs visible and decided, and dishonest to present it as an independent review or an ATAM. The record therefore says, in its frontmatter and its opening statement, that it is a self-check, not independent, and not an ATAM. At enterprise scale the product owner's confirmation of the risks at the Design gate is the nearest substitute for the wider group.

## Sizing (Fairbanks)

Risk-driven architecture sizes effort to risk: cost if wrong times uncertainty. A twenty-person lunch app does not need a theme analysis; a platform with regulatory obligations and two regions does. Lean therefore runs a questionnaire on the top two or three scenarios, standard evaluates every high-impact scenario, and enterprise adds themes and the walk with the product owner. Over-applying the full method at lean contradicts both the book's advice to focus on the few scenarios that matter and the manifest's profile rules.

## What a late finding does

A risk or trade-off found here can change a decision in an approved artifact. The manifest reopens a changed artifact to draft, and no later phase can be completed until the user re-approves it. Say so in the record when a finding implies such a change, and ask the user before changing cost or scope.
