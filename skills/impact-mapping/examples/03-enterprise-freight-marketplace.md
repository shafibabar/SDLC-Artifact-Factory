# Example 3 — Enterprise: two maps for a multi-tenant two-sided marketplace, a works council blocker and an off-stage regulator (hardest case)

Self-contained. **Haulwise** is a multi-tenant SaaS platform where enterprise shippers tender loads to small and mid-size carriers. It runs in two regions, holds driver location data under data-protection law (the EU GDPR for EU drivers), and serves two segments: shipper tenants (sales-led, annual contracts) and carrier accounts (self-serve). At the **enterprise** profile the impact map is **required**: one map per product outcome in scope this cycle, with one shared actor register. It continues `opportunity-solution-tree`'s enterprise example.

## Input

> **KR (strategy/okrs.md, KR-1.1):** "Net revenue retention of shipper tenants from 104% to 115% by FY-end", a business outcome.
>
> **Trees (approved, cycle 2):** `ideate/opportunity-solution-trees/carrier-acceptance-speed.md`, outcome "share of tendered loads accepted within 2 h, 51% → 75% by 2027-06-30", constraint "acceptance-then-cancel rate below 3%", target **OPP-2.1** "I can't say yes until I know which driver can take it, and that takes phone calls", SOL-1 driver-set availability, SOL-2 live telematics location, SOL-3 equipment and window shown first; assumptions A-1…A-9 (A-3, A-4 ethical); tests T-4…T-6. And `shipper-tender-share.md`, outcome "share of loads tendered through the platform, 38% → 65%", target OPP-1.2.
>
> **Snapshot note:** K-4's dispatcher said the drivers' works council "would never sign off on tracking".

## Working it

- **Two maps, not one per KR.** KR-1.1 is one business outcome; the trees turned it into two product outcomes. Each becomes one map's WHY: `ideate/impact-maps/carrier-acceptance-speed.md` and `ideate/impact-maps/shipper-tender-share.md`. Other KRs in the OKR set are not mapped this cycle.
- **Shared actor register.** Both maps name the actors the same way, with persona IDs: the carrier dispatcher (P-4) is primary in the carrier map and appears in the shipper map as the party shippers wait on, cited "as in carrier-acceptance-speed.md", not redescribed.
- **Two sides must both change.** Carrier acceptance only moves revenue retention if shippers also tender more through the platform: the impact → goal link for each map names the other (A-9 in the tree).
- **The four Who questions surface the hard actors.** Obstruct: the drivers' works council at EU carriers (can veto location sharing). Affected: drivers whose location or availability becomes visible. Off-stage: the data-protection regulator, who never uses the product but whose view constrains SOL-2.
- **A prevent impact.** Dispatchers who accept fast and cancel later would hit the constraint (acceptance-then-cancel below 3%); "stops accepting before checking the driver" is on the map.
- **The selected path avoids the veto.** SOL-2 (live location) carries the ethical assumptions and the blocker; SOL-1 and SOL-3 do not. The path takes SOL-1 + SOL-3, keeps SOL-2 as an option pending the works council and T-5.

## Output 1 — `ideate/impact-maps/carrier-acceptance-speed.md` (abridged to the decision path)

````markdown
---
name: impact-map
product: haulwise
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-06
summary: Carrier map for loads accepted within 2 h (51% → 75%); path is dispatchers accepting without phoning drivers via driver-set availability and fit-first tenders; telematics held for the works council.
profile: enterprise
goal: share of tendered loads accepted within 2 h, 51% → 75% by 2027-06-30
linked-kr: KR-1.1
linked-tree: ideate/opportunity-solution-trees/carrier-acceptance-speed.md
target-opportunity: OPP-2.1
selected-path: dispatcher → accepts within the hour without phoning → SOL-1 + SOL-3; driver → keeps availability current
traces_to: strategy/okrs.md (KR-1.1); ideate/opportunity-solution-trees/carrier-acceptance-speed.md (OPP-2.1, SOL-1…3, A-1…A-9, T-4…T-6); ideate/impact-maps/shipper-tender-share.md; ideate/personas.md (P-4, P-5)
---

