# User Story Backlog — Pre-Handoff Checklist

Self-contained rule set for `ideate/user-stories.md`. Run it before presenting the backlog to the user, and again after taking in gap stories from the story map. Items marked **(script)** are also checked by `../scripts/check-user-stories.py`; the rest need judgement.

## Artifact

- [ ] Frontmatter has `name: user-story-backlog`, `version`, `phase: ideate`, `owner`, `created`, a one-sentence `summary` and `profile` **(script)**
- [ ] The translation line says which epics, requirements and job stories became these stories, for which consumers
- [ ] The provisional-priority note is present and names who finalises (MoSCoW, or the lean closing block)

## Every story

- [ ] `US-n` ID, outcome-named title, one-sentence card with **As a**, **I want to**, **so that** **(script)**
- [ ] "As a" is a persona (P-n) or a user role, never "a user", never a system **(script: "a user", "the system")**
- [ ] "I want to" is a user action with no implementation word (endpoint, dropdown, table, modal, vendor)
- [ ] "so that" survives the "so what?" test: it names a change for the user, and does not repeat the want **(script: obvious repeats)**
- [ ] Passes all six INVEST letters, or the failing letter is fixed (split, spike, rewrite)
- [ ] **Traces to** cites the epic (when epics exist), the job story JS-n.m, and at standard/enterprise the UR-n **(script)**
- [ ] Rules cited by BR-n, not restated; quality numbers cited by NFR ID, not written into the card
- [ ] **Priority (provisional)** present, high / medium / low or value and penalty; no Must / Should / Could / Won't **(script)**
- [ ] One **seed example**: concrete names, numbers and outcome **(script: present)**
- [ ] No Given/When/Then on the card: that is `acceptance-criteria`'s, from the example map **(script)**
- [ ] No size field, no sprints, story points or person-weeks **(script)**

## Splitting

- [ ] Every child of a split is an end-to-end slice a user can see working; no layer or per-service stories
- [ ] Every spike names one question and a decision-note output, and the story it unblocks names it
- [ ] Ordering dependencies are recorded on the story, not hidden

## Coverage and intake

- [ ] Every epic story title has a story; every UR's FRs are carried by at least one story (standard/enterprise: Coverage table) **(script: Coverage section present)**
- [ ] Transition requirements that change what a user sees are stories (TR-n cited); procedures are not
- [ ] Every gap the story map proposed is written (approved, dated) or recorded as declined with a reason; every orphan placed or removed with the user's agreement; nothing added or removed silently
- [ ] At enterprise, the forward trace (epic list Stories column, FRD Story column) is proposed for the user's approval

## Lean only

- [ ] A **Requirements Header** holds translation, scope and exclusions, BR-n, TR-n (or "none, because…"), quality concerns, assumptions and waiting room **(script: header present)**
- [ ] Epic headings, when used, each carry one Trace line (KR → actor → behaviour change), an assumption, a signal, a provisional priority and a size by story count
- [ ] The file closes with the **Must / Won't-this-time** block: a spine line, a Must table (one story or named manual step per journey step), a Won't-this-time table with workaround and "look again", contingency and a learning checkpoint **(script: block present and last)**
- [ ] The Musts are the walking skeleton and every Won't has a workaround or reason (DSDM's workaround clause)

## Standard and enterprise only

- [ ] No Requirements Header and no Must / Won't block: the FRD and `moscow-prioritization` own those **(script)**
- [ ] A Backlog Summary table and a Coverage table are present **(script)**
- [ ] Enterprise: stories for disfavoured user classes (access, tenant isolation) exist where the FRD names them; tenant-policy and interface splits are recorded; value and penalty on every story
