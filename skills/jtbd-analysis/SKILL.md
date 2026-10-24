---
name: jtbd-analysis
description: >
  Teaches how to write the Jobs To Be Done (JTBD) analysis artifact in Ideate: one
  solution-free job statement per core job (Ulwick: verb + object + contextual
  clarifier) as the stable anchor, with job stories beneath it, one per situation
  (Klement / Intercom: When…, I want to…, so I can…); the job spec (functional,
  emotional and social dimensions, obstacles, purchase and use experiences); what
  gets fired, including non-consumption; Big Hire vs Little Hire; the four forces of
  progress (push, pull, anxiety, habit); and desired-outcome statements ranked by
  opportunity (compare-and-contrast at 3–5 design partners, the opportunity score
  only for larger samples). Also writes the story-based or switch-interview guide
  before a customer conversation and the dated one-page interview snapshot after
  it: the user or a design partner interviews, the agent never does. Use when
  analysing customer jobs, writing job statements or job stories, running or
  planning JTBD, switch or customer-discovery interviews, synthesising interview
  notes, finding competing alternatives, or scoring underserved needs. Used by the
  requirements-analyst agent in Ideate (/sdlc-ideate) after user personas and
  before the impact map; skipped at lean, where JTBD folds into the persona.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, jobs-to-be-done, job-statement, job-story, forces-of-progress, switch-interview, interview-snapshot, opportunity-score, discovery]
