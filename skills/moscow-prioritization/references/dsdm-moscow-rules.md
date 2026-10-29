# DSDM MoSCoW Rules — Categories, the Must Set, Contingency, Levels and Negotiation

Self-contained reference for `moscow-prioritization`. Read it before binning any release, whenever a Must is contested, when someone asks for a capacity percentage or person-week estimates, and when a release's priorities change. The Kano cross-check is in `moscow-and-kano.md`.

Grounded in the DSDM Agile Project Framework (Agile Business Consortium; DSDM Atern before it; the MoSCoW acronym is Dai Clegg's), with Thomas and Angela Hathaway, *Getting and Writing IT Requirements in a Lean and Agile World* (the necessity test), Jeff Patton with Peter Economy, *User Story Mapping* (the walking skeleton, crediting Alistair Cockburn) and Mike Cohn, *User Stories Applied* (value, cost, risk and knowledge). MoSCoW is DSDM's: do not credit it to Cohn, Patton or the Hathaways.

---

## 1. Why MoSCoW exists: fixed time and quality, variable features

A traditional project fixes the features and lets time and cost overrun. DSDM inverts the triangle: **time, cost and the agreed quality level are fixed at the start, and the features vary.** Two of DSDM's eight principles force this: *deliver on time* (the deadline is protected) and *never compromise quality* (quality is not traded for features). If neither the date nor quality can move, the only thing left to cut is scope, and the cut must be agreed **before** it is needed. MoSCoW is that agreement.

So MoSCoW is **not a ranking of importance**. It states what is **guaranteed** in a fixed timeframe and what is **contingency**.

---

## 2. The categories, precisely

### Must Have: the Minimum Usable SubseT

DSDM expands MUST as **Minimum Usable SubseT**. The defining test is **"what happens if this requirement is not delivered?"** It is a Must only if the honest answer is one of DSDM's signals:

| Signal | Meaning |
|---|---|
| **No point delivering** | Without it there is no reason to ship on the date at all: the core journey cannot be completed |
| **Illegal** | Shipping without it breaks a law, a regulation or a signed contract |
| **Unsafe** | Without it the solution would put people or property at risk |
| **Not viable** | Without it the solution cannot operate (a hard dependency of everything else) |

**The workaround clause.** Then ask: *"Is there any workaround, even a manual or painful one?"* If there is, it is **not a Must**; it is a Should or a Could. For an illegal or unsafe signal, a workaround counts only if it **still meets the obligation**: "officers email the status" does not meet a contract term that says "online status from go-live".

The Hathaways' **necessity test** ("what happens if we don't build this?") is the requirements-side form of the same question: with no consequential answer the item is a *preference* and must not compete with things that gate release. Priority is assigned by interrogation, never by how confidently a want was stated.

### Should Have

Important but not vital. Leaving it out may hurt, but the release is still viable. There is often a workaround: managing expectations, some inefficiency, an existing tool, paperwork.

### Could Have

Wanted or desirable, but less important than a Should. Leaving it out has a smaller impact. **The Coulds are the main contingency**: the first thing dropped when the release runs late.

**Should vs Could** is decided by **how much pain** leaving it out causes, measured as business value lost or the number of people affected. "The front desk phones twelve patients a day" is more pain than "one steward re-keys a rare extension".

### Won't Have this time

Agreed by the product owner and the team as **not delivered in this timeframe**, and recorded, because writing it down clarifies scope and stops the same request being re-raised. "This time" is part of the name: it means **not now, not never**.

| Disposition | Meaning | Where it goes |
|---|---|---|
| **Won't this time** | Valid, deferred | This artifact, with a reason (often the workaround) and a look-again point (a release or a trigger) |
| **Closed** | Will never be built | Closed, not parked as a Won't |
| **Could** | Might be built this release if the Musts and Shoulds land | The contingency list |

---

## 3. The Must set as a whole: usable, and equal to the walking skeleton

"Minimum *Usable*" means the Musts **together** make a solution that works for its purpose. After the story-by-story test, test the set: **can the primary user complete the core journey end to end using only the Musts?** A Must set with a step missing is not a usable subset, so it fails DSDM's own definition.

This is exactly Patton's walking skeleton: the thinnest slice that works end to end across the whole backbone, however ugly. DSDM states the idea as a priority category, Patton as a shape on the map. This plugin's decision (D045) joins them: **the release Musts are the Minimum Usable SubseT, which is the walking skeleton**, checked both ways.

| Direction | Check | If it fails |
|---|---|---|
| Skeleton → Must | Every story on the skeleton is a Must for this release | The workaround clause found a workaround? The story leaves the skeleton (to contingency or a later slice), the workaround becomes a named manual cell ("(manual: steward keys open loans on day one)"), and the end-to-end test is re-run |
| Must → skeleton | Every Must for this release is on the skeleton | Not needed to walk and not legal, safety or regulatory? **Demote it.** Legal, safety or regulatory? **Add it to the skeleton** at the step it protects, marked with its rule ("US-42 (regulatory: personal data)") |

DSDM never mentions story maps, so "a legal Must is added to the skeleton" is this plugin's reading of "usable"; it keeps the two lists identical. The story map proposes the skeleton; MoSCoW confirms it and, when its tests move a story, hands the re-cut back to `story-mapping` (at enterprise, as a re-cut log entry). At lean the backlog's closing Must / Won't-this-time block *is* the skeleton list.

**A gap in the Musts is fixed by adding the missing step** (a story, or a named manual cell), never by accepting the hole. If no honest Must can fill the step, the release goal is wrong: put that to the product owner.

---

## 4. Levels, decomposition and re-prioritising

DSDM applies MoSCoW at three levels, and the same requirement can carry a different priority at each:

| Level | In this plugin | Who sets it |
|---|---|---|
| **Project** | The **provisional priority** on requirements, epics and stories: high / medium / low, or value and penalty 1–9 at enterprise (`requirements-analysis`, `epic-definition`, `user-story-writing`) | Written by the requirements-analyst, labelled provisional |
| **Release** | This artifact: Must / Should / Could / Won't this time for one release | The product owner, facilitated and recorded by the requirements-analyst |
| **Iteration** | In Implement, the release Musts first within each build iteration | The product owner, with the implementing agent |

**Decomposition.** When an epic is high (or a project-level Must), its parts do **not** inherit Must. Test each story: some are on the skeleton, some are Shoulds or Coulds (edge-case handling, a second input format, a convenience), some are Won't this time.

**Re-prioritise at every boundary.** Re-run MoSCoW at each release against that release's constraint. A Could in Release 1 can be a Must in Release 3 (a tenant-isolation story becomes a regulatory Must the day a second tenant goes live). Each Won't is re-examined at the release or trigger its row names: promoted, moved to a later point, or closed. At enterprise, record every change in a priority change log.

**Epic size as a relative weight.** Epics carry a structural size from their story count (S = 3–4, M = 5–7, L = 8–10; `epic-definition`). It may be used as a relative weight; it is never converted to person-weeks, days or points.

---

## 5. Contingency without person-weeks

### What DSDM recommends, and why

DSDM guides Must Haves to **no more than about 60% of the effort** of a project, increment or timebox, with Coulds about 20% and Shoulds the rest. The purpose is **contingency**: estimates are always wrong, and the Coulds (then the Shoulds) are the buffer that lets the Musts arrive on the fixed date and quality when they are. A timebox loaded with Musts has no buffer, so the first surprise breaks the deadline. DSDM also says the percentage should be **lower** when estimates are less trustworthy: a new technology, an unfamiliar domain, no estimating track record. 60% is a ceiling on risk, not a target to fill.

### Why this plugin drops the percentage (D045)

The ratio needs effort estimates in person-weeks. In this plugin AI agents build the product: there is no team capacity in person-weeks, no skill produces such estimates, and stories deliberately carry no size field. An agent-built product also has no estimating track record, which is the case where DSDM itself says to lower the percentage. A computed "Musts = 56% of 16 person-weeks" would be false precision built on invented numbers. **Never invent estimates to compute it.**

### The three structural checks that keep its purpose

| Check | Passes when | Fails when |
|---|---|---|
| **Usable** | The Musts equal the walking skeleton, both ways, and walk end to end | A Must off the skeleton (not legal), a skeleton story not a Must, a gap |
| **Droppable** | A non-empty Should / Could tier exists and is **listed in cut order**: Coulds first, then Shoulds by least pain, a protected Delighter last; stories that only work together drop together | No Shoulds or Coulds, or a list with no order |
| **Workaround-free** | Every Must records "no workaround" (or "none that meets <obligation>") | A Must whose own row names a workaround |

When a check fails and re-testing does not fix it, **escalate to the product owner** with the options: keep the Musts at the skeleton and the rest as contingency; narrow the release; move the date; or accept a release with no contingency, recorded as a risk. The analyst never chooses for them.

### The constraint to state instead of capacity

Name what really binds an agent-built release: the **release date** the product owner set (if any), the **quality bar** (NFRs, legal obligations), and the **model and review budget** (how much the product owner can review and accept before the date). The contingency list is what gives way when any of them is under pressure.

### The optional report-only share (enterprise)

At enterprise the artifact may carry one line: *"Musts are 8 of the 35 stories in scope (23%) by count."* Where epics differ greatly in size, weight each epic's Must fraction by its size (S = 1, M = 2, L = 3) and label the figure **approximate**. Worked: EPIC-A (M, 6 stories, 1 Must) and EPIC-B (S, 4 stories, 2 Musts) give (1/6 × 2 + 2/4 × 1) / (2 + 1) ≈ 28%. The line is a prompt to look harder at a high share, **never a pass / fail threshold**, and it is never written at lean or standard.

---

## 6. The prioritisation agreement and who decides

DSDM advises agreeing the rules **before** any prioritisation, so the categories are not re-argued under deadline pressure. The artifact opens with:

- **Constraint:** the release (and date, if set), the quality bar, the review budget.
- **Who decides:** the product owner. DSDM's priority belongs to the business roles: the **Business Visionary** (project level) and the **Business Ambassador** (release and iteration level). In this plugin the product owner holds both. The requirements-analyst is DSDM's **Business Analyst**: facilitates, records, never decides a contested priority.
- **What drops first:** the contingency list, in its order.
- **Escalation:** a disputed Must goes to the product owner with the Must test, the workaround found, and the skeleton consequence.

Consulted parties (a design partner, a tenant's service manager, the board) give evidence; they do not hold the decision.

---

## 7. Negotiating contested items

The argument is never "how important is this?"; it is always "what happens to this release if it is not delivered, and is there a workaround?"

| Situation | Technique | What it forces |
|---|---|---|
| A stakeholder calls their item Must | Run the Must test and the workaround clause out loud | Only items with a signal and no workaround stay Must |
| "Everything is important" | Concede importance; MoSCoW ranks what is **guaranteed**, not importance | Separates "matters" from "gates this release" |
| "The epic is high, so its stories are Musts" | Test each story (DSDM decomposition) | Edge cases and conveniences fall to Should / Could |
| A Kano-Basic is called an automatic Must | Second look with the Must test; Basic is a satisfaction class (`moscow-and-kano.md`) | Promotion only on a Must signal with no workaround |
| A Should that always ships anyway | If it truly gates the release, test it as a Must; otherwise hold the line | Removes Musts in disguise without silently promoting |
| Musts outgrow the skeleton, or no contingency is left | Stop and escalate (§ 5) | A scope decision by the product owner, recorded |
| Deadlock between stakeholders | Escalate to the product owner, never to consensus or seniority | One accountable decision |

---

## 8. Ordering the contingency: Cohn's four factors

Cohn (*User Stories Applied*) weighs each story on four factors: **financial or business value**, **cost** to develop, **risk removed** and **knowledge gained**. Use them for what MoSCoW leaves open: the order of Shoulds and Coulds in the cut list, and which contingency to build first. They never make a Must.

- A **spike** that unblocks a Should goes early: its value is the knowledge, and it carries the priority of the story it unblocks.
- A story that removes a delivery risk (an unfamiliar reply format, a third-party GIS) is built before a same-value story that does not.
- Stories that only work together (a GIS-based checklist and its outage fallback) sit together in the list and drop together.
- A Kano-Delighter is cut last among its tier (`moscow-and-kano.md`).

Use relative comparisons ("US-3 removes more risk than US-8"), not a computed score with invented numbers.

---

## 9. Quick reference: the disqualifiers

- A Must with no DSDM signal, or with a workaround → demote.
- A Must off the skeleton that is not legal, safety or regulatory → demote; one that is → add it to the skeleton.
- A skeleton story that is not a Must → move it off and name the manual cell, or make it a Must.
- No Should / Could tier, or one not in cut order → not prioritised; escalate if it cannot be fixed.
- A Won't with no reason or no look-again → incomplete.
- Person-weeks, story points or a "Must %" gate → remove; the plugin has no estimates.
- MoSCoW words on a card or epic before this step → provisional priority only.
- At lean, a `moscow.md` → write the closing Must / Won't-this-time block in `ideate/user-stories.md` instead.
