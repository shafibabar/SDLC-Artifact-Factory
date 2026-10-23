# GTM Strategy — Artifact Template

Self-contained. Copy everything below the line into `artifacts/<product>/strategy/gtm-strategy.md` and replace every `[bracketed]` value. This is the **standard** shape. Sections marked *(enterprise)* are deleted below enterprise. At lean the artifact is skipped; if the user asks for one anyway, use the rollout shape in the skill's lean example instead of this template.

---

```markdown
---
name: gtm-strategy
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the beachhead, the alternative it beats and how it is reached, e.g. "Win 5–50-staff firms at year-end, unlike spreadsheets, with a same-day import trial at $70–110 per firm per month."]
owner: product-strategist
profile: [standard | enterprise]
traces_to: [strategy/strategy-kernel.md; strategy/competitive-analysis.md; strategy/business-model-canvas.md; strategy/stakeholder-map.md]
---

# Go-to-Market Strategy

## 1. Beachhead Segment

Carries out the kernel's guiding policy: "[quote the focus from the guiding policy]".

| Criterion | [Segment A] | [Segment B] |
|---|---|---|
| Compelling reason to buy now | [✓ / ~ / ✗ — evidence] | |
| One coherent channel | | |
| Accessible economic buyer | | |
| No entrenched competitor | | |
| Winnable now | | |
| Reference base for expansion | | |
| WTP evidence | [range, stated / committed, n] | |
| Kernel fit | [inside / ruled out] | |

**Chosen:** [segment] — [why, in one or two sentences].
**Next pin (bowling alley):** [adjacent segment and what transfers] *(enterprise; standard may write "not yet")*

## 2. Ideal Customer Profile

| Attribute | Definition |
|---|---|
| Size | [revenue or headcount band] |
| Industry / type | [where the pain is acute] |
| Geography | [if it changes buying or compliance] |
| Technical maturity | [what they must be able to do to adopt] |
| Buying triggers | [events that make them ready now] |
| Observed in | [the design partner or customer this is anchored in, or "hypothesis"] |
| Disqualifiers | [at least two] |

### Buying group

**Committee:** `strategy/stakeholder-map.md` §2, segment [beachhead] — [roles, one line]. (The per-role table lives there; do not copy it.)
**Mobilizer hypothesis:** [role] — confirmed in Stage 1 by [how].
**Blocker:** [role] — handled by [the Mobilizer, with which proof].
**Where consensus is built:** [in the trial / product-assisted call / collective-learning session].

## 3. Positioning

**Competitive alternatives** (from `strategy/competitive-analysis.md` §1, not re-derived): [A1 doing nothing, A2 no decision, A3 …].
**Unique attributes used:** [D1 — evidence status from the competitive analysis], [D2 — …].
**Value themes:** [2–4].
**Market category:** [fit / subcategory / create] — "[category]". Rejected: [option — why].

> For [ICP], who [pain or trigger], [product] is the [category] that [measurable value]. Unlike [the alternative the beachhead actually uses], [product] [differentiator].

## 4. Messaging

**Reframe:** [the insight about the customer's own situation that leads to a unique strength].
**Headline:** [5–10 words].
**Value proposition:** [2–3 sentences; the customer is the protagonist].
**Proof points:**
1. [factual, verifiable — how verified]
2. [...]
3. [customer story — only with a named, consenting customer; otherwise "after Stage 1"]

**Lead proof point by role:** [role → proof point].
**Objections:** ["why not just …?" → answer], keyed to the alternatives.

## 5. Channel Strategy

**Primary:** [channel] — reaches the whole beachhead because [...].
**Supporting:** [at most two].
**Deferred:** [channels — revisit when].

## 6. Sales and Distribution Model

| Decision | Choice |
|---|---|
| Sales motion | [self-serve / product-assisted / sales-led] |
| Contract model | [...] |
| Procurement path | [...] |
| Trial model | [...] |
| Expansion motion | [follows the charging unit: ...] |
| Buying group | [Mobilizer target; where consensus is built] |

## 7. Pricing

**WTP evidence:** [who, how many, stated / committed, range per segment].
**Monetisation model:** [subscription / usage / freemium / ...] — [why].
**Charging unit:** [per what] — tracks value: [...]; predictable: [...]; grows with success: [...]. Rejected: [unit — why].
**Packaging:** [single offer | tiers, with each tier's leaders].
**Value anchor (ceiling):** [quantified value; label assumptions].
**Price strategy:** [maximisation / penetration / skimming] — [justification].
**Price range per tier:** [tier: range]. List prices refined in Stage 2.
**Failure-mode check:** feature shock [ ], minivation [ ], hidden gem [ ], undead [ ].

### Packaging detail *(enterprise)*

| Feature | [Segment 1] | [Segment 2] |
|---|---|---|
| [feature] | [Leader / Filler / Killer — evidence] | |

**Fences:** [what stops buying down].
**Discount policy:** [who may discount, how much, what the customer gives in return].

## 8. Launch Sequencing

| Stage | Audience | Planned length | Exit criteria |
|---|---|---|---|
| 1 — Closed beta | [3–5 ICP design partners] | [weeks] | ICP and core value confirmed on Mom-Test evidence (past behaviour, commitments); onboarding without hands-on help; WTP range recorded per segment; Mobilizer hypothesis confirmed or replaced |
| 2 — Soft launch | [...] | [weeks] | [repeatable motion]; price accepted within [range] without structural discounting; no-decision losses counted with reasons |
| 3 — GA | [...] | Ongoing | Entered when Stage 2 criteria hold for [window]; chasm diagnostic run before a new segment |

**Positioning refresh:** at each stage transition, and when the competitive analysis's win/loss log contradicts [D1 / D2].

## 9. GTM Success Metrics

| Metric | Target | Measured from |
|---|---|---|
| Time to first value | [target, or "set after Stage 1 from partner data"] | [...] |
| Trial-to-paid conversion | [our target, set from our own funnel; no borrowed benchmark] | [...] |
| Acquisition cost | [target relative to first-year contract value] | [...] |
| Net revenue retention | [target] | [...] |
| ICP hit rate | [share of new customers matching the ICP] | [...] |
| Lost to no decision | [target or "baseline in Stage 2"] | [win/loss log] |
```
