---
name: user-story-backlog
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: which users get which behaviours, from which epics, serving which KR>
profile: <lean | standard | enterprise>
status: <draft | approved>
linked-kr: <KR ID(s) from strategy/okrs.md>
linked-epics: <ideate/epics.md | none (lean: epic headings below)>
linked-requirements: <ideate/requirements.md | none (lean: the requirements header below)>
linked-jtbd: <ideate/jtbd-analysis.md | ideate/user-personas.md (lean: the persona carries the job)>
traces_to: strategy/okrs.md (<KR>); <linked-epics> (<EPIC-n>); <linked-requirements> (<UR-n, TR-n>); <linked-jtbd> (<J-n, JS-n.m>)
---

<!-- Copy into ideate/user-stories.md and fill. Delete these comments.
     LEAN: keep the Requirements Header and the closing Must / Won't-this-time
     block; delete Backlog Summary and Coverage. Epic headings carry a Trace line.
     STANDARD / ENTERPRISE: delete the Requirements Header and the closing block
     (the FRD and MoSCoW own those); keep Backlog Summary and Coverage. -->

# User Story Backlog — <Product>

**Translation.** <Which epics, user requirements and job stories become these stories, for example-mapping, acceptance-criteria and story-mapping.>

Priorities in this document are **provisional**. <standard/enterprise: `moscow-prioritization` finalises them. lean: the closing Must / Won't-this-time block finalises them.>

<!-- ===================== LEAN ONLY ===================== -->
## Requirements Header (lean: the backlog is the functional requirements)

**Translation.** <KR and the personas' job stories become the stories below; there is no FRD at lean.>

**Scope:** <what this cycle covers>
**Excluded:** <what it does not, each with a reason>

**Business rules**
- BR-1 (<fact | constraint | computation | inference | action enabler>): <rule>. Source: <policy, person, date>.

**Transition (<replacing what>)** <or: "None: greenfield, nothing is replaced, because …">
- TR-1 <data migration | parallel run | training | decommission>: <what, with a pass/fail check>.

**Quality concerns for the NFR specification:** <concern (attribute); …>

**Assumptions:** ASM-1 <belief>. Confirm by <question for the user to put to whom>.

**Waiting room:** <want found but not built now, with its reason>.
<!-- =================== END LEAN ONLY =================== -->

<!-- ============== STANDARD / ENTERPRISE ONLY ============== -->
## Backlog Summary

| ID | Story | Epic | Persona | UR / FR | Job story | Priority (provisional) |
|---|---|---|---|---|---|---|
| US-1 | <title> | EPIC-1 | P-n | UR-n (FR-n.m) | JS-n.m | <high | value 9, penalty 8> |
<!-- ============ END STANDARD / ENTERPRISE ONLY ============ -->

## Stories

### EPIC-1: <Outcome title, from the epic list or the lean heading>

<!-- LEAN epic heading only (none at standard/enterprise, where ideate/epics.md holds it):
Trace: <KR-n.m> → <actor (P-n)> → <behaviour change> → this epic. Assumption [<type>]: <belief> (<ASM-n>). Signal: <signal>.
Priority (provisional): <high | medium | low> · Size: <S | M | L> (<n> stories)
-->

#### US-1: <Outcome-named title>
As a <persona (P-n) or user role>, I want to <action the user takes>, so that <change in the user's world>.
- Traces to: EPIC-1 · <UR-n (FR-n.m) — omit at lean> · J-n → JS-n.m · KR-n.m <· TR-n for a transition story>
- Rules: <BR-n, BR-m | none> <· NFR-ID if a quality target constrains it>
- Priority (provisional): <high | medium | low — enterprise: value <1–9>, penalty <1–9>>
- Seed example: <one concrete case with real-feeling names and numbers, and its outcome>
- Acceptance criteria: ideate/acceptance-criteria/US-1.md (from the example map) <lean: these are its fit criteria>
- Notes: <optional: split pattern used · waits on US-n (spike) · ordering note · Source: story-map gap, approved <date>>

#### US-2: Spike: <the one question to answer>
- Question: <what nobody can say yet, e.g. what the external system returns>
- Output: <a decision note answering the question — not shippable software>
- Unblocks: US-n · Traces to: EPIC-1
- Priority (provisional): <same as the story it unblocks>

<!-- ============== STANDARD / ENTERPRISE ONLY ============== -->
## Coverage

| Source | Stories |
|---|---|
| EPIC-1 story title "<title>" | US-1 |
| UR-n (FR-n.m, FR-n.k) | US-1, US-3 |
| TR-n | US-n <or: procedure, not a story> |

<!-- Enterprise: also propose the forward trace (epic list Stories column, FRD Story column) for the user's approval. -->
<!-- ============ END STANDARD / ENTERPRISE ONLY ============ -->

## Intake Log (from the story map)

| Item | Kind | Decision |
|---|---|---|
| <step with no story> | Gap | <US-n written, approved <date> | declined: <reason, e.g. a named manual step>> |
| <US-n> | Orphan | <placed at <step> | removed with the user's agreement> |

<!-- ===================== LEAN ONLY ===================== -->
<!-- Added after the spine is walked (story-mapping thinking). It is the walking skeleton
     and makes the provisional priorities final. -->
## Must / Won't-this-time — Release 1 (the walking skeleton)

Spine: <first step → next step → … → last step, in the persona's words>.

### Must (the walking skeleton)
| Step | Story |
|---|---|
| <journey step> | <US-n title> <or: (manual: named step)> |

### Won't this time
| Story | Why not now | Look again |
|---|---|---|
| <US-n title> | <workaround, even manual, or reason> | <when> |

Contingency, built after the Musts if the release allows: <US-n (provisional priority), …>.

Learning checkpoint: <after when, read which signal (KR); what is built next if it has not moved>.
<!-- =================== END LEAN ONLY =================== -->
