# Skill: design/information-architecture

## Purpose
Produce the Information Architecture (IA) document — the structural design of the product's user interface: navigation model, content hierarchy, and how information is organised and labelled. IA ensures the product's language and structure match the user's mental model.

## Inputs
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/ideate/story-map.md`
- `artifacts/design/domain/read-models/` (all — what data is available to display)
- `artifacts/design/ux/flows/` (existing UX flows)

## Output
**File:** `artifacts/design/ux/information-architecture.md`
**Registers in manifest:** yes

## IA Rules (enforced)
- Navigation labels use the ubiquitous language of the domain — not technical jargon.
- Each persona's primary job must be reachable within 2 clicks from the home screen.
- The IA must match the domain model — content categories map to read models, not database tables.
- Empty states are designed for every section (first-time user with no data is a real user flow).

## Artifact Template

```markdown
# Information Architecture

**Product:** {product_name}
**Phase:** Design
**Artifact:** Information Architecture
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Navigation Model

```
{product_name} (Top-level)
├── Home (Dashboard)
│   └── Posture Summary — compliance score per framework, open findings count, last scan time
│
├── Data Estate
│   ├── Storage Locations — list of registered locations + scan status
│   │   └── [Location Detail] — location info, scan history, files discovered count
│   ├── Files — searchable file inventory across all locations
│   │   └── [File Detail] — file metadata, entity types found, linked findings
│   └── Entity Map — graph view of data subjects across the estate
│       └── [Entity Detail] — entity type, golden record, locations found, linked findings
│
├── Compliance
│   ├── Findings — list of open/resolved/excepted findings by framework
│   │   └── [Finding Detail] — rule violated, entity reference, evidence, actions
│   ├── Frameworks — configured compliance frameworks and their rule sets
│   │   └── [Framework Detail] — rules, coverage status, recent evaluations
│   └── Exceptions — findings with approved exceptions
│       └── [Exception Detail] — justification, approver, expiry
│
├── Reports
│   ├── Posture History — compliance score trend over time (per framework)
│   ├── Scan Activity — scan history, throughput, coverage
│   └── Evidence Export — generate compliance evidence package for auditors
│
├── Audit Trail
│   └── Audit Log — immutable chronological log (read-only for all roles)
│
└── Settings (tenant_admin only)
    ├── Users — manage users, roles, API service accounts
    ├── Alert Channels — configure Slack, email, PagerDuty
    ├── Compliance Frameworks — enable/disable frameworks, configure rules
    └── Integrations — Worker Node deployment guide, API keys
```

---

## Role-Based Navigation Visibility

| Section | tenant_admin | compliance_officer | viewer | auditor |
|---------|-------------|-------------------|--------|---------|
| Home | ✓ | ✓ | ✓ | ✓ |
| Data Estate | ✓ | ✓ (read) | ✓ (read) | — |
| Compliance → Findings | ✓ | ✓ (full) | ✓ (read) | ✓ (read) |
| Compliance → Frameworks | ✓ | ✓ (read) | ✓ (read) | — |
| Compliance → Exceptions | ✓ | ✓ (full) | ✓ (read) | ✓ (read) |
| Reports | ✓ | ✓ | ✓ | ✓ |
| Audit Trail | ✓ | ✓ | — | ✓ |
| Settings | ✓ | — | — | — |

---

## Home Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Compliance Posture                          Last updated: 2h ago│
│                                                                   │
│  GDPR   [████████░░] 82%    SOC2  [██████████] 95%             │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Open Findings│  │ Scanning Now │  │ Files Indexed│           │
│  │      14      │  │      2 of 6  │  │   142,318    │           │
│  │ 3 CRITICAL   │  │ locations    │  │  +1,204 today│           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                   │
│  Recent Critical Findings                           View all →   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ GDPR Art.5 · SSN found in Sales Drive · 3 instances        │ │
│  │ GDPR Art.5 · Credit card in HR folder · 1 instance         │ │
│  │ HIPAA · PHI in unencrypted SharePoint · 7 instances        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Label Glossary (UI vs Domain Term)

| UI label | Domain term | Reason for difference |
|----------|-------------|----------------------|
| "Storage Location" | `StorageLocation` | Same — domain term is accessible to non-technical users |
| "Data Estate" | (section name) | Describes the collection of all storage locations — recognisable to compliance audience |
| "Entity Map" | `GoldenRecord` graph | "Entity Map" is more intuitive to compliance officers than "Golden Record" |
| "Compliance Score" | `posture_score` | "Score" is more intuitive than "posture" in a UI context |
| "Scan" / "Scanning" | `ScanInitiated`, `Scanning` state | Match; consistent with domain language |
| "Finding" | `Finding` | Same — already natural language |
| "Exception" | `Exception` | Same — legal/compliance professionals recognise "exception" |

---

## Empty States

| Section | First-time state | Message and CTA |
|---------|----------------|-----------------|
| Home | No storage locations connected | "Your data estate is empty. Connect your first storage location to start scanning." → [Connect storage] |
| Data Estate → Storage Locations | No locations | "No storage locations registered yet." → [Register location] |
| Compliance → Findings | No findings | "No compliance findings — your connected locations are clean, or scanning hasn't run yet." |
| Audit Trail | New tenant | "Your audit trail is empty. Actions taken in {product_name} will appear here." |
```

## Quality Checks
- [ ] Navigation hierarchy is 3 levels deep maximum
- [ ] Every persona's primary job is reachable within 2 clicks from Home
- [ ] Role-based visibility table covers all roles and sections
- [ ] UI label glossary explains any divergence from domain terms
- [ ] Empty states are defined for all major sections
- [ ] Home dashboard layout shows key metrics immediately (no drilling required)
