# Example 3 — An enterprise multi-tenant platform: product-area swimlanes (hardest case)

Self-contained. The **enterprise** profile: a multi-tenant, multi-region platform with a high-availability commitment, per-tenant data residency and three product lines plus a shared platform team. It shows product-area swimlanes, a weakest-link Now that spans lanes, cross-area dependencies, a committed contractual date, a Later theme that opens the next bowling-alley segment (Moore), exclusions that each cite the guiding policy, a recorded pre-wiring order and the audience views.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise) in EU and US regions, per-tenant data residency, a 99.95% availability commitment. Product lines **Discover** (finds and classifies sensitive data), **Govern** (access reviews), **Prove** (audit evidence); a shared **Regional runtime** team.
>
> Company vision, North Star: *share of tenants whose estate is continuously provable*.
>
> Company strategy kernel: **Crux:** findings data owners act on without re-checking. **Guiding policy:** fix the weakest link first; make every finding explainable and evidenced, inside the tenant's region, before widening what we scan or govern. **Rules out:** new connectors before accuracy is proven on the existing ones; cross-region or central processing; auto-remediation. **Coherent actions:** (1) every finding carries its reason and evidence, in-region; (2) one-click owner confirm/reject feeding accuracy back; (3) Govern reviews only findings above a tenant-set confidence; (4) each region's runtime sized for actions 1–3 first. Prove has a line kernel (crux: evidence an auditor can accept; rules out a proprietary "trust score").
>
> OKRs, aligned (not cascaded): **C-O1** (aspirational) owners act on findings without re-checking; **C-O2** (aspirational) owner feedback improves classification in every region; **C-O3** (**committed**) 2 of 2 audit firms receive control-mapped reports by 2027-03-01. Discover: **D-O1** findings show why, in-region (aligns C-O1); **D-O2** decisions feed classification (C-O2); **D-O3** existing connectors proven before any new one (C-O1). Regional runtime: in-region explanation compute for 60 of 60 enterprise tenants (D-O1). Health: availability per region ≥ 99.95%; cross-region data copies = 0.
>
> GTM: beachhead is EU and US regulated financial-services firms; the advisory board names mid-size healthcare providers as the adjacent segment.

## Working it

- **Weakest link across lanes.** Explainable findings are what Govern and Prove are built on. The Discover theme and the Regional runtime theme that makes it possible go first; Govern waits for them.
- **Swimlanes, one roadmap.** Each lane's themes name the line or team KR (or the company Objective) they serve, so the roadmap reads the aligned OKR levels without copying them.
- **A committed date is allowed** because C-O3 is a committed OKR with a contractual pilot date. Nothing else has a date.
- **New connectors appear twice, correctly.** The policy rules them out *now* ("before accuracy is proven"), so "Not On This Roadmap" declines them for Now and Next, and a Later theme names the condition (D-O3 reached) as its dependency.
- **The bowling alley.** One Later theme exists because it completes the whole product for the next segment, healthcare providers, which shares the in-region processing and control-keyed evidence already built for financial services.

## Output — the roadmap artifact (internal view, abridged to the roadmap body)

