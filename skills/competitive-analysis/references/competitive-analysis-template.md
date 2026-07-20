---
name: competitive-analysis
product: Data Estate Mapping and Compliance Intelligence
version: 1.0.0
phase: strategy
created: 2026-07-19
owner: product-strategist
---

# Competitive Analysis

## Competitive Landscape

| Competitor | Type | Brief description | Key strength | Key weakness |
|---|---|---|---|---|
| BigID | Direct | Enterprise data discovery and privacy platform | Breadth of connectors and compliance frameworks | Enterprise pricing and sales-led POC; out of reach for 50–500 employee SMBs |
| Varonis | Direct | Data security and access governance platform | Deep permissions analytics; strong brand with CISOs | On-prem/file-server heritage; heavy deployment; enterprise-priced |
| Securiti.ai | Direct | Data command centre for privacy and security | Broad framework automation (GDPR, CCPA, SOC 2) | SaaS-first architecture — metadata and samples leave the customer boundary |
| Generic DLP tools (e.g. endpoint DLP suites) | Indirect | Prevent data exfiltration at endpoints and gateways | Mature blocking controls | Show data *leaving*, not what you *hold* — no estate map, no relationship graph |
| CASB platforms | Indirect | Broker and monitor cloud app access | Coverage of SaaS app activity | Access-centric, not content-centric; no entity extraction from documents |
| Manual audit spreadsheet (consultant-maintained) | Substitute | A consultant interviews teams and builds a data inventory in a spreadsheet | Cheap to start; auditor-credible; fully private | Point-in-time snapshot, stale within weeks; no evidence trail; does not scale past the first audit |
| Do nothing until the audit | Substitute | Scramble when the SOC 2 window opens | Zero cost today | Surprise findings; failed audits cost customers and deals |
| AWS Macie | Future entrant / partial direct | Managed sensitive-data discovery for S3 | Native S3 integration; usage-based pricing | S3-only — blind to Google Drive and documents-in-motion; data processed in AWS-managed service, not customer-controlled boundary |
| Google Cloud DLP | Future entrant | Managed classification API | Strong PII detectors | An API, not a product — no estate map, no compliance intelligence; content leaves customer control |

## Capability Matrix

Ratings: ✓ strong · ~ partial · ✗ absent · ? unknown

| Dimension | Our product | BigID | Varonis | Securiti.ai | AWS Macie | Consultant spreadsheet |
|---|---|---|---|---|---|---|
| Private deployment — zero data leaving customer infrastructure | ✓ | ~ | ~ | ✗ | ✗ | ✓ |
| SMB fit: price and setup effort for 50–500 employees | ✓ | ✗ | ✗ | ~ | ~ | ~ |
| Google Drive coverage | ✓ | ✓ | ~ | ✓ | ✗ | ✓ |
| AWS S3 coverage | ✓ | ✓ | ~ | ✓ | ✓ | ~ |
| Entity extraction from PDF/DOCX/XLSX | ✓ | ✓ | ~ | ✓ | ~ | ~ |
| Cross-source relationship graph | ✓ | ~ | ✗ | ~ | ✗ | ✗ |
| SOC 2 control mapping (CC6, CC7, A1) | ✓ | ~ | ~ | ✓ | ✗ | ✓ |
| Time to first insight | < 30 min | Weeks | Weeks | Days–weeks | Hours | Weeks |
| Continuous monitoring (vs point-in-time) | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| Sensitivity classification (Public/Internal/Confidential/Restricted) | ✓ | ✓ | ~ | ✓ | ~ | ~ |

## Positioning Map

Axes: **deployment privacy** (x — data leaves customer boundary → fully private) × **SMB accessibility** (y — enterprise-only → self-serve SMB).

```
SMB-accessible │  AWS Macie (S3-only)        │  ★ OUR PRODUCT
               │                             │
               │                             │  Consultant spreadsheet
               │─────────────────────────────│─────────────────────────
Enterprise-    │  Securiti.ai                │  BigID (~)
only           │  Google Cloud DLP           │  Varonis (~)
               └─────────────────────────────┴─────────────────────────
                  Data leaves boundary           Fully private
```

The top-right position — fully private *and* SMB-accessible with full-estate coverage — is unoccupied. The nearest occupant, the consultant spreadsheet, cannot provide continuous monitoring or a relationship graph.

## Competitive SWOT

| | |
|---|---|
| **Strengths** | Only continuous-monitoring option that keeps all data inside the customer boundary at SMB price and setup effort; cross-source relationship graph none of the SMB-reachable alternatives offer |
| **Weaknesses** | Two connectors at launch (Google Drive, S3) vs dozens for BigID/Securiti; no brand recognition; SOC 2 only at MVP (no GDPR/ISO mapping yet) |
| **Opportunities** | SMBs facing SOC 2 demands from enterprise customers are underserved by every enterprise platform; auditor-credible automated evidence is a need no substitute meets continuously |
| **Threats** | AWS Macie extending beyond S3 or bundling into an SMB security tier; Securiti launching a self-hosted SMB edition; Google adding Drive-native classification for Workspace at zero marginal cost |

## Differentiation Points

1. **Zero data egress, architecturally guaranteed.**
   - *Dimension:* deployment privacy. *Evidence:* all scanning, extraction, and graph building run inside the customer's Kubernetes cluster; only the consultant substitute matches this, and it cannot monitor continuously.
   - *Defensibility:* SaaS competitors would need to re-architect their platforms for private deployment — a multi-year change that undermines their own operating model.
2. **First compliance gap in under 30 minutes, self-served.**
   - *Dimension:* time to first insight + SMB fit. *Evidence:* guided onboarding targets a connected storage source and a classified estate within one session; every direct competitor requires a sales-led POC measured in weeks.
   - *Defensibility:* enterprise vendors' pricing and sales motion structurally prevent them from serving a self-serve SMB funnel without cannibalising their core business.
3. **Cross-source relationship graph.**
   - *Dimension:* graph capability. *Evidence:* entities extracted from PDF/DOCX/XLSX are linked across Google Drive and S3 into one queryable graph; matrix shows ✗ or ~ for every alternative.
   - *Defensibility:* requires the graph data model and extraction pipeline to be designed in from the start; bolting a graph onto a scan-and-list architecture is a rebuild.

## Competitive Risks

| Risk | Competitor | Probability | Impact | Mitigation |
|---|---|---|---|---|
| Macie expands beyond S3 and bundles at low cost | AWS | Medium | High | Lead on Google Drive + cross-source graph, which a single-cloud vendor is structurally unlikely to match; anchor positioning on multi-source privacy |
| Self-hosted SMB edition launched | Securiti.ai | Low–Medium | High | Speed: lock in design partners and auditor-credible evidence templates before an enterprise vendor can down-market |
| Workspace-native classification | Google | Medium | Medium | Google-native tools stop at Google's boundary — S3 coverage and SOC 2 intelligence remain differentiated |
| Consultant channel resists displacement | Substitute | High | Medium | Position consultants as a channel, not a competitor: the product generates the evidence they present |
