---
name: architecture-evaluation
description: >
  Check a design against its quality-attribute scenarios once the container
  diagram and the first ADRs exist, as a lightweight self-check by the designing
  agent (not independent, not a full ATAM): evaluate the architecturally
  significant scenarios from nfr-specification, refusing wishes with no response
  measure and sending them back; run a tactics questionnaire per attribute
  (availability, performance, modifiability, security, testability, usability,
  deployability); record risks, non-risks with their reason, sensitivity points,
  trade-off points and risk themes; never hide a trade-off, resolving it in an
  ADR or recording an accepted reason; propose fitness functions, objective
  automated checks that a characteristic still holds; sized to the profile.
  Use when evaluating, reviewing or re-checking an architecture against its
  NFRs, or when asked for an ATAM or an architecture review. Used by
  enterprise-architect.
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
tags: [design, architecture, evaluation, quality-attributes, tactics, trade-offs, fitness-functions, risks]
produces: architecture-evaluation
domain: architecture
status: stable
related: [nfr-specification, adr-authoring, container-diagram, component-diagram, integration-design, multi-tenancy-design, event-storming-facilitation, glossary-management, methodology-review]
sources:
  - research/software-architecture/software-architecture-in-practice-bass.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/just-enough-software-architecture-fairbanks.md
---

# Architecture Evaluation

## Purpose

A design is only as good as the scenarios it was checked against, and nothing else in the pipeline checks it: the NFR specification says what must hold, the container diagram and ADRs say what was chosen, and no step asks whether the choices serve the scenarios. This skill does that, honestly sized. **Readers:** enterprise-architect, the product owner (which risks the design carries, and what each trade-off costs), backend-engineer and platform-engineer (the fitness functions to build). **Question:** does the design, as it stands, meet its highest-impact scenarios, and where does it not, or only at a cost?

It is a **lightweight, in-house evaluation** after Bass: the same scenario analysis as an ATAM, without the many stakeholders, outside team and several days a full ATAM assumes. Here the agent that designed the architecture also evaluates it, so the record says plainly that it is a **self-check**, not an independent review and not an ATAM (`./references/lightweight-vs-atam.md`). The output is `artifacts/<product>/design/architecture/architecture-evaluation.md` (`./templates/architecture-evaluation.md`), required at every profile. Scenarios and the utility tree stay with `nfr-specification`; each resolved trade-off is recorded with `adr-authoring`; the diagram-level fitness functions are in `container-diagram` and `component-diagram`.

| Profile | What the record holds |
|---|---|
| Lean | A tactics questionnaire on the top 2 or 3 scenarios, risks and non-risks, the fitness functions worth having; sensitivity and trade-off points only if met; no risk themes. With no scenario rated high on architectural impact, a short paragraph says so |
| Standard | The full record: every scenario in the Architecture Handoff evaluated, risks, non-risks, sensitivity and trade-off points, fitness functions; risk themes only where two or more risks share a cause |
| Enterprise | As standard, plus every trade-off point the NFR handoff carried resolved or carried on, risk themes tied to business drivers, and the product owner's confirmation at the Design gate |

## Procedure

