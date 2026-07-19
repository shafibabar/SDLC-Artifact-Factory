---
name: strategic-roadmap
product: Data Estate Mapping and Compliance Intelligence
version: 1.0.0
phase: strategy
created: 2026-07-19
owner: product-strategist
format: now-next-later
---

# Strategic Roadmap

> This roadmap reflects current understanding and will be updated as we learn.
> Confidence levels indicate certainty of sequence and scope, not importance.

## Now (Current quarter)

| Outcome | OKR Link | Confidence | Dependencies |
|---|---|---|---|
| A trial user connects Google Drive and discovers their first compliance gap within 30 minutes, self-served | KR1.1, KR1.2 | High | OAuth app verification with Google; guided onboarding flow |
| Every discovered file is classified Public / Internal / Confidential / Restricted, with the classification visible and explainable in the UI | KR1.2 | High | Classification rule set validated with design partners |
| AWS S3 buckets can be connected with read-only credentials and scanned into the same estate view as Google Drive | KR1.1 | High | Google Drive connector proves the connector abstraction first |

## Next (Following 2–3 quarters)

| Outcome | OKR Link | Confidence | Dependencies |
|---|---|---|---|
| SOC 2 CC6, CC7, and A1 controls are automatically mapped to discovered data assets, with exportable auditor-ready evidence | KR (Q4): 5 paying customers with SOC 2 audit support delivered | Medium | Classification outcomes from "Now"; control-mapping rules reviewed by a practising auditor |
| Entities extracted from PDF, DOCX, and XLSX are linked across sources into a queryable relationship graph ("show every document containing this customer's data") | Strategic — core differentiator | Medium | Extraction pipeline accuracy ≥ agreed threshold on design-partner corpora |
| A compliance officer schedules recurring scans and is alerted when a new Restricted asset appears in an unexpected location | KR (Q4): weekly active compliance-officer usage | Medium | Event pipeline; notification design |

## Later (Directional — timing uncertain)

| Theme | Strategic rationale | Confidence |
|---|---|---|
| Multi-framework intelligence (GDPR Article 30, ISO 27001) | Expands TAM beyond SOC 2-driven SMBs; reuses the same estate graph | Low |
| Additional storage connectors (SharePoint, Dropbox, Box) | Connector breadth follows evidence of ICP demand, not competitor checklists | Low |
| Compliance posture over time (trend reporting for board/auditor packs) | Turns point-in-time evidence into a retention driver | Low |

## Explicitly Not On This Roadmap

- **Data Loss Prevention (blocking/quarantine actions)** — we surface and map risk; enforcement is a different product with different failure modes and buyer expectations.
- **HIPAA / FedRAMP framework mapping** — outside the ICP's regulatory profile; revisit only with paying-customer evidence.
- **A multi-tenant SaaS hosting option** — zero-data-egress private deployment is the differentiator; hosting customer data would negate the positioning.
- **Endpoint or email scanning** — the estate boundary for this product is cloud document storage; scope creep here would dilute the core graph.
