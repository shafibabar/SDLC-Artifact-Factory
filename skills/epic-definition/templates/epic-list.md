---
name: epic-list
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: which outcomes these epics deliver, from which selected-path deliverables, for which user classes>
profile: <standard | enterprise>
status: <draft | approved>
linked-kr: <KR ID(s) from strategy/okrs.md>
linked-impact-map: <ideate/impact-map.md | ideate/impact-maps/<outcome>.md, … | none (standard, map not produced)>
linked-jtbd: ideate/jtbd-analysis.md
linked-requirements: ideate/requirements.md
traces_to: strategy/okrs.md (<KR>); <linked-impact-map> (selected path); ideate/jtbd-analysis.md (<J-n, JS-n.m>); ideate/requirements.md (<UR-n, TR-n>)
---

<!-- Copy into ideate/epics.md and fill. Lean: no epic list; epic headings go in
     ideate/user-stories.md instead (see the skill's lean example). Delete these comments. -->

# Epic List — <Product>

**Translation.** <Which selected-path deliverables, job stories and user requirements become which epics, for user-story-writing, story-mapping and the domain-modeler.>

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`. Sizes are structural (S = 3–4 stories, M = 5–7, L = 8–10).

## Epic Summary

<!-- Enterprise: one summary table per impact map / product outcome, with the roadmap Theme as a heading. -->

| ID | Epic (outcome) | Deliverable | Job story | URs / TRs | Bounded Context | Priority (provisional) | Size |
|---|---|---|---|---|---|---|---|
| EPIC-1 | <outcome title> | <SOL-n> | <JS-n.m> | <UR-n> | <candidate> | <high> | <M> |

## Epics

### EPIC-1: <Outcome title — never a feature, component or service>

As a result of this epic, <user class> will be able to <outcome>.

**Hypothesis:** If we deliver <this>, we believe <actor> will <behaviour change>, shown by <signal>, which moves <KR-n.m>.

**Traces to:** deliverable <SOL-n> (selected path, <linked-impact-map>) · job <J-n> "<job statement>" → job story <JS-n.m> · <UR-n, UR-m> · <KR-n.m>
**Personas:** <P-n (primary); P-m>
**Bounded Context (candidate):** <one name>

**Risks:** value — <tested (evidence) | assumed (test) | low (reason)> · usability — <…> · feasibility — <…> · viability — <…>

**Epic acceptance criteria** (high level; Given/When/Then comes later, per story):
- [ ] <condition>. *Example: <one concrete case with real-feeling names and numbers>.*
- [ ] <condition>. *Example: <…>.*
- [ ] <condition>. *Example: <…>.*

**Story titles** (in the order the user meets them; titles only):
1. <outcome-named story title> (<UR-n>)
2. <…>
3. <…>

**Size:** <S | M | L> <+spike>
**Priority (provisional):** <high | medium | low — enterprise: value <1–9>, penalty <1–9>>

---

### EPIC-2: <…>

<!-- repeat -->

## Coverage

| Source | Epic |
|---|---|
| <SOL-n> (selected path) | <EPIC-1> |
| <UR-n> | <EPIC-1> |
| <TR-n> | <EPIC-n or "Not epics: procedure"> |

## Not Epics

<!-- Non-software deliverables on the selected path, option branches, and anything else
     deliberately not turned into an epic, with where it goes instead. -->

| Item | Why not an epic | Where it goes |
|---|---|---|
| <SOL-n procedure> | Non-software deliverable | <documented procedure / rollout checklist> |
| <option on the map> | Option branch, not selected | Stays on the impact map |

## Cross-Context Flags (for the domain-modeler)

<!-- Standard: when any. Enterprise: always present ("none" if none). -->

| Epic | Contexts involved | Why it still crosses after the outcome split | Question for the domain-modeler |
|---|---|---|---|
| <EPIC-n> | <A, B> | <…> | <missing context? Anti-Corruption Layer?> |

<!-- Enterprise adds a forward-trace column per epic, filled by user-story-writing:
| Epic | Stories (US-IDs) | -->