produces: [jtbd-analysis, interview-guide, interview-snapshot]
domain: discovery
status: stable
related: [user-persona, user-story-writing, moscow-prioritization, business-model-canvas, impact-mapping, competitive-analysis, gtm-strategy, requirements-analysis, feedback-template, strategy-kernel, nfr-specification, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/competing-against-luck-christensen.md
  - research/product-strategy-and-gtm/continuous-discovery-habits-torres.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/product-strategy-and-gtm/lean-product-playbook-olsen.md
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/human-ai-collaboration/unleash-creativity-with-ai-bier.md
---

# Jobs To Be Done Analysis

## Purpose

A **job** is the progress a person is trying to make in a particular circumstance (Christensen et al., *Competing Against Luck*). People do not buy products; they **hire** them for a job, and every hire **fires** something: a spreadsheet, a consultant, a habit, or nothing at all. The **circumstance**, not the customer's attributes, is the causal unit: demographics correlate with purchases but do not cause them. The milkshake bought on a long morning commute competed with bagels and boredom, not with other milkshakes. That is why this artifact is organised by job and situation, and why the persona (who) and the job (why and when) are separate artifacts.

The job is stable while solutions churn. Design for the job, not for today's workaround.

## Where It Sits

```
Ideate: user personas ─► JTBD ANALYSIS ─► impact map ─► functional requirements ─► epics ─► stories …
                ▲  interview guides (before) and dated interview snapshots (after) feed it, weekly
```

| Reads | What it takes |
|---|---|
| `user-persona` | One job statement per persona, and the Trigger / Current approach / Adoption barrier fields, which are **push / habit / anxiety** in persona form. Refine them here; never restate the personas |
| Interview snapshots | The evidence. Each job story cites at least one |
| `competitive-analysis`, `gtm-strategy` | Competitive alternatives and the ICP, checked against what customers actually fired |

| Feeds | What it gives |
|---|---|
| `business-model-canvas` (Value Proposition Canvas) | Job statements and ranked outcomes, cited by ID, never re-gathered |
| `impact-mapping` | Job stories explain the HOW behaviour changes of each actor |
| `requirements-analysis`, `user-story-writing` | Each job story's implied capability; every requirement traces to a job statement and a story beneath it |
| `competitive-analysis`, `gtm-strategy` | What gets fired, including non-consumption: the real competitive set |
| Onboarding and NFRs | Obstacles, purchase and use experiences, consumption jobs and the Little Hire, as onboarding requirements |
| An opportunity space | Each snapshot's "opportunities heard", in the customer's voice, ready for a later opportunity-mapping step to place |

## Who Does What: the User Interviews, the Agent Synthesises

The agent **cannot hold a customer conversation**. The user (or a design-partner session the user runs) is the interviewer. The agent:

1. **Before**, writes the **interview guide**: a story-based prompt, or a switch-interview timeline for someone who recently switched, plus probes and the question the user is most afraid to ask. Every question in it, including that one, asks about a specific past event or the present; none starts "would you" or "if … tomorrow". Template: `./templates/interview-guide.md`.
2. **After**, turns the user's raw notes into a one-page **interview snapshot**, one per conversation, saved as a dated file. It is marked as synthesised from notes the agent did not witness. **Every job story in the analysis cites at least one snapshot**; tell the user so when handing over a guide. Template: `./templates/interview-snapshot.md`.
3. **Labels every job, story, force or outcome without a snapshot behind it `[assumption]`**, with the question that would confirm or overturn it. An agent never claims evidence that no conversation produced.

Snapshots are **evidence, not approved artifacts**: one new dated file per conversation (`ideate/interviews/snapshots/<yyyy-mm-dd>-<participant>.md`), so the weekly discovery loop (Torres, *Continuous Discovery Habits*) adds files instead of reopening the approved analysis. The analysis is revised only when the evidence changes a job, a force or a ranking.

How to run each interview type, the switch timeline, Mom-Test question rules (Fitzpatrick), screening interviewees (Blank), the snapshot fields and the weekly loop: `./references/interviewing-and-synthesis.md`. Read it before writing any guide or snapshot.

## Two Formats, Both Named in the Artifact

| Format | Shape | Source | Role |
|---|---|---|---|
| **Job statement** | `[verb] [object] [contextual clarifier]`, one line, solution-free | Ulwick, Outcome-Driven Innovation | The **stable anchor**: one per core job. Would it have existed fifty years ago? |
| **Job story** | `When [situation], I want to [motivation], so I can [expected outcome]` | Intercom (Paul Adams's team), popularised by Klement, *When Coffee and Kale Compete* | The **situational layer**: one per situation in which the job comes up, each under one job statement |

Label both by name in the artifact so no reader confuses them. The motivation clause carries the most risk: "I want to see a prioritised list of gaps" is a product output; "I want to know which gaps could fail the review before the reviewer finds them" is the motivation, and only the second survives a different solution. The job types table (core, related, consumption-chain, emotional, the buyer's financial job) and the executor / beneficiary / buyer split are also Ulwick's. Both formats in full, the schools compared (Christensen / Moesta, Ulwick, Klement), the job types and the job spec: `./references/job-formats-and-types.md`.

## The Job Spec: More Than Three Dimensions

For each core job, record:

- **Dimensions**: functional, emotional and social. Never functional only.
- **What gets fired**: what the customer used before, **including non-consumption** (nobody does this until the auditor asks). It is the real competitive set; hand it to `competitive-analysis`.
- **Big Hire vs Little Hire**: one line on what wins the purchase, one on what brings the user back on an ordinary Tuesday. A product can win the Big Hire and lose every Little Hire (shelfware).
- **Obstacles** and the **purchase and use experiences** the job demands. With consumption jobs and the Little Hire, these become **onboarding requirements**.
- **Forces of progress** (Moesta and Spiek, in *Competing Against Luck*): push and pull for change against anxiety and habit, one row each, each quoting a specific event from a snapshot. Gather them with the switch-interview timeline.

## Ranking: Score Outcomes, Not Jobs

Opportunity scoring applies to **desired-outcome statements within a job**, not to whole jobs. Ulwick's syntax is `[direction] + [metric] + [object of control] + [contextual clarifier]` ("Minimize the time it takes to confirm that a newly connected source is fully classified"). A score on a whole job is a category error.

| Sample | Method |
|---|---|
| A handful of design partners (3–5) | **Compare-and-contrast** (Torres) is the default: compare sibling outcomes on sizing, customer importance and how badly they are served today, and pick a **target**. Any 1–10 ratings are labelled directional, never presented as a survey result |
| A sample that supports a survey, per segment | Importance and satisfaction per outcome; **Opportunity = Importance + max(Importance − Satisfaction, 0)** (Ulwick; Olsen, *The Lean Product Playbook*). Rank **separately per segment**: a blended average hides one segment's underserved outcome |

Worked ranking at both sample sizes, the job map and outcome syntax: `./references/outcomes-and-ranking.md`. Read it before ranking anything.

## Producing the Artifact

1. **Check the profile.** At lean there is no artifact: see Scale.
2. **Gather the evidence.** List the snapshots. With none, offer the user an interview guide first. If they want the draft anyway, write it with every item `[assumption]` and `evidence: none` in the frontmatter. With no interviewee, ask the core-job question twice: straight, then as a sceptical customer would answer it (Bier, *Unleash Your Creativity with AI*), so the agent does not anchor on its first plausible job.
3. **Write one job statement per core job** (usually per primary persona), refining the persona's line. Check its altitude: a task inside a job ("export a CSV") is too low; the job is what the task is *for*.
4. **Write the job spec**: dimensions, what gets fired, Big and Little Hire, obstacles, experiences, forces table.
5. **Write job stories**, one per situation (typically the trigger, the routine case and the high-stakes case), each citing a snapshot.
6. **Write and rank desired outcomes** with the method the sample supports.
7. **Derive onboarding requirements, related jobs and implied capabilities**; list open assumptions with their validation questions.
8. **Validate** against `./resources/jtbd-checklist.md`; run `python3 ./scripts/check-jtbd-analysis.py <artifact>`; write `ideate/jtbd-analysis.md` from `./templates/jtbd-analysis.md` and present it to the user for review before the impact map.

JTBD finds out whether a job is real and worth solving. It does not test whether a particular solution solves it (Cagan, *Inspired*): never show a concept in a discovery interview.

## Scale

`phase-requirements.json` **skips** this artifact at lean and **requires** it at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | No `jtbd-analysis` file. JTBD folds into each persona: the job statement, one or two job stories and a one-line forces summary, labelled proto (`user-persona`). The interview guide and snapshots still apply whenever the user talks to someone: `./examples/01-lean-lunch-tracker.md` |
| **standard** | The full artifact: job statements, job stories per situation citing snapshots, the job spec with a forces table, what gets fired, Big and Little Hire, onboarding requirements, and desired outcomes ranked by compare-and-contrast from design partners: `./examples/02-standard-ledgerline.md` |
| **enterprise** | Adds Ulwick's **job map** with desired-outcome statements per step, the executor / beneficiary / buyer split per tenant role, and outcomes ranked **per segment**; numeric opportunity scores only where a survey sample supports them: `./examples/03-enterprise-platform.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **One format under two names** | A job story headed "job statement", or the reverse: readers cannot tell the anchor from the situation |
| **Solution-shaped job or motivation** | "When I open the dashboard…", "I want to see the report": names the product, so the job dies with it |
| **Task altitude** | "Export a CSV of flagged files" is a step inside a job; the job is what the export is for |
| **Scoring whole jobs** | "J1: 9 + (9 − 3) = 15": ODI scores outcomes within a job |
| **Survey maths at n = 4** | Four ratings averaged as if they were a market; compare and contrast instead |
| **Blended segments** | One average over two segments hides the outcome one of them is underserved on |
| **Agent as interviewer, or invented evidence** | The agent cannot hold the conversation; a story with no snapshot is `[assumption]` |
| **Hypothetical questions** | "Would you use…?", "How much would you pay?": fluff, not evidence (Fitzpatrick) |
| **Competitors only** | Ignoring what gets fired, especially non-consumption, misses the biggest market |
| **Pull only** | Designing more features while the customer's anxiety and habit go unaddressed |
| **Backwards JTBD** | Jobs written to justify the roadmap: every implied capability matches a planned feature |
| **Editing the approved analysis weekly** | New evidence goes into a new dated snapshot; the analysis changes only when a job, force or ranking does |
| **Product-specific jobs as rules** | A compliance job required of every product; such jobs belong in examples |

Use canonical terms from `glossary-management`: **Jobs To Be Done (JTBD)**, **Job Statement**, **Job Story**, **Desired-Outcome Statement**, **Opportunity Score**, **Forces of Progress**, **Switch Interview**, **Interview Snapshot**, **Big Hire / Little Hire**, **Non-Consumption**, **Competitive Alternative**, **Persona**. Run `methodology-review` before hand-off.