```markdown
---
name: strategic-roadmap
product: data-accountability-platform
version: 1.0.0
phase: strategy
created: 2026-10-22
summary: Platform roadmap: explainable in-region findings first across Discover and runtime (weakest link), Prove's committed audit pilots, Govern next; auto-remediation and cross-region processing excluded.
owner: product-strategist
profile: enterprise
format: quarters-then-halves
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/prove-strategy-kernel.md; strategy/okrs.md; strategy/okrs-discover.md
---

# Strategic Roadmap — Data Accountability Platform

## Disclaimer
This roadmap is a statement of intent and direction. It reflects our current understanding and will change as we learn. Confidence describes sequence and scope, not importance. The only date is marked **committed** and is a contractual obligation already in our OKRs. This disclaimer appears on every view.

## Vision
Every organisation accountable for sensitive data can know, govern and prove what it holds, continuously — North Star: share of tenants whose estate is continuously provable.

## Objectives this roadmap serves
**Guiding policy:** fix the weakest link first; explainable, evidenced, in-region findings before widening scope.
| Level | Objective | Type |
|---|---|---|
| Company | C-O1 owners act without re-checking · C-O2 feedback improves classification · C-O3 audit pilots on the promised date | aspirational · aspirational · **committed** |
| Discover | D-O1 findings show why, in-region · D-O2 decisions feed classification · D-O3 existing connectors proven | aspirational ×3 |
| Regional runtime | In-region explanation compute for 60 of 60 enterprise tenants | aspirational |

## How this was prioritised
**Weakest link:** trust in findings (Discover A + Runtime R) — caps Govern and Prove.
**Framework:** value / effort / confidence scorecard per product area, after cross-area dependency order (scores in the appendix).

## Q1 2027 — Now
| Area | Theme (customer problem) | Serves | Candidate solutions (bets) | Stage | Conf. | Reinforces | Depends on |
|---|---|---|---|---|---|---|---|
| Discover | A. "We can't see why a file was flagged, so we re-check every finding" | D-O1 → C-O1 | We believe showing the reason and matched evidence on each finding, in-region, will cut re-checks | development | High | Policy (weakest link) | R |
| Runtime | R. "Our data may not leave the region, so we can't get explanations at all" | Runtime KR → D-O1 | We believe per-region explanation compute will reach 60 of 60 tenants | development | High | A | Platform capacity per region |
| Discover | B. "We correct a finding and the same wrong finding comes back" | D-O2 → C-O2 | We believe one-click confirm/reject feeding the next model update will move D-O2 | discovery | High | A (explanations make the feedback meaningful) | A |
| Prove | P. "Our auditors re-do your work because the evidence isn't in a form they test against" | C-O3 (**committed: 2 audit firms by 2027-03-01**) | Report sections keyed to control IDs; an in-region auditor read-only view | development | High | A (evidence source) | A |

## Q2 2027 — Next
| Area | Theme (customer problem) | Serves | Stage | Conf. | Depends on |
|---|---|---|---|---|---|
| Govern | G. "Reviewers spend review time on findings nobody trusts" | C-O1 (coherent action 3) | discovery | Medium | A, B |
| Discover | C. "Findings from three of our five connectors still can't be trusted" | D-O3 → C-O1 | discovery | Medium | B |

## H2 2027 — Later
| Area | Theme (customer problem) | Serves | Conf. | Next segment it unlocks | Depends on |
|---|---|---|---|---|---|
| Prove | H. "Our regulator's controls aren't the ones your evidence maps to" | Guiding policy: widen scope only once findings are trusted | Low | Mid-size healthcare providers (shares in-region processing and control-keyed evidence) | P, D-O3 reached |
| Discover | N. "Data on storage you don't connect to stays invisible" | Guiding policy: new connectors only after accuracy is proven | Low | — | D-O3 reached |

## Not On This Roadmap
| Declined direction or request | Excluded by |
|---|---|
| Auto-remediation / blocking (data loss prevention actions) | Guiding policy rules it out: acting automatically on findings owners don't trust deepens the crux |
| Central or cross-region processing to cut cost | Guiding policy rules it out: breaks residency and the one advantage the policy relies on |
| New connectors in Now or Next (SharePoint requested by three enterprise tenants) | Guiding policy: not before accuracy is proven on existing connectors (theme N holds the condition) |
| A proprietary "trust score" in Prove | Prove line kernel rules it out: auditors cannot test it |
| "GDPR module by June" promised to a prospect | Guiding policy: widen scope only once findings are trusted; a contract date must first become a committed OKR |

## Review pre-wiring (recorded order)
| Order | Stakeholder | Concern | How the draft answered it |
|---|---|---|---|
| 1 | Regional runtime lead (owns a shared dependency) | Capacity for R and the 99.95% in both regions | R sized before any new workload; availability stays a health metric |
| 2 | Discover, Govern, Prove leads | Govern waits a quarter | G depends on A and B; its value is capped until they land |
| 3 | Head of sales | SharePoint and GDPR requests | Declined with policy reasons; theme N and H show the conditions |
| 4 | Executive sponsor | The committed pilot date | P is in Now, High confidence, marked committed |

## Audience views
Executive (objectives, themes per area, confidence) · Sales (themes and stages; must not promise: SharePoint, GDPR, any date) · Engineering (Now detail, dependencies, link to the release plan) · External (themes in customers' words and stages; no dates). Disclaimer on each.

## Revision history
Revise at: each OKR cycle · discovery results · a kernel revision (company or line) · the story maps per line · a KR no theme can move. Near-term review monthly; whole roadmap quarterly.
| Date | Trigger | What moved | What was dropped | The learning |
|---|---|---|---|---|
| 2026-10-22 | First version | Govern from Now to Next | New connectors from Next | Weakest-link sequencing; the policy's connector condition |
```

## Where product-specific rules go

Data residency, the 99.95% commitment and the audit-firm pilot date are this product's obligations. They appear here, in this product's roadmap, never in the skill's general rules.