# Impact Map — Haulwise: carriers accept tendered loads fast

## Goal (WHY)

| Field | Value |
|---|---|
| Metric | Share of tendered loads accepted within 2 h of tender |
| Meter | Tender and acceptance timestamps, all carrier accounts, both regions, rolling 4 weeks |
| Baseline | 51% (October 2026) |
| Target | 75% |
| Deadline | 2027-06-30 |
| Constraint | Acceptance-then-cancel rate stays below 3% |
| Linked KR | KR-1.1: "Net revenue retention of shipper tenants from 104% to 115% by FY-end" |
| Source | Desired outcome of the carrier tree; a product outcome believed to drive KR-1.1 (tree A-9) |

## Actors (WHO)

| Actor | Type | Why on the map | Source |
|---|---|---|---|
| Carrier dispatcher | Primary | Accepting is the metric | P-4 (shared register) |
| Driver | Secondary; affected | Availability or location makes fast acceptance possible; their data becomes visible | P-5 (shared register) |
| Drivers' works council (EU carriers) | Blocker | Can veto location sharing and availability tracking | Snapshot 2026-10-21-k-4 |
| Shipper logistics manager | Off-stage | Tender quality (equipment, window) decides whether a load fits; as in shipper-tender-share.md | P-2 (shared register) |
| Data-protection regulator | Off-stage | Never uses the product; its guidance constrains location processing | Who-is-affected question |

## Map

### Actor: Carrier dispatcher — Primary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Accepts a fitting tender within the hour without phoning drivers first, instead of after a round of calls | OPP-2.1 "I can't say yes until I know which driver can take it" | SOL-1 Drivers set "available from / where"; shown beside each tender (software) | selected | [desirability] drivers keep it current without being chased (A-1) | Median time from tender to acceptance |
| | | SOL-3 Equipment and window shown first (software) | selected | [feasibility] shippers fill both on 90%+ of tenders (A-6) | Calls logged per acceptance (pilot carriers) |
| | | SOL-2 Live telematics location matched to pickup (software) | option | [ethical] location seen by dispatchers only, on duty only (A-3) | Same |
| Stops accepting before checking the driver, instead of accepting and cancelling later | — not on tree (dispatcher habit under time pressure) | Acceptance screen asks "driver confirmed?" (software) | option | [usability] one extra tap does not slow acceptance | Acceptance-then-cancel rate |

### Actor: Driver — Secondary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Updates availability at the end of each job instead of only when phoned | OPP-2.1 (the dispatcher's need is met by the driver's behaviour) | SOL-1 driver-app prompt at job close (software) | selected | [ethical] availability entries are never used to rank or penalise drivers (A-4) | Share of drivers with an entry under 24 h old |
| | | Dispatcher asks drivers to text availability at shift end (non-software, the T-4 concierge) | option | [desirability] drivers text without reminders | Same |

### Actor: Drivers' works council — Blocker

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Agrees the availability feature's terms instead of vetoing tracking | — not on tree (carrier-internal governance) | Written data-use terms: availability only, no location, no ranking, deletion after 30 days (non-software) | selected | [viability] councils accept availability without location | Councils signed off, of EU pilot carriers |
| | | Telematics with duty-hours-only visibility, offered for later (software) | option | [ethical] duty-hours limits are enforceable and auditable | Same |

### Actor: Shipper logistics manager — Off-stage

One-line placeholder, as in shipper-tender-share.md: "fills equipment and window on every tender" serves SOL-3 here and is detailed in that map.

### Actor: Data-protection regulator — Off-stage

One-line placeholder: no deliverable this cycle; SOL-2 stays an option until a data-protection impact assessment exists.

## Selected Path

