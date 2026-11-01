# Epic Readiness Checklist

Self-contained. Run it on the epic list (standard, enterprise) or on the epic headings in the backlog (lean) before handing to `user-story-writing` and `story-mapping`. Every item must pass, or carry a written reason the user accepted. Then run `python3 ../scripts/check-epic-list.py <artifact>` for the mechanical checks.

## Every profile

- [ ] Each epic title names an outcome for a user class, not a feature, component, service or layer
- [ ] Each epic traces to a selected-path deliverable (or, with no impact map, the Key Result); no epic comes from an option branch
- [ ] Priority is provisional (high / medium / low, or value and penalty scores) and stated to be finalised by `moscow-prioritization`; no Must / Should / Could / Won't anywhere
- [ ] No epic is sized in sprints, weeks or story points

## Lean (epic headings in `ideate/user-stories.md`)

- [ ] No `ideate/epics.md` was written
- [ ] Each epic heading has a trace line: KR → actor → behaviour change, a typed assumption and a signal
- [ ] Every story sits under one epic heading, or the backlog has no epics and every story traces to the KR

## Standard and enterprise (`ideate/epics.md`)

- [ ] Frontmatter: name, version, phase (ideate), owner, created, summary, profile, and the linked KR, impact map (or "none") and JTBD analysis
- [ ] Each epic has an outcome statement ("As a result of this epic, … will be able to …")
- [ ] Each epic has a falsifiable hypothesis naming an actor, a behaviour change, a signal and a KR; it could fail while the epic succeeds
- [ ] Each epic traces to a job statement and the job story beneath it (J-n → JS-n.m) and lists the user requirements (UR-n) it carries; a transition epic lists its TR-n
- [ ] Each epic has a four-risk line: value, usability, feasibility, viability, each tested (evidence cited), assumed (with its test) or low (with a reason)
- [ ] Each epic has 3–5 epic acceptance criteria, each with one concrete example; none in Given/When/Then; no NFR targets restated
- [ ] Each epic lists 3–10 story titles, outcome-named, in the order the user meets them; no layer or per-service titles
- [ ] Size matches the count: S 3–4, M 5–7, L 8–10; +spike where a title is a spike
- [ ] Each epic names one Bounded Context candidate, or is listed in the cross-context table with the reason
- [ ] Coverage: every selected-path software deliverable has an epic; every UR is in one epic (or split by FR across epics, recorded in the coverage table); every TR is in an epic or under "Not epics"
- [ ] Non-software deliverables (procedures, messages, training) and option branches are listed under "Not epics", not turned into epics
- [ ] No product-specific rule (a compliance persona, a tenant rule) is presented as a general rule

## Enterprise only

- [ ] Epics are grouped by impact map (product outcome) and, where a roadmap exists, by roadmap Theme
- [ ] Priority carries value and penalty scores
- [ ] Transition epics exist per tenant where tenants migrate separately
- [ ] The cross-context table names each flagged epic, the contexts involved and the question for the domain-modeler
- [ ] A forward-trace column (stories) is present, to be filled by `user-story-writing`
