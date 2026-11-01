# MoSCoW Checklist

Self-contained. Cross-check the MoSCoW artifact (`ideate/moscow.md`) or, at lean, the Must / Won't-this-time block closing `ideate/user-stories.md`, before handing off. Items marked **(script)** are checked by `../scripts/check-moscow.py`; the rest need judgement.

## Every profile

- [ ] Runs after the story map (or, at lean, after the spine is walked); no Must / Should / Could / Won't was set earlier on cards or epics
- [ ] Every Must passed the test "what happens if it is not delivered?" with a DSDM signal: no point delivering, illegal, unsafe, not viable
- [ ] Every Must passed the **workaround clause**: no workaround, even manual (for a legal obligation, none that still meets it) **(script)**
- [ ] Stories under a high epic were judged one by one; none is a Must only because its epic is high
- [ ] **Must = walking skeleton, both ways:** every skeleton story is a Must; every Must is on the skeleton; a legal, safety or regulatory Must was added to the skeleton and marked **(script, with `--story-map`)**
- [ ] No gap in the Musts: the primary user can walk the journey end to end with them (a step met by a named manual cell is fine)
- [ ] Every Won't this time has a reason (often the workaround) and a look-again point **(script)**
- [ ] A contingency exists **(script)**; if it does not, the product owner was asked to decide the scope
- [ ] No person-weeks, story points, capacity percentage or "Must %" gate **(script)**
- [ ] Product-specific rules (a compliance persona, a tenant rule) appear only as this product's BR-n, not as general rules

## Lean (the closing block)

- [ ] No `ideate/moscow.md` **(script)**
- [ ] The block is the last `##` section of `ideate/user-stories.md`, headed "Must / Won't-this-time — Release 1 (the walking skeleton)" **(script)**
- [ ] A spine line; a Must table with one story or named manual step per journey step **(script: at least one row)**
- [ ] A Won't-this-time table; a contingency line with provisional priorities; a learning checkpoint that reads the KR **(script)**
- [ ] No Should / Could labels: contingency stories keep their provisional priority

## Standard and enterprise (`ideate/moscow.md`)

- [ ] Frontmatter: name `moscow-prioritized-backlog`, version, phase `ideate`, owner, created, summary, profile **(script)**
- [ ] A **Prioritisation Agreement**: constraint (date if set, quality bar, review budget), who decides (the product owner), what drops first, escalation **(script: section present)**
- [ ] Must, Should, Could and Won't this time sections; no story in two bins **(script)**
- [ ] Should vs Could is argued as pain (value lost, people affected), not "nice to have"
- [ ] The **Contingency** is numbered in cut order and holds exactly the Should and Could stories **(script)**; Coulds before Shoulds; a Delighter last in its tier; stories that only work together drop together
- [ ] Cohn's factors (value, cost, risk removed, knowledge gained) were used only to order the contingency, never to make a Must
- [ ] A Kano-Basic that is not a Must had its second look, and the reason it stays is written
- [ ] A **Skeleton Check** section states both directions, any re-cut handed to `story-mapping`, and the three structural checks **(script: section present)**
- [ ] With `--backlog`: every story in the backlog is in exactly one bin **(script)**

## Enterprise adds

- [ ] **Priority Levels**: provisional value / penalty beside the release bin **(script: section present)**
- [ ] Any Must share is labelled report-only and approximate, never a gate
- [ ] **Priority Change Log** with date, from → to, why and "decided by" **(script: section present)**
- [ ] Legal and contractual Musts per tenant are marked with their rule; a tenant-isolation story becomes a Must in the release that brings a second tenant live
- [ ] Any failed structural check is recorded under **Scope Escalations** with the product owner's decision
