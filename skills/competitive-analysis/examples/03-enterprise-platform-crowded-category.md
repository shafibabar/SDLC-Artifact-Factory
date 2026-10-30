# Example 3 — An enterprise multi-tenant platform entering a crowded category (hardest case)

Self-contained. The hardest common case, at the **enterprise** profile: a multi-tenant, multi-region platform (EU and US regions, per-tenant data-residency commitments, a 99.95% availability commitment) entering a category full of well-funded vendors. It shows four things the smaller examples do not need: the **category lens** changing the criteria and the axes, criteria **per buying-committee role**, a **whole-product** decomposition, a hyperscaler as **future entrant**, and a **win/loss log** after the closed beta that fed the strategy kernel. Product-specific obligations (residency, auditor acceptance) appear here because they are this product's facts, not general rules.

## Input

> A B2B platform for organisations accountable for sensitive data: 4,000 tenants (60 enterprise, the rest SMB). Three product lines: **Discover** (finds and classifies sensitive data), **Govern** (policy and access reviews), **Prove** (audit evidence and reporting).
>
> Vision (approved): "Every organisation accountable for sensitive data can know, govern and prove what it holds continuously, wherever that data lives."
>
> Stakeholder map (approved), summarised: tenant compliance officers buy; data owners use it daily; the CISO's team must approve any data handling; external auditors must accept the output; procurement checks the availability commitment.
>
> Evidence the user supplied: a closed beta with 6 enterprise tenants (ended 2026-09-30) with exit interviews; two lost-deal call notes; one analyst comparison the user licensed (dated 2026-06).

## Working it

