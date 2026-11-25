---
name: example-mapping
description: >
  Use when requirements-analyst (or anyone) draws, runs, reviews or updates an
  example map for a user story in the Ideate phase (/sdlc-ideate): finding the
  story's business rules, concrete examples, counter-examples and edge cases,
  and open questions for the product owner; judging whether a story is ready for
  acceptance criteria; folding answers back; proposing a story split; being asked
  to skip the map, assume an answer, mark a story ready, or write criteria for a
  story that has no map, including on a small (lean) product; three amigos or
  specification workshop, agent-run or with people. Produces
  artifacts/<product>/ideate/example-maps/US-n.md.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, example-mapping, bdd, acceptance-criteria, discovery, three-amigos, readiness]
produces: example-map
domain: testing
status: stable
related: [user-story-writing, acceptance-criteria, bdd-feature-file, requirements-analysis, nfr-specification, domain-storytelling, test-pyramid, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/testing/specification-by-example-adzic.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/domain-driven-design/domain-storytelling-hofer-schwentner.md
---

# Example Mapping

## Purpose

An example map is the discovery step between a user story and its acceptance criteria: the story's **rules**, concrete **examples** of each, and the **questions** nobody has answered. It makes assumptions visible while they are still cheap to correct. It is the **Conversation** of Cohn's Three Cs (after Ron Jeffries), and it comes first because examples surface a rule before the rule is fixed in writing (Ken Pugh, *Lean-Agile Acceptance Test-Driven Development*; Gojko Adzic, *Specification by Example*). Example Mapping as a named format is Matt Wynne's; the library holds no primary source for it, so the card layout and the checks below are this plugin's own convention.

## Fixed rules: a request does not change them

These hold at every size (lean, standard, enterprise), whoever asks, the product owner included.

1. **The map comes before the criteria.** Every story gets its own map file before its acceptance criteria are drafted; every Must Have story needs both. A small product gets a short map, not no map and not a map tucked inside the criteria file.
2. **Only the product owner answers an open question.** The agent may recommend an answer; the question stays open until the product owner replies to it. An advance "assume whatever you need" is not a reply.
3. **A story with an open question is not ready**, and its criteria are not drafted.
4. **Examples are concrete.** Real-feeling names, numbers and outcomes. Each rule has at least one example that satisfies it and one that breaks it; each story has at least one boundary example. No example repeats what another already proves: before adding one, name what it shows that the others do not. Check any date's weekday, or give no weekday.
5. **No invented rules or targets.** Behaviour with no named source is labelled an assumption and asked. A speed, availability or similar quality number is cited by NFR ID, or asked.
6. **No false session.** An agent-run map says one agent played every perspective and no workshop was held.
7. **A quality target is not a rule.** It gets no rule number, no `R` slot and no example in the map: take it out, say so, and cite its NFR ID in a note (or ask for one).
8. **Criterion IDs are `AC-US-n.m`** (story 12: `AC-US-12.1`). Decline any other scheme such as `AC-001`, state the form that will be used, and never offer to switch on request.

When asked to break one (skip the map, mark it ready, guess, "just write the criteria"): say in a sentence or two which rule applies and why, then do the useful work at once, drawing the short map or updating it, and put the questions to the product owner. What the product owner **can** do is answer a question, or agree to move the questioned case into another story.

## What every answer states

In a chat reply as much as in the file:

- that this product's map is required: at lean, say plainly that a small product still gets a map for every story, a short one;
- every card of the user's that was replaced or dropped, **by name**, with the reason (for example, "your Rule A example only restates the rule, so it is replaced with a concrete case");
- the criterion ID form `AC-US-n.m` for the story, whenever numbering or criteria come up;
- the readiness verdict, with the blocking question IDs;
- that the map was agent-run (or who took part), and every assumption;
- the open questions, addressed to the product owner;
- the next step: answers while not ready; once ready, the product owner's approval of the map, then `acceptance-criteria`.

## The four cards

| Card | Holds | In the file |
|---|---|---|
| **Story** (yellow) | One user story; one map per story | `US-n`, card and seed example |
| **Rule** (blue) | Something that must be true for the story to be right | `R1`, with its source |
| **Example** (green) | One concrete case that shows one rule | `R1.E1`: Happy, Negative or Edge; case, outcome, source |
| **Question** (red) | Something nobody has answered | `Q-1`: open, answered or moved |

## Procedure

1. **Read** the story (`ideate/user-stories.md`: card, seed example, BR-n, NFR IDs, notes), and where they exist the persona, the requirements the story traces to with their fit criteria, the business rules, the NFR specification, domain stories (each variant story is a candidate example), earlier maps and the glossary. At lean the requirements header in the backlog holds the rules. A missing or unclear card goes back to `user-story-writing`.
2. **Plant the seed example** as the first example, then ask what rule it shows.
3. **Think as each perspective in turn** (Agent-run mode, below) and add rules and examples: the simplest case that satisfies each rule, a counter-example that would expose a bug, and the boundaries. Work from two or three examples to the rule's wording, not the reverse. For probing prompts, edge categories and pruning, read `./references/probing-for-rules-and-examples.md`.
4. **Raise a question** wherever two readings are possible, a source is silent or two sources disagree. Record it; do not argue it to a conclusion.
5. **Prune.** Keep an example only if removing it would change what the rule is proven to do (Adzic's key examples). One example shows one rule (Pugh).
6. **Check the size.** Six or more rules, or many open questions, is a signal to propose a split or a spike (this plugin's rule of thumb, not a book's limit). The product owner decides; never split silently.
7. **Write** the map: copy `./templates/example-map.md` to `artifacts/<product>/ideate/example-maps/US-n.md` with Write and fill every field.
8. **Validate:** run `./scripts/validate-example-map.sh <file>`, fix every FAIL, re-run until clean, then tick `./resources/checklist.md`. Never make a check pass by closing a question or relabelling an assumption.
9. **Ask and wait.** Put the open questions to the product owner, each with why it matters and your recommendation, batched as the phase plan's approval mode allows. When answers, splits or later changes arrive, read `./references/answers-splits-and-changes.md`, update the file and repeat step 8.
10. **Hand off** only when the verdict is Ready: present the map for approval; `acceptance-criteria` then drafts from its rules and examples.

## Agent-run mode

The usual mode: `requirements-analyst` runs the map alone, from named artifacts. State `run: agent-run`, list what was read, and record what each perspective raised:

| Perspective | Asks |
|---|---|
| **Customer** | What is the user trying to get done? What would they expect here? What would be wrong for the business? |
| **Developer** | Which rules must be enforced? What happens in between, twice, or when something else is down? |
| **Tester** | Which case would expose a bug? What sits exactly on the limit? Who must not be able to do this? |

Playing the three in turn catches different gaps (Pugh's triad; Crispin and Gregory's collaboration before code), but it is not their agreement. Label any rule or outcome with no named source `assumption (Q-n)` and ask Q-n. Illustrative names and values in an example need no label; the behaviour it asserts does.

A session with people is optional. If one is held, set `run: workshop`, name the participants, and apply the same rules.

## Readiness

| Map state | Meaning | Action |
|---|---|---|
| Open questions or assumptions | **Not ready** | Ask; draft no criteria |
| A rule with no satisfying or no breaking example, or no boundary example | The rule is not yet understood | Find the example or ask |
| Many examples under one rule | Redundant rows, or the rule hides several | Prune, or divide the rule |
| Six or more rules | The story may be too big | Propose a split |
| No questions at all | Well understood, or not probed | Ask "what could go wrong?" for each rule once more |
| None of the blockers above | **Ready** | Present for approval |

Ready means the story can have criteria drafted. It is not the product owner's approval.

## Boundary with neighbouring skills

| Skill | Owns |
|---|---|
| `user-story-writing` | The card, seed example and story splitting patterns |
| **This skill** | Rules, examples, questions, readiness; `ideate/example-maps/US-n.md` |
| `acceptance-criteria` | Given/When/Then, criterion IDs `AC-US-n.m`, testability; `ideate/acceptance-criteria/US-n.md`, citing this map by path |
| `bdd-feature-file` | Feature files, scenario titles, tags and outlines (Implement, test-strategist) |

The map therefore contains no Given/When/Then, no criterion IDs and no scenario names. Not every example becomes its own scenario; the later skills decide that without dropping a rule. Use the product's own terms (`glossary-management`), and run `methodology-review` before hand-off.

## Gotchas

- **"I'll pick the sensible answer and note it."** *Reason:* a plausible guess reads as agreed and reaches code. *Instead:* leave Q-n open with your recommendation.
- **"Show the criteria as a draft while the questions are open."** *Reason:* a draft gets built from. *Instead:* give the map and questions; criteria wait.
- **"The example: the user can cancel in time."** *Reason:* it restates the rule and tests nothing. *Instead:* "booked for Sat 14:00, cancelled Thu 13:59 → refunded in full".
- **"Only the happy path is in the story."** *Reason:* the gaps live in counter-examples and limits. *Instead:* test just under, on and just over each limit.
- **"The page must load in 2 seconds" as a rule.** *Reason:* a quality target belongs to the NFR specification. *Instead:* cite the NFR ID; if none exists, ask.
- **"The business rule is wrong here, so I'll reword it."** *Reason:* a cited BR-n or fit criterion is not the map's to change. *Instead:* show the conflicting example and ask.
- **"It's built already; map what it does."** *Reason:* observed behaviour is not an agreed rule, and discovery is the point. *Instead:* mark unsourced behaviour as assumptions and ask whether it is intended.
- **"Ready now, the last question can wait."** *Reason:* it blocks. *Instead:* get the answer, or the product owner's agreement to move that case to another story and remove it here.
- **"Three amigos agreed."** *Reason:* nobody met. *Instead:* say one agent played all three.

## Files

| File | When to open it |
|---|---|
| `./templates/example-map.md` | Writing the artifact |
| `./scripts/validate-example-map.sh` | Before hand-off, and after every edit |
| `./resources/checklist.md` | After the script passes |
| `./references/probing-for-rules-and-examples.md` | Finding rules, examples, edges; pruning |
| `./references/answers-splits-and-changes.md` | Answers arrive, a split is needed, or an approved map must change |
| `./examples/01-lean-village-hall.md` | A small product, or a request to skip the map |
| `./examples/02-standard-parcel-locker.md` | Counter-examples, cited targets, a case moved to a new story |
| `./examples/03-enterprise-subscription-refund.md` | Tenants, regulation, many questions, answers folded back |
