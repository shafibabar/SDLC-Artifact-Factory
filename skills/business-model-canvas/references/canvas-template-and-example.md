# Canvas Template and Worked Example

The fill-in artifact template for a Business Model Canvas (and its Lean Canvas
variant), followed by a fully worked canvas for this repo's first product — the
data-estate mapping and compliance-intelligence platform for SMBs. Copy the
template, choose the variant per `SKILL.md`, and use the worked example as the
quality bar for depth and traceability.

---

## Artifact Template — Full BMC

```markdown
---
name: business-model-canvas
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
owner: product-strategist
canvas-type: bmc
---

# Business Model Canvas — [Product Name]

## 1. Customer Segments
- [Primary segment: size band + vertical + regulatory exposure + technical maturity]
- [Secondary segment(s), ranked]
- Users vs buyers: [who operates it | who pays — served how each]

## 2. Value Propositions
- [Segment] → [pain relieved] + [gain created]; traces to underserved need: [ranked need ID/name]
- [Differentiator: why a competitor cannot claim the same]

## 3. Channels
- Awareness / sales: [how prospects discover and buy]
- Delivery: [how the product is deployed]
- Support: [after-sales]

## 4. Customer Relationships
- [Segment] → [self-service | automated | dedicated | community | co-creation]

## 5. Revenue Streams
- Model: [subscription | licence | usage | transaction]
- Mechanism + tiering: [...]
- Value anchor: [what the price is measured against]

## 6. Key Resources
- Physical: [...]  Intellectual (the moat): [...]  Human: [...]  Financial: [...]

## 7. Key Activities
- Production: [...]  Problem-solving: [...]  Platform: [...]

## 8. Key Partnerships
- [Partner] | [motivation: optimisation | risk reduction | resource acquisition] | [what they provide]

## 9. Cost Structure
- Type: [cost-driven | value-driven]
- Top items (fixed | variable): [...]  including CAC and cost-to-serve

## Coherence Check
1. Value Prop ↔ Segment: [pass/revise]
2. Channel ↔ Segment: [pass/revise]
3. Key Activities → Value Prop only: [pass/revise]
4. Key Resources → Key Activities: [pass/revise]
5. Revenue ↔ Segment receiving Value Prop: [pass/revise]
6. Cost ↔ Activities + Resources: [pass/revise]
7. At least one non-replicable item: [pass/revise]
```

---

## Artifact Template — Lean Canvas Variant

For the early-stage variant, swap in the four Lean Canvas blocks (see
`canvas-blocks.md` for which BMC blocks they replace). The frontmatter
`canvas-type` becomes `lean-canvas`. Blocks:

```markdown
## 1. Problem
- Top 1–3 problems for the early adopter
- Existing alternatives: [how customers solve this today, absent the product]

## 2. Customer Segments (with Early Adopters)
- Segment(s), and the specific early adopters within them

## 3. Unique Value Proposition
- Single, clear, compelling message; traces to a ranked need

## 4. Solution
- Smallest feature set that addresses each listed problem (kept thin)

## 5. Channels
- Path to early adopters

## 6. Revenue Streams
- Model, mechanism, value anchor

## 7. Cost Structure
- Fixed + variable, including CAC

## 8. Key Metrics
- The few numbers that show the model is working

## 9. Unfair Advantage
- Something that cannot be easily copied or bought (may be honestly blank early)
```

---

## Worked Example — Full BMC (Data-Estate Mapping & Compliance Intelligence)

This is the migrated **full BMC** the product would hold at Stage 2 (soft launch),
after Stage 1 closed-beta validation. It is intentionally detailed — this is the
depth a finished canvas should reach, with every Revenue Stream traced to a Value
Proposition and at least one non-replicable item.