**Alternatives first.** Before any vendor: doing nothing until the audit window (most SMB tenants before they joined), no decision (the enterprise buying group stalls: five roles, and the CISO's team defends the status quo), consultancies doing an annual audit by sampling, in-house scripts. Then the enterprise data-discovery suites, the hyperscalers' DLP services, and a future entrant: a hyperscaler bundling in-region classification into a security tier the buyer already pays for.

**The category lens.** Filed under the existing category "data discovery and classification", the buyer brings the category's criteria: connector breadth and framework coverage, where the suites lead by years. Under the subcategory "in-region data accountability for multi-region regulated organisations", the same buyer re-weights toward residency, explainable findings and auditor acceptance. The analysis records both; `gtm-strategy` chooses.

**Criteria per role.** The five roles weigh different things, so criteria carry a role, and the axes come from the roles that decide: the compliance officer and the CISO's team.

**Whole product.** "Fit for a regulated enterprise" was one cell in the draft. Decomposed (Moore), the platform leads on the generic product and trails on proof: the suites bring auditor references and certifications the platform is still earning.

## Output — the competitive analysis artifact (abridged)

```markdown
---
name: competitive-analysis
product: data-accountability-platform
version: 3.0.0
phase: strategy
created: 2026-10-22
summary: Buyers mostly defer or hire annual auditors; in-region processing with explainable findings is the defensible edge, while suites lead on breadth and proof.
owner: product-strategist
profile: enterprise
traces_to: strategy/vision-statement.md; strategy/stakeholder-map.md
---

# Competitive Analysis

## 1. Competitive Alternatives

| # | Alternative | Type | What the customer does today | Evidence |
|---|---|---|---|---|
| A1 | Wait for the audit window | Doing nothing | Reconstruct the data inventory when the auditor asks | Beta exit interviews (4 of 6) |
| A2 | No decision | Status quo | Buying group stalls; CISO's team blocks any new data processor | Lost-deal notes (1 of 2) |
| A3 | Consultancy annual audit | Substitute | Sampling-based inventory once a year | Beta exit interviews |
| A4 | In-house scripts | Substitute | Engineers scan buckets with home-grown rules | Beta exit interviews |
| A5 | Enterprise data-discovery suites (BigID, Varonis, Securiti.ai) | Direct | Broad connectors and framework mappings | Analyst comparison 2026-06; model knowledge |
| A6 | Hyperscaler DLP services (e.g. AWS Macie, Google Cloud DLP) | Indirect | Classification inside one cloud | model knowledge |
| A7 | Hyperscaler bundled in-region classification | Future entrant | Not available today; would arrive free in a tier the buyer already pays for | Lost-deal notes (1 of 2): prospect said it was "expecting it next year" |

## 2. Buyer's Evaluation Criteria

| # | Criterion | Whose | Weight | Where it came from | Table stakes? |
|---|---|---|---|---|---|
| C1 | Data never leaves our region and boundary | CISO's team | high | Lost-deal notes; beta | no |
| C2 | Findings our data owners act on without re-checking | Compliance officer | high | Beta exit interviews (5 of 6) | no |
| C3 | Evidence our auditor accepts | Compliance officer | high | Beta; auditors on the stakeholder map | no |
| C4 | Connector breadth | Compliance officer | medium | Category (data discovery) | no |
| C5 | 99.95% availability with a contractual commitment | Procurement | medium | Procurement checklist | yes |
| C6 | SSO and audit logging | CISO's team | high | Every beta tenant | yes |

### Category lens

| Candidate category | Criteria it brings | Compared with | Where we stand |
|---|---|---|---|
| Data discovery and classification (existing) | C4 heavy; framework coverage | A5 suites | Behind on breadth and proof |
| In-region data accountability for multi-region regulated organisations (subcategory) | C1, C2, C3 heavy | A3, A5, A7 | Leads on C1 and C2; C3 still being proven |

## 3. Evidence Register (excerpt)

| ID | Claim | Source | Date | Status |
|---|---|---|---|---|
| E1 | The suites offer 100+ connectors vs our 2 | Analyst comparison | 2026-06 | verified |
| E2 | Suite processing sends metadata or samples to the vendor's cloud for at least one suite | Analyst comparison | 2026-06 | verified |
| E3 | Other suites offer self-hosted deployment | model knowledge | unknown | unverified (model knowledge) |
| E4 | Hyperscaler DLP processes data inside the provider's managed service, one cloud only | model knowledge | unknown | unverified (model knowledge) |
| E5 | A hyperscaler is preparing bundled in-region classification | Prospect's remark, lost-deal notes | 2026-09-11 | user-reported |
| E6 | Beta data owners stopped re-checking findings that carried explanations | Beta telemetry | 2026-09-30 | verified |

**Evidence requested from the user:** current deployment options for each suite (E3); the hyperscalers' current regional processing terms (E4); any second source on the bundling rumour (E5).

## 4. Capability Matrix (excerpt, whole product decomposed)

| Criterion (weight) | Platform | A1 Wait | A3 Consultancy | A5 Suites | A6 Hyperscaler DLP |
|---|---|---|---|---|---|
| C1 In-region (high) | ✓ | ✓ | ✓ | ~ [E2, E3] | ~ [E4] |
| C2 Findings acted on (high) | ✓ [E6] | ✗ | ~ sampled | ? | ? |
| C3 Auditor accepts — proof ring (high) | ~ (2 audit firms piloting) | ✗ | ✓ references | ✓ references | ✗ |
| C4 Connectors (medium) | ✗ 2 [E1] | — | ~ manual | ✓ [E1] | ~ one cloud |
| Whole product — augmented ring: SIEM integrations | ~ | — | ✗ | ✓ | ✓ |

## 5. Positioning Map

**Axes:** C1 in-region (x) × C2 findings acted on (y), the heaviest criteria of the two deciding roles.
**Who shares our space:** the consultancy and "wait" share C1 but fail C2 continuously; a hyperscaler bundle (A7) would arrive in our corner on C1 if E5 is true.

## 6. Competitive SWOT (excerpt)

**Threats:** A7 bundling at zero marginal cost; a suite shipping a fully in-region edition (E3, unverified).

## 7. Differentiation Points

| # | Point | Real | Valued | Defensible | Evidence status |
|---|---|---|---|---|---|
| D1 | All processing inside the tenant's region and boundary | E2 verified; E3, E4 unverified | C1 | Suites built around central processing would need to re-architect; a hyperscaler can match C1 in its own cloud only | verified vs one suite; hypothesis vs others |
| D2 | Every finding carries its reason and evidence | E6 verified for us; ? for suites | C2 | Needs the extraction and explanation model built in; months, not weeks, to copy | hypothesis until a suite trial is compared |

**Considered and cut:** connector breadth (we lose it), "AI-powered classification" (every alternative claims it).

## 8. Competitive Risks (excerpt)

| Risk | From | Probability | Impact | Mitigation |
|---|---|---|---|---|
| Bundled in-region classification | A7 | Medium (E5 user-reported) | High | Lead on C2 and C3, which a bundle that only classifies does not address |
| Buying groups stall on the CISO's review | A2 | High | High | A pre-approved security pack for the CISO's team (to `gtm-strategy`) |

## 9. Win/Loss Log

| Date | Account / trial | Weighed against | Outcome | Stated reason (source) | Differentiation point |
|---|---|---|---|---|---|
| 2026-09-30 | Beta tenant 1 (EU bank) | A3 Consultancy | won | "Continuous, and nothing leaves Frankfurt" (exit interview) | D1 confirmed |
| 2026-09-30 | Beta tenant 4 (US insurer) | A5 Suites | won | "Owners trusted the findings" (exit interview) | D2 confirmed |
| 2026-09-11 | Prospect (EU retailer) | A7 Bundling | lost | "We'll wait for our cloud provider's version" (call notes) | D1 contradicted for single-cloud buyers |
| 2026-09-30 | Beta tenant 6 (US health system) | A2 No decision | no decision | CISO's team did not finish its review (email) | none touched |

The 2026-09-11 loss fired `gtm-strategy`'s Positioning Refresh Trigger: single-cloud buyers value D1 less. Two no-decision outcomes involving the CISO's team went to the kernel's review trigger.

## 10. Hand-off to the Strategy Kernel

- **Advantage candidates:** D1 (verified against one suite), D2 (verified for us; comparison pending).
- **The alternative to beat:** A1 waiting for the audit and A2 no decision, not the suites.
- **The advantage is not real if:** owners still re-check findings that carry full explanations, or multi-cloud buyers also choose a bundle — watched in the win/loss log and confirm/reject telemetry.
- **Table stakes for requirements:** C5, C6.
```

## What the enterprise shape added

- The category lens is why C4, where the platform loses badly, is medium and not high: under the subcategory the buyer re-weights. That choice is `gtm-strategy`'s to make; this analysis only shows the evidence for it.
- The kernel's company crux (findings data owners act on without re-checking) traces to C2, E6 and the beta rows of the win/loss log. Its "relies on: in-region processing" traces to D1, with its evidence status stated.
- The lost deal to a bundle that does not yet exist is real evidence, recorded as such, and it narrowed where D1 counts.