1. **Read** the NFR specification and its Architecture Handoff, the container diagram, the ADRs written so far, the component diagrams if they exist, and `sdlc-config.json` (profile). Stop if the handoff or the container diagram is missing: there is nothing to evaluate against, or nothing evaluated.
2. **State that this is a self-check** and size it to the profile (Fairbanks: spend effort where being wrong costs most). At lean, keep to the top 2 or 3 scenarios.
3. **Choose the scenarios:** every scenario in the handoff rated high on architectural impact (standard, enterprise), the top 2 or 3 at lean. Each needs a response measure. A wish ("fast", "secure", "scalable") or a scenario with no measure goes back to `nfr-specification`; do not invent a target or write the scenario here.
4. **Find the approaches:** for each scenario, the containers, ADRs and tactics in the design that serve it.
5. **Run the tactics questionnaire** for the scenario's attribute (`./references/tactics-questionnaires.md`): per tactic family, does the design do it, where, and at what cost? An unanswered family is itself a finding.
6. **Classify each finding** (`./references/evaluation-vocabulary.md`): a **risk** (a decision that may leave the scenario unmet), a **non-risk** (judged safe, with the reason), a **sensitivity point** (a property critical to one response), a **trade-off point** (a property that moves two attributes in opposite directions). Carry the trade-off points the NFR handoff listed (`TP-n`).
7. **Group risks into themes** where two or more share a systemic cause, tied to the business driver they threaten (always at enterprise).
8. **Propose fitness functions** (`./references/fitness-functions.md`): for each hard rule or characteristic that must stay true, an automated check, where it runs, and who owns it.
9. **Route every trade-off point.** It passes `adr-authoring`'s risk gate: write an ADR with its `Trade-off:` line. It does not: record "accepted, no ADR" with the reason. It changes cost or scope: the user decides. Never relabel a trade-off a non-risk to save time.
10. **Validate and loop:** run `./scripts/validate-architecture-evaluation.sh <file>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
11. **Present** with the reason for every request declined (§ Gotchas). Always state, in the answer itself:
    - **What it is:** a lightweight self-check by the agent that designed the architecture, not independent and not a full ATAM (a full ATAM needs many stakeholders, an outside team and several days).
    - **Scenarios come from `nfr-specification`:** where one is missing, vague or has no response measure, name `nfr-specification` and list what it needs (each scenario with its stimulus, source, environment, response and response measure; ranked by business value and architectural impact; the Architecture Handoff with the architecturally significant scenarios and the trade-off points). Never supply a target or a number, and never route the gap to a person instead of the skill. Give no safe or unsafe verdict until the scenarios exist; say what can be examined meanwhile.
    - **Every risk and non-risk carries its scenario and a reason.** Show sensitivity points (a property critical to one response) and trade-off points (a property that is sensitive for more than one attribute in opposite directions, where an explicit decision is needed), and use the book's tactic family names for the attribute (for availability: detect, recover from and prevent faults; for performance: control resource demand and manage resources).
    - **No trade-off is hidden:** each is resolved in an ADR (it passes `adr-authoring`'s risk gate, cost of change times breadth of dependency times uncertainty, and the ADR carries a Trade-off line), or accepted with a reason, or, if it changes cost or scope, put to the user with the options and their costs.
    - **Fitness functions:** name at least one concrete check for this product (even when the evaluation must wait for scenarios, say which check you will propose); they are objective automated checks that run continuously and complement this one-time evaluation, not replace it.
    - **A finding that changes an approved artifact reopens it.** No implementation code appears in the answer.
    - Answering in a reply: the declined requests and their reasons once, then the record once, without its YAML frontmatter block.

Examples: `./examples/01-lean-toolshed-questionnaire.md` (a volunteer-built tool loan tracker asking for "a full ATAM"), `./examples/02-standard-rebound-reminders.md` (a reminder service with a durable-queue risk and a staleness trade-off in an ADR), `./examples/03-enterprise-permitry-residency-and-failover.md` (a multi-tenant, two-region platform: a trade-off point, a risk theme and the product owner's confirmation).

## Gotchas

- **"Run a full ATAM so we're covered."** *Reason:* a full ATAM needs many stakeholders, an outside team and days; here one agent designed and evaluates, so it cannot be one. *Instead:* the lightweight self-check, labelled as such, with the questionnaire sized to the profile.
- **"Evaluate the design" with no scenarios, or only "fast", "secure", "scalable".** *Reason:* an evaluation is a check against scenarios with response measures; against wishes it checks nothing. *Instead:* send the user back to `nfr-specification`, say what is missing, and do not invent targets or write the scenarios here.
- **"Call it a non-risk; we have no time."** *Reason:* a property that raises one attribute and lowers another is a trade-off point, and hiding it removes the decision the design has to make. *Instead:* record it as a trade-off point, resolve it in an ADR or record an accepted reason, and tell the user the cost.
- **"An independent review would say the same."** *Reason:* the designer evaluating its own design shares its blind spots. *Instead:* say so in the record, and for an enterprise product have the product owner confirm the risks at the gate.
- **"List the sensitivity points as trade-offs."** *Reason:* a sensitivity point governs one response (a pool size sets latency); a trade-off point is sensitive for two attributes in opposite directions. *Instead:* name which it is.
- **"Put the tactics and fitness functions in the NFR spec."** *Reason:* choosing a tactic is a design decision, and a fitness function checks a design. *Instead:* the NFR states scenarios and measures; this record holds tactics findings and fitness functions.
- **"A fitness function is a review we do once."** *Reason:* a fitness function is an objective, automated, continuously run check. *Instead:* name the check, where it runs and who owns it.
- **"Give every product the full record."** *Reason:* effort should follow risk; a small product does not need a utility tree and a theme analysis. *Instead:* the lean shape: top scenarios, risks and non-risks, fitness functions.

## References

| Question | File |
|---|---|
| The five outcomes defined, and how they map to the NFR handoff | `./references/evaluation-vocabulary.md` |
| The tactics questions per quality attribute | `./references/tactics-questionnaires.md` |
| What a fitness function is, examples, and the repo's own checks | `./references/fitness-functions.md` |
| What is kept from an ATAM, what is dropped, and why this is a self-check | `./references/lightweight-vs-atam.md` |
| The artifact | `./templates/architecture-evaluation.md` |
| Checking before hand-off | `./resources/checklist.md` |