**Dispatcher → accepts within the hour without phoning → OPP-2.1 → SOL-1 + SOL-3; driver updates availability at job close; works council agrees written data-use terms.** OPP-2.1 is the tree's target; SOL-2 is held because it carries the blocker's veto and two ethical assumptions. Confirmed by the user on 2026-11-06.

| ID | Link | Assumption | Type | Evidence today | Test |
|---|---|---|---|---|---|
| PA-1 | SOL-1 → dispatcher accepts without phoning | Drivers keep availability current without being chased | desirability | T-2 not supported (stated intent, 11%) | T-4 (tree), by behaviour |
| PA-2 | SOL-1 → driver updates | Availability is never used to rank or penalise drivers | ethical | none | New: data-use terms reviewed with 2 EU works councils; criterion set 2026-11-06: 2 of 2 agree without a location clause |
| PA-3 | SOL-3 → dispatcher accepts without phoning | Shippers fill equipment and window on 90%+ of tenders | feasibility | shipper tender data | Shipper map |
| PA-4 | Written terms → council agrees | Councils accept availability without location | viability | 2026-10-21-k-4 objects to tracking only | Same as PA-2 |
| PA-5 | Fast acceptance → 2 h share | Accepting without calls moves acceptance inside 2 h | viability | none | Pilot carriers' 2 h share after 6 weeks |
| PA-6 | 2 h share → KR-1.1 | Faster acceptance raises shippers' tender share and spend | viability | shipper tree OPP-1.2 | Shipper map's signal |

## Re-plan Trigger

- **Deliverable guess wrong:** if fewer than 60% of pilot drivers have an entry under 24 h old after four weeks, try the texted-availability option; if councils refuse the written terms, SOL-1 pauses in the EU and SOL-3 continues alone.
- **Impact → goal link wrong:** if dispatchers accept faster but the 2 h share stays below 60% after six weeks, return to the tree (OPP-1.1 "tenders arrive in five places").
- **Two-sided link wrong:** if the 2 h share reaches target but shippers' tender share does not move by 2027-03-31, review A-9 with the shipper map.

## Not Mapped This Cycle

- `ideate/impact-maps/shipper-tender-share.md`: the other map for KR-1.1 (shipper side).
- KR-2.x (carrier self-serve onboarding): no tree yet.

## Hand-off

- `requirements-analysis`: functional requirements trace to SOL-1 and SOL-3; the data-use terms become constraints for `nfr-specification`.
- `epic-definition`: candidate epics "Driver availability" and "Fit-first tender view".
- `story-mapping`: those epics form the backbone; SOL-2 and option rows stay off it.
- `moscow-prioritization`: finalises priority on the resulting stories.
- Next discovery cycle: the prevent impact (not on tree), works-council outcome, SOL-2 after a data-protection impact assessment.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-11-06 | First map | Ideate, cycle 2 |
````

## Output 2 — the shipper map, in one line

`ideate/impact-maps/shipper-tender-share.md`: goal "share of loads tendered through the platform, 38% → 65%"; primary actor the shipper logistics manager (P-2), blocker procurement's preferred-carrier list, the carrier dispatcher cited from the carrier map; selected path through the shipper tree's target OPP-1.2 "the platform's carriers are strangers"; its impact → goal link names KR-1.1 and the carrier map's 2 h share.

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| One map per product outcome, two for one KR | The KR is a business outcome; each tree's product outcome is a goal the team can steer by |
| Shared actor register | The dispatcher and the logistics manager appear in both maps, described once |
| Works council as blocker, regulator off-stage | The four Who questions found who can obstruct and who is affected; data-protection law is this product's, not a rule of the skill |
| SOL-2 held as an option | It carries the veto and two ethical assumptions; the cheaper path avoids both |
| A prevent impact | Fast acceptance that cancels later breaks the constraint |
| Two-sided re-plan trigger | The goal moves only if both sides change |
