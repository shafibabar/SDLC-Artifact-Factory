---
name: gtm-strategy
product: Data Estate Mapping and Compliance Intelligence
version: 1.0.0
phase: strategy
created: 2026-07-19
owner: product-strategist
---

# Go-to-Market Strategy

## Ideal Customer Profile

| Attribute | Definition |
|---|---|
| Company size | 50–500 employees |
| Industry | Healthtech, fintech, B2B SaaS — verticals where enterprise customers demand SOC 2 |
| Geography | North America and EU first (SOC 2 demand + data-residency sensitivity) |
| Technical maturity | Has an IT/DevOps function able to run a Kubernetes deployment or a managed private install; no dedicated security engineering team |
| Regulatory exposure | SOC 2 Type II required or imminent; data spread across Google Drive and AWS S3 |
| Buying triggers | Enterprise customer security questionnaire; upcoming SOC 2 audit window; a failed or qualified prior audit; rapid headcount growth outpacing the data inventory |
| Disqualifiers | No cloud storage estate (fully on-prem file servers); fewer than ~20 employees (spreadsheet still works); regulated to frameworks we do not yet map (HIPAA-only, FedRAMP); unwilling to host any infrastructure |

## Positioning Statement

For SMBs of 50–500 employees preparing for or maintaining SOC 2 compliance,
who cannot afford enterprise data-governance suites and cannot accept file content leaving their infrastructure,
the product is the data estate intelligence platform
that surfaces every sensitive data asset and SOC 2 control gap within 30 minutes of connecting a storage source.
Unlike BigID or Varonis,
it deploys entirely inside the customer's own infrastructure at SMB pricing — no data egress, no sales-led proof of concept.

## Messaging Framework

**Headline:** Know your data estate. Prove your compliance. Nothing leaves your infrastructure.

**Value proposition:** Connect Google Drive and S3, and within 30 minutes see every sensitive file, every extracted entity, and every SOC 2 control gap across your estate — mapped into one relationship graph. All scanning and analysis runs inside your own infrastructure, so the tool that audits your data never becomes your next data risk.

**Proof points:**
1. First compliance gap surfaced within 30 minutes of connecting a storage source — self-served, no sales call
2. Zero data egress: scanning, entity extraction, and graph building run entirely inside the customer's Kubernetes cluster
3. SOC 2 CC6, CC7, and A1 controls mapped automatically to discovered data assets, with exportable evidence
4. Every file classified Public / Internal / Confidential / Restricted, continuously — not a point-in-time snapshot
5. Entity-level extraction from PDF, DOCX, and XLSX — not just filename and metadata matching

## Channel Strategy

**Primary channel:** Content/SEO targeting compliance-officer search intent ("SOC 2 data inventory", "where does our PII live") plus presence in compliance and DevOps communities. Rationale: the ICP's buying journey starts with research, not vendor outreach; content compounds at near-zero cost (frugality constraint).

**Supporting channels:** (1) Product-led growth — guided self-serve trial in the prospect's own infrastructure; (2) compliance consultants and vCISOs as referral partners — the product generates the evidence they present, making them a channel rather than a substitute.

**Deferred:** outbound sales, events, paid acquisition — revisit after Stage 2 proves the self-serve motion.

## Sales and Distribution Model

| Decision | Choice |
|---|---|
| Sales motion | Self-serve with guided POC; founder-assisted for design partners |
| Contract model | Annual SaaS subscription (monthly available at premium during soft launch) |
| Procurement path | Credit card up to starter tier; PO/light MSA for larger SMBs |
| Trial model | Guided POC in the prospect's own infrastructure, time-limited to 30 days |
| Expansion motion | Additional storage source connectors and compliance framework modules |

## Pricing Model

**Model:** Flat annual subscription per tenant, tiered by number of connected storage sources (Starter: 2 sources; Growth: 5; Scale: unlimited). Flat tiers because SMB buyers resist metered pricing and estate sizes vary too widely for per-GB fairness.

**Value anchor:** audit-prep time. A compliance officer spends ~40 hours per quarter maintaining a manual data inventory; at loaded cost this is $6,000–10,000/quarter of effort that the product replaces with continuous, evidence-grade output. Pricing is set well below that recovered value and well below the five-figure entry point of enterprise suites. Exact price points are set in the commercial plan.

## Launch Sequencing

| Stage | Audience | Duration | Exit criteria |
|---|---|---|---|
| Stage 1 — Closed beta | 3–5 design partners matching the ICP (SOC 2 window inside 6 months) | 8 weeks | ICP confirmed by partner fit; each partner reaches first compliance gap ≤ 30 min; onboarding completed without hands-on support in the final 2 deployments |
| Stage 2 — Soft launch | ICP outreach + limited inbound from content; no broad announcement | 12 weeks | ≥ 10 active trials; trial-to-paid ≥ 15%; pricing accepted without structural discounting; repeatable self-serve deployment evidenced |
| Stage 3 — GA | Full channel activation, public launch | Ongoing | Entered only when Stage 2 criteria hold for 4 consecutive weeks |

## GTM Success Metrics

| Metric | Target | Measured from |
|---|---|---|
| Time to first value (TTFV) | ≤ 30 minutes from source connection to first compliance gap | Product telemetry |
| Trial-to-paid conversion | ≥ 15% at Stage 2 (PLG B2B benchmark 15–25%) | Trial cohort tracking |
| CAC | ≤ 25% of first-year contract value | GTM spend / new customers |
| Net Revenue Retention | > 100% by end of year 1 (connector/module expansion) | Billing data |
| ICP hit rate | > 80% of new customers match the ICP definition | CRM qualification fields |
