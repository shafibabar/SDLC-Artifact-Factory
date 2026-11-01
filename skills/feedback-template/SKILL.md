---
name: feedback-template
description: >
  Teaches how to capture and triage feedback in Customer Validation into a
  feedback log: one structured item per finding from a UAT failure, a beta
  check-in, an exploratory session debrief, an ad hoc report, or a lost
  trial or churned customer. Covers story-based capture (a specific past
  event), Mom Test question design for check-ins (no pitch, past tense, no
  "would you"), filtering compliments, fluff and ideas, converting a feature
  request into the underlying customer need, deduping by cause rather than
  symptom, the house severity scale, routing each item to the agent that owns
  it (which engineer for a bug; the requirements-analyst for a missing
  capability; the win/loss log for positioning feedback), and rolling items up
  by symptom and by customer need, so a single loud report is not a pattern
  and a confirmed pattern reaches acceptance-sign-off. Use when logging
  feedback, writing check-in questions, deciding what a piece of feedback
  means or who owns it, or summarising a feedback log. Used by the
  requirements-analyst agent; written to customer-validation/feedback/<date>.md.
version: 3.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-07-20
tags: [customer-validation, feedback, feedback-triage, mom-test, severity, routing, opportunity, win-loss, exploratory-debrief]
produces: feedback-log
domain: validation
status: stable
related: [uat-scenario, uat-plan, beta-program-design, acceptance-sign-off, opportunity-solution-tree, jtbd-analysis, user-persona, competitive-analysis, gtm-strategy, moscow-prioritization, risk-register, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/testing/explore-it-hendrickson.md
  - research/product-strategy-and-gtm/loved-lauchengco.md
  - research/product-strategy-and-gtm/continuous-discovery-habits-torres.md
---

# Feedback Template

## Purpose

Feedback is only evidence once it is captured in a shape that can be compared, interpreted for the need behind it, and handed to whoever owns it. "The customer wasn't thrilled with the report" cannot be triaged, rolled up, or used to defend a sign-off. This skill turns raw feedback into **feedback items** in a **feedback log**.

The requirements-analyst captures, interprets and routes; it never fixes a bug or redesigns a screen itself.

| Owned here | Owned elsewhere |
|---|---|
| The item shape; check-in question design; filtering bad data; dedupe; **the severity scale** (the one copy; `uat-scenario` points here); routing; the symptom and customer-need rollups | What an open defect allows at sign-off, and treating a blocking pattern as High: `acceptance-sign-off` · exploratory charters and sessions: `uat-plan` · scripted results: `uat-scenario` · the opportunity space: `opportunity-solution-tree` · the win/loss log: `competitive-analysis` |

## 1. Where Feedback Comes From

| Source | What arrives | Note |
|---|---|---|
| **UAT failure** | A Fail or Blocked from `uat-scenario` | One item per failure; its severity is set at the scenario |
| **Beta check-in** | Notes from a structured check-in (`beta-program-design`) | Facts and quotes, then filtered (§ 4) |
| **Exploratory debrief** | A session's findings from `uat-plan`'s charter | Hendrickson (*Explore It!*): the debrief records what the session found, including what no scenario expected. Each finding becomes an item; questions for a further session go back to `uat-plan` as new charters, not into the log. A finding that recurs from an earlier release is a standing exposure: log it and add it to `risk-register`, never close it as a one-off |
| **Ad hoc report** | An email, a support ticket, a message | Captured the same day; Critical and High triaged the same day |
| **Lost trial or churn** | "We went with a spreadsheet", "we chose a rival" | Positioning evidence (§ 5), not only a product complaint |

## 2. Capture One Item per Finding

Every item has the same fields (`./templates/feedback-item.md`): ID and title; source; **reporter by role** (and organisation or tenant), never a product-specific persona list; date; **context as a specific past event**, in the reporter's words (Torres, *Continuous Discovery Habits*: collect stories, not opinions); expected vs actual; category; severity; underlying need; supporting detail; routed to; rollup notes.

One finding, one item. Five complaints in one email are five items, so each can be routed and counted.

## 3. Ask So the Answers Are Facts

In a check-in the facilitator surfaces what happened, not confirmation of what the team believes. Fitzpatrick's **Mom Test** (*The Mom Test*):

1. **Talk about their life, not your idea.** No demo or pitch before the questions.
2. **Ask about specific past behaviour.** "Walk me through the last time you…", never "Would you use…?" or "How much would you pay?"
3. **Talk less, listen more.** When they complain, ask what they did next, not whether a proposed fix would help.

End by asking for a **commitment**: the next session on the calendar, an introduction, real data, a paid pilot. Write the guide from `./templates/check-in-guide.md`; question pairs and scripts: `./references/mom-test-question-design.md`.

## 4. Filter Bad Data Before Logging

| Type | Sounds like | What to log |
|---|---|---|
| **Compliment** | "It's great", "love it" | Nothing on its own. Ask for the last time they used it. A **positive signal** is logged only when it rests on behaviour ("ran last month's close in it, two days faster") |
| **Fluff** | "I always…", "I'd definitely…" | Nothing until a specific instance is named |
| **Idea** | "You should add a dashboard" | The **underlying need** behind it, as a missing-capability item; the requested feature goes in supporting detail |

## 5. Triage Each Item

1. **Dedupe by cause, not symptom.** Merge items only when the cause is the same. The same symptom with different causes stays separate: at two tenants "the export is slow" may be a large estate at one and a misconfigured region at the other.
2. **Interpret the underlying need.** Write it in the customer's voice, at a level where more than one solution could meet it, tagged with the moment in their workflow. This is Torres's **opportunity**, and it is what `opportunity-solution-tree` places on the tree.
3. **Set severity once, at capture**, from the impact on the reporter, on the house scale in `./resources/severity-and-routing.md`. The scale is **this plugin's house rule**, not an industry standard and not from the research library; it exists so every source uses the same four words. Never adjust it later to make an exit criterion pass. What each severity allows at sign-off is `acceptance-sign-off`'s defect rule.
4. **Route to the one owner** (`./resources/severity-and-routing.md`):
   - a bug goes to the engineer who owns the broken part: backend, frontend, data, platform or security, never just "engineering";
   - UX friction goes to the `ux-architect`;
   - a **missing capability goes to the requirements-analyst**: a requirement or story for a later release (`moscow-prioritization`) and an opportunity on the tree, never a silent Must for this release. Escalate to the `product-strategist` only when the gap challenges the positioning or the ICP;
   - **positioning feedback** ("we went back to our spreadsheet", "we chose a rival") is never skipped as a one-off preference. Record it in `competitive-analysis`'s win/loss log **and** flag it to `gtm-strategy` as a possible **Positioning Refresh Trigger**: the alternative the customer chose, for which job, and the reason given. The product-strategist decides whether the positioning changes. Lauchengco (*Loved*): positioning is a hypothesis tested against real market contact, and this is that contact.

## 6. Roll Up: Symptoms and Customer Needs

The log's summary has **two rollups**:
- **By symptom and cause**, for defect handling: reports, independent reporters, severity, status.
- **By customer need**, for discovery: each need heard, how many independent stories mention it, and the parent opportunity it sits under (Torres). A feature asked for by five people is one need counted five times, not five features.

**One report is a data point.** A pattern needs independent reporters with the same cause; one participant repeating themselves is one concern. A loud single Low or Medium is logged and watched, never escalated as if three people said it. A **confirmed pattern** is named in words for the sign-off ("3 of 4 partners independently missed the export on the report page"); when it blocks a Must flow, `acceptance-sign-off` treats it as High. A single Critical needs no pattern.

## Scale

`phase-requirements.json`: `feedback-log` is **optional at every profile**; it becomes the evidence behind the sign-off whenever one is kept.

| Profile | Shape |
|---|---|
| **lean** | A short list of items in one file; often a single ad hoc report. `./examples/01-lean-single-report.md` |
| **standard** | Items per check-in and UAT window; both rollups. `./examples/02-standard-check-in.md` |
| **enterprise** | Per-tenant items, dedupe across tenants by cause, patterns named for the sign-off, positioning routed to win/loss. `./examples/03-enterprise-multi-tenant.md` |

## Producing the Log

1. Start `artifacts/<product>/customer-validation/feedback/<date>.md` from `./templates/feedback-log.md`.
2. **Before a check-in**, draft the guide (§ 3); the user, or the design partner's session, holds the conversation, and the agent works from their notes.
3. **Capture** one item per finding (§ 2), **filter** (§ 4), **triage** (§ 5).
4. **Roll up** (§ 6) and list positive signals that rest on behaviour.
5. **Present it to the user**: each route and each pattern named for the sign-off. Cross-check `./resources/severity-and-routing.md`.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Free-text notes** | Cannot be triaged, routed or counted |
| **Leading the witness** | "That worked well, right?" manufactures agreement |
| **A compliment logged as a positive signal** | Costs the speaker nothing and predicts nothing |
| **A feature request logged as a requirement** | Records the customer's guess at a solution, not their need |
| **Dedupe by symptom** | Hides a second cause; one fix closes only one tenant's problem |
| **"Route to engineering"** | Nobody in particular owns it |
| **Missing capability sent to strategy** | Strategy is approved; requirements are the requirements-analyst's |
| **Positioning feedback filed as a bug** | The win/loss evidence never reaches positioning |
| **One loud report treated as a pattern** | Forces scope changes on noise |
| **Severity moved to hit a number** | Defeats the sign-off |
| **The scale presented as a standard** | It is a house rule; say so |
| **A product's personas as a required field** | Ties the skill to one product; use roles |

Use canonical terms from `glossary-management`: **Acceptance Testing**, **User Acceptance Testing**, **Residual Risk**. Run `methodology-review` before hand-off.
