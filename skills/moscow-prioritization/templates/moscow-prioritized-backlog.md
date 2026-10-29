---
name: moscow-prioritized-backlog
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <YYYY-MM-DD>
summary: <one sentence, ≤ 200 chars: the release, its Must set (the walking skeleton) and what gives way first>
profile: <standard | enterprise>
status: draft
release: <Release 1 — name from the story map's first slice>
linked-story-map: ideate/story-map.md
linked-backlog: ideate/user-stories.md
traces_to: <strategy/okrs.md (KR-n.m); ideate/story-map.md (walking skeleton); ideate/user-stories.md (US-n–US-m); ideate/requirements.md (BR-n)>
---

<!-- STANDARD and ENTERPRISE only. At lean there is no moscow.md: close
     ideate/user-stories.md with the Must / Won't-this-time block instead. -->

# MoSCoW Prioritisation — <Product>, <Release>

Priorities here are **final for this release**. They replace the provisional priorities on the stories; slices below this release are prioritised again when their release comes.

## Prioritisation Agreement

- **Constraint:** <release date set by the product owner, or "no fixed date">; quality bar <NFR-n, BR-n that must hold>; review budget <what the product owner can review and accept before the date>.
- **Who decides:** the product owner. The requirements-analyst facilitates and records. <Consulted: who gives evidence.>
- **What drops first:** the Contingency list below, in its order.
- **Escalation:** a disputed Must goes to the product owner with the Must test, the workaround found and the skeleton consequence.

## Must Have (Minimum Usable SubseT = walking skeleton)

| Story | Journey step | Why Must (DSDM signal) | Workaround |
|---|---|---|---|
| US-n <title> | <story-map activity> | <no point delivering: … / illegal: BR-n … / unsafe: … / not viable: …> | none <or: none that meets BR-n> |

## Should Have

| Story | Pain if left out (value lost, who is affected) | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-n <title> | <…> | <…> | <Basic / Performance / Delighter / Indifferent (P-n), directional> |

## Could Have

| Story | Pain if left out | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-n <title> | <…> | <…> | <…> |

## Won't Have this time

| Story | Why not now | Look again |
|---|---|---|
| US-n <title> | <workaround, or reason> | <Release n / trigger> |

## Contingency (cut order)

Dropped in this order if the release is under pressure. Coulds first, then Shoulds by least pain; a protected Delighter last; stories that only work together drop together.

1. US-n <title> (Could) — <why it goes first: Cohn's factors, Kano>
2. US-n <title> (Should) — <…>

## Skeleton Check (two-way)

- **Skeleton → Must:** <every skeleton story is a Must above; any story moved off the skeleton for a workaround, and the manual cell that replaces it>.
- **Must → skeleton:** <no Must off the skeleton; any legal, safety or regulatory Must added to the skeleton at the step it protects, marked with its rule>.
- **Re-cut for the story map:** <none, or what `story-mapping` must change so the two lists agree>.
- **Structural checks:** usable <yes / no>; droppable tier present and ordered <yes / no>; every Must workaround-free <yes / no>.

<!-- ===================== ENTERPRISE ONLY ===================== -->
## Priority Levels (project → release)

| Story | Provisional (value / penalty) | Release <n> | Note |
|---|---|---|---|
| US-n | <v / p> | <Must / Should / Could / Won't> | <e.g. high epic, story judged on its own> |

Report-only (never a gate): Musts are <n> of the <N> stories in scope (<x>%) by count<; ≈ <y>% weighted by epic size, approximate>.

## Priority Change Log

| Date | Story | From → to | Why | Decided by |
|---|---|---|---|---|
| <YYYY-MM-DD> | US-n | <provisional v / p → Must R1> | <contract term, regulation, workaround found> | the product owner |

## Scope Escalations

| Date | Check that failed | Options put to the product owner | Decision |
|---|---|---|---|
| <YYYY-MM-DD> | <Musts outgrew the skeleton / no droppable tier> | <keep Musts = skeleton · narrow the release · move the date · accept no contingency as a risk> | <decision, quoted> |
<!-- =================== END ENTERPRISE ONLY =================== -->