| Block | Entry |
|---|---|
| **1. Customer Segments** | **Primary:** SMBs of 50–500 employees carrying SOC 2 obligations, with data spread across Google Drive and AWS S3. **Users:** the Data Steward and the Compliance Officer (the Maya Chen archetype) who run scans and answer auditors. **Buyers:** the CTO / VP Engineering who owns the budget and the risk. Distinct needs — the buyer wants defensible risk reduction and a clean audit; the user wants to stop manually chasing files. Both must be served. |
| **2. Value Propositions** | *For the Compliance Officer:* "Know exactly what sensitive data you hold, where it lives, and which SOC 2 controls it puts at risk — within 30 minutes, without a single file leaving your infrastructure." Pain relieved: audit blindness and weeks of manual evidence-gathering. Gain: evidence on demand. *For the buyer:* "Turn 'we think we're compliant' into a defensible, current map." Traces to the ranked underserved need *"know at a glance whether we're at risk before an audit or a meeting."* |
| **3. Channels** | **Awareness/sales:** content + SEO on compliance topics, presence in compliance-officer communities, design-partner referrals. **Delivery:** private deployment into the customer's own Kubernetes cluster — the delivery channel is itself part of the differentiation (nothing leaves the customer's boundary). **Support:** self-service docs + a light human support tier. |
| **4. Customer Relationships** | Self-service onboarding + community for peer support + light human support for the buyer relationship. Co-creation with the 3–5 named design partners during closed beta, narrowing to standard support at soft launch. |
| **5. Revenue Streams** | Flat annual subscription per tenant, tiered by number of connected storage sources. Mechanism: subscription. **Value anchor:** compliance-officer hours of audit-prep saved per quarter, plus risk of a failed SOC 2 attestation avoided. Traces directly to the Compliance-Officer Value Proposition. |
| **6. Key Resources** | **Intellectual (the moat):** the entity-extraction pipeline, the SOC 2 control-mapping rule engine, and the relationship-graph design. **Physical:** the customer-deployed infrastructure (owned by the customer, not us — low fixed cost). **Human:** compliance-domain expertise to curate the rule engine. |
| **7. Key Activities** | **Production:** building and hardening the scanning/classification pipeline; maintaining connector coverage (Google Drive, S3, and the roadmap of PDF/DOCX/XLSX parsers). **Problem-solving:** curating SOC 2 control mappings as the framework evolves. **Platform:** keeping the private-deployment Helm/Kubernetes packaging current. |
| **8. Key Partnerships** | **Optimisation:** cloud providers as the deployment substrate; open-source model providers for extraction (frugality — zero paid third-party APIs). **Risk reduction:** compliance-community credibility partners. **No reseller motion** at this stage — that would be an aspirational partnership. |
| **9. Cost Structure** | **Value-driven.** Top items: engineering time (fixed); per-customer deployment and support (variable, the main cost-to-serve driver); CI/CD and test infrastructure (fixed); CAC via content and community (variable). Zero paid third-party API cost by design (frugality constraint). |

### Coherence Check Result

1. **Value Prop ↔ Segment** — pass. Each proposition names a segment's real pain.
2. **Channel ↔ Segment** — pass. Content/community reaches compliance officers; the
   private-deployment delivery channel matches a security-sensitive SMB buyer.
3. **Key Activities → Value Prop only** — pass. Pipeline, connectors, and rule
   curation all produce the "know your risk in 30 minutes" proposition.
4. **Key Resources → Key Activities** — pass. The extraction pipeline and rule
   engine are exactly what the production and problem-solving activities need.
5. **Revenue ↔ Segment** — pass. The subscription is paid by the buyer whose
   segment receives the risk-reduction proposition.
6. **Cost ↔ Activities + Resources** — pass. Every top cost item maps to a named
   activity or resource; CAC and cost-to-serve are present.
7. **Non-replicable item** — **pass, and this is the sharpest point:** the
   private-deployment architecture (no file ever leaves the customer's
   infrastructure) is something a competitor's multi-tenant SaaS cannot copy
   without rebuilding its data plane — check 7 passes on the delivery Channel and
   the intellectual Key Resources together.

---

## Reading the Worked Example as a Rubric

- Notice every Revenue Stream row explicitly names the Value Proposition it flows
  from — that traceability is the difference between a coherent canvas and nine
  lists.
- Notice the Value Propositions cite a **ranked underserved need**, not just a
  benefit — the `jtbd-analysis`/Opportunity-Score link the SKILL.md body requires.
- Notice Cost Structure names **CAC and cost-to-serve**, not only infrastructure —
  the most common realism failure.
- Notice check 7 is answered with a *specific* non-replicable item, not a hopeful
  "our team is great." If your check 7 cannot name something concrete, the model
  has no moat yet — that is the finding, and the honest thing to do is record it.
