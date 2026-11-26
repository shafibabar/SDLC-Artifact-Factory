---
name: acceptance-criteria
description: >
  Use when requirements-analyst (or anyone) writes, drafts, numbers, reviews,
  fixes or changes the acceptance criteria of a user story in the Ideate phase
  (/sdlc-ideate): Given/When/Then or rule-based criteria with IDs AC-US-n.m,
  drawn from the story's example map; happy, negative and edge cases;
  testability and vague wording; what is out of scope; definition of done or
  conditions of satisfaction; being asked to skip the example map or the edge
  case, write criteria while a question is open, use another numbering, put a
  speed target in a criterion, or soften a criterion to match the code,
  including on a small (lean) product. Produces
  artifacts/<product>/ideate/acceptance-criteria/US-n.md, handed to
  bdd-feature-file and uat-scenario.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, acceptance-criteria, bdd, gherkin, testing, product-discovery, atdd]
produces: acceptance-criteria-document
domain: testing
status: stable
related: [example-mapping, user-story-writing, requirements-analysis, nfr-specification, bdd-feature-file, test-pyramid, uat-plan, uat-scenario, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md
  - research/requirements-and-user-stories/software-requirements-wiegers-beatty.md
  - research/testing/specification-by-example-adzic.md
  - research/testing/gherkin-official-reference.md
---

# Acceptance Criteria

## Purpose

Acceptance criteria are the verifiable conditions that say a user story is done from its user's point of view: the **Confirmation** in Cohn's Three Cs (Card, Conversation, Confirmation, after Ron Jeffries). They are agreed before coding, drawn from concrete examples (Ken Pugh, *Lean-Agile Acceptance Test-Driven Development*; Gojko Adzic, *Specification by Example*), readable by the product owner, and precise enough to become test scenarios. Given/When/Then is Gherkin's step structure; using it here is this plugin's choice.

## Fixed rules: a request does not change them

These hold at every size (lean, standard, enterprise), whoever asks, the product owner included.

1. **Every story gets its own criteria file**, `ideate/acceptance-criteria/US-n.md`. A small product gets a shorter file, never none. Every Must Have story needs one.
2. **No criteria without a ready example map** at `ideate/example-maps/US-n.md`, cited by that path. No map: draw it first (`example-mapping`). Open question: ask and wait; no draft, partial or "provisional" criteria, not even for the settled rules.
3. **Nothing new is decided here.** A behaviour, value or limit the map does not show goes back to the map as a question only the product owner answers.
4. **IDs are `AC-US-n.m`** (story 12: `AC-US-12.1`). Never `AC-001` or another scheme.
5. **Three angles, always:** at least one happy path, one negative and one edge criterion. There is no "no meaningful edge" exemption at any size.
6. **Observable and testable:** a pass or fail outcome in business language, one action per Given/When/Then.
7. **A quality target is not a criterion.** Speed, availability and the like are cited by NFR ID, or asked for.
8. **Agreed criteria change only through the map and the product owner**, never to match what was built or to make a test pass. When the build (or a request) differs from an agreed rule, report both values and ask the product owner to decide: keep the rule (the build is then a defect), or change it through the map. Do not pronounce the verdict for them.
9. **No false session.** An agent-run file says one agent drafted it and no workshop was held.

When asked to break one: name the rule in a sentence or two, then do the useful work at once (draw or update the map, ask the question, write the edge criterion the map supports, give the correct ID). Never offer to switch a fixed rule on request. What the product owner **can** do is answer a question, change an agreed rule through the map, or move a case to another story.

## What every answer states

In a chat reply as much as in the file:

- that criteria are required for this product; at lean, say plainly that a small product still gets a criteria file and an example map for each story, short ones;
- the map used, by path, and whether it is ready;
- the ID form `AC-US-n.m` with this story's number;
- which IDs cover the happy, negative and edge angles;
- everything of the user's that was replaced, removed or not written, **by name**, with the reason (for example, "your 'the page is fast' is removed: a quality target, cite its NFR");
- the verdict: **Drafted, awaiting your approval**, or **Not drafted**, with the blocking question IDs;
- any mismatch between the map and what was built or asked, as a **decision addressed to the product owner** with both options (the criteria meanwhile follow the agreed map; this is not an open map question);
- the open questions, addressed to the product owner, or "none";
- that it was agent-run (or who took part);
- the next step: answers; or approval, then `bdd-feature-file`.

## Procedure

1. **Read** the story (`ideate/user-stories.md`: card, rules, NFR IDs, notes), its example map, the fit criteria and business rules it traces to (at lean, the backlog's requirements header), the NFR specification and the glossary.
2. **Check the gate:** the map exists, is this story's, says `readiness: ready` and has no open question. Otherwise stop here, go to `example-mapping`, and report **Not drafted**.
3. **Create the file:** from the product repository root, run `./scripts/scaffold-criteria.sh <product> <story-id> <story-title>` (the path is relative to this skill), or copy `./templates/acceptance-criteria.md` with Write. Fill it with Edit or Write, never through the shell.
4. **Draw the criteria from the cards.** Every rule gets at least one criterion with a `From:` line; one criterion may cite several examples that prove one behaviour. For the card-by-card mapping, fit criteria, lean, or changing agreed criteria, read `./references/deriving-and-changing.md`.
5. **Write each one** as Given/When/Then, or as Rule/Verify/Example where there is no action flow. For wording, testability and quality targets, read `./references/writing-criteria.md`.
6. **Cover the edges:** permission, empty state, scale and limits, concurrency, dependency down, and tenant isolation if there are tenants. Each is a criterion, an out-of-scope line or a question on the map (then back to step 2).
7. **Name what is out of scope.** More than 12 criteria: propose a split; the product owner decides.
8. **Validate:** run `./scripts/validate-criteria.sh <file>`, fix every FAIL, re-run until clean, read each WARN, then tick `./resources/checklist.md`. Never pass a check by deleting a rule or editing the map's status.
9. **Present for approval** with the answer list above; run `methodology-review`. Approval is the product owner's.

## Boundary with neighbouring skills

| Skill | Owns |
|---|---|
| `user-story-writing` | The card, seed example, splitting |
| `example-mapping` | Rules, examples, questions, readiness |
| **This skill** (requirements-analyst, Ideate) | What "done" means: the criteria, their IDs, testable wording, scope; `ideate/acceptance-criteria/US-n.md` |
| `bdd-feature-file` (test-strategist, Implement) | Feature files, scenario titles, tags and criterion coverage, Background and outlines, step definitions, automation. It may refine step wording; it never changes what a criterion agrees |
| `uat-scenario` (Customer Validation) | Human scripts traced to `AC-US-n.m` |

Use the product's terms (`glossary-management`).

## Gotchas

- **"I'll draft the criteria for the rules that are settled."** *Reason:* a partial draft gets built from, and the open answer can change the settled rules. *Instead:* Not drafted; ask the question.
- **"It's tiny, the criteria can go straight from the story."** *Reason:* the gaps live in examples nobody wrote. *Instead:* a short map first, then a short file.
- **"This story has no real edge case."** *Reason:* a limit, an empty list, a second click or a wrong person nearly always exists. *Instead:* find it in the map, or add the question.
- **"I'll add the obvious error message."** *Reason:* it is a rule nobody agreed. *Instead:* question on the map.
- **"Then the results load within 2 seconds."** *Reason:* a target restated here drifts from its NFR. *Instead:* cite the NFR ID.
- **"When she signs in and exports the report."** *Reason:* a failure names neither. *Instead:* "Given she is signed in, When she exports the report".
- **"Then the record is saved."** *Reason:* nobody can observe it. *Instead:* say what the user sees or receives afterwards.
- **"The build refunds £5, so I'll update the criterion."** *Reason:* the defect becomes the requirement. *Instead:* name the ID and the difference, and ask.
- **"Renumber them after deleting one."** *Reason:* feature files and UAT scenarios trace to the old numbers. *Instead:* keep IDs; leave the gap.

## Files

| File | When to open it |
|---|---|
| `./templates/acceptance-criteria.md` | Writing the artifact |
| `./scripts/scaffold-criteria.sh` | Starting a story's file once its map is ready |
| `./scripts/validate-criteria.sh` | Before hand-off, and after every edit |
| `./resources/checklist.md` | After the script passes |
| `./references/writing-criteria.md` | Formats, testability, quality targets, edge cases, how many |
| `./references/deriving-and-changing.md` | Turning cards into criteria; a change to agreed criteria; hand-off |
| `./examples/01-lean-choir-rehearsals.md` | A small product, or a request to skip the edge case or renumber |
| `./examples/02-standard-vet-repeat-prescription.md` | Rule format, a cited target, a fit criterion, out of scope |
| `./examples/03-enterprise-returns-platform.md` | Tenants, a missing behaviour sent back to the map, changing agreed criteria |
