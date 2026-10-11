# Example 3 — An enterprise multi-tenant platform: a vision cascade

Self-contained. The hardest common case: a company running a multi-tenant platform with several product lines, enterprise and SMB tenants, and high-availability, multi-region obligations. One vision cannot serve every team, but separate visions that don't connect fragment the strategy. Cagan's distinction (*Inspired*) does the work: one durable vision; strategy as focused bets; each product line's vision a consequence of the company's, never a rival to it.

## Input

> A B2B platform serving 4,000 tenants (60 enterprise, the rest SMB) across EU and US regions with data-residency obligations and a 99.95% availability commitment. Three product lines: **Discover** (finds and classifies data), **Govern** (policy and access reviews), **Prove** (audit evidence and reporting). Each line has drafted its own "vision"; they contradict each other on whether enterprise or SMB comes first.

## Step 1 — The company vision (the anchor)

| Component | Value |
|---|---|
| Protagonist | The people accountable for an organisation's sensitive data: compliance, security and data owners, at any size |
| Today's need | To know, govern and prove what they hold continuously, instead of reconstructing it before each audit |
| Future state | Data accountability is a live, provable state of the organisation, not a yearly project |
| Why it matters | Trust between organisations, regulators and customers rests on claims nobody can currently verify between audits |
| Durable bet | Accountability has to work where the data already lives: the customer's region, boundary and systems |

> Every organisation accountable for sensitive data can know, govern and prove what it holds continuously, wherever that data lives, so trust between organisations, their customers and regulators rests on evidence instead of annual reconstruction.

**34 words.**

## Step 2 — Product-line visions as consequences

Each line's vision names the **same protagonist family** and a future state that is one part of the company's:

| Line | Product-line vision (logline) | The part of the company future it delivers |
|---|---|---|
| Discover | Data owners always know what sensitive data exists and where, within their own region and boundary. | "know" |
| Govern | Access to sensitive data is always justified, reviewed and current, without a spreadsheet campaign. | "govern" |
| Prove | Any accountability claim can be evidenced on demand, to an auditor or a customer, from live state. | "prove" |

**The conflict resolved.** Whether enterprise or SMB comes first is a *strategy* question: a sequenced bet, decided and revisited with OKRs (`okr-authoring`). It is not a vision question. The company vision deliberately says "at any size", so neither line's vision may exclude a segment. The roadmap decides the order.

## Step 3 — What the cascade rules out

- **Region-centralised processing** to simplify operations. It breaks "wherever that data lives" and data-residency commitments.
- **A line-specific vision with its own protagonist** (e.g. Prove targeting external auditors as the hero). A line can serve auditors, but the hero stays the accountable organisation.
- **"Point-in-time" features as the flagship** (a better annual-audit export). They fight "continuously".

## Step 4 — North star cascade

| Level | North star |
|---|---|
| Company | Share of tenants whose estate is continuously provable (classified, access-reviewed within policy, evidence fresh within SLA) |
| Discover | Classified share of each tenant's connected estate |
| Govern | Share of sensitive-data access grants reviewed within policy |
| Prove | Share of evidence requests answered from live state within the SLA |

The company metric is defined so that it can only rise if all three lines' metrics rise. That is the mechanical check that the line visions are consequences of the company vision, not rivals.

## Why this is the hard case

At platform scale, the failure mode is not a weak sentence. It is **many reasonable visions that don't compose**. The cascade test settles it: each line names the same protagonist, delivers a named slice of the company's future state, and has a north star that rolls up.
