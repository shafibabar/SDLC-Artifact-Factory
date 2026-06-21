# Skill: design/system-context-diagram

## Purpose
Produce the C4 System Context Diagram (Level 1) — the highest-level view of the system. Shows the product as a black box in the centre, surrounded by the people (personas) who use it and the external systems it integrates with. This diagram is for communicating to non-technical stakeholders and executive sponsors.

## Inputs
- `artifacts/strategy/vision.md`
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/ideate/requirements/functional.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/architecture/c4-context.md`
**Registers in manifest:** yes

## C4 Level 1 Rules (enforced)
- The system under development appears once in the centre.
- People (users, roles) are shown as external actors.
- External systems (third-party services, storage platforms, customer-controlled systems) are shown as external boxes.
- No internal components visible at this level — it is a black box.
- Every relationship has a label describing what flows (not how).
- Relationships include direction (arrow) and protocol/mechanism where relevant.

## Artifact Template

```markdown
# C4 System Context Diagram

**Product:** {product_name}
**Phase:** Design
**Artifact:** System Context (C4 Level 1)
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Diagram

```mermaid
C4Context
  title System Context for {product_name}

  Person(admin, "Administrator", "Registers storage locations and manages compliance configuration")
  Person(compliance_officer, "Compliance Officer", "Reviews findings, manages exceptions, tracks posture")
  Person(auditor, "External Auditor", "Read-only access to audit trail and compliance posture reports")

  System(product, "{product_name}", "Maps data estates, extracts sensitive entities, evaluates compliance posture, and produces findings")

  System_Ext(google_drive, "Google Drive / Workspace", "Cloud file storage — customer-operated")
  System_Ext(aws_s3, "AWS S3", "Object storage — customer-operated")
  System_Ext(sharepoint, "SharePoint / OneDrive", "Microsoft cloud storage — customer-operated")
  System_Ext(secrets_mgr, "Secrets Manager", "Credential storage — customer-operated (AWS SM / HashiCorp Vault)")
  System_Ext(identity_provider, "Identity Provider", "SSO / OIDC provider — customer-operated (Okta, Azure AD, Google)")
  System_Ext(notification_channel, "Notification Channels", "Email, Slack, PagerDuty — customer-configured")

  Rel(admin, product, "Registers storage locations, configures scan schedules", "HTTPS / browser")
  Rel(compliance_officer, product, "Reviews findings, manages exceptions, exports reports", "HTTPS / browser")
  Rel(auditor, product, "Reviews audit trail, exports compliance evidence", "HTTPS / browser")
  Rel(product, google_drive, "Reads file metadata and content (read-only)", "Google Drive API / OAuth2")
  Rel(product, aws_s3, "Reads object metadata and content (read-only)", "AWS SDK / IAM Role")
  Rel(product, sharepoint, "Reads file metadata and content (read-only)", "Microsoft Graph API / OAuth2")
  Rel(product, secrets_mgr, "Reads storage credentials at scan time", "SDK (read-only)")
  Rel(product, identity_provider, "Delegates authentication", "OIDC / OAuth2")
  Rel(product, notification_channel, "Sends finding alerts and digest notifications", "Webhook / SMTP / SDK")
```

---

## System Description

**System:** {product_name}

{2–3 sentence description of the system from the outside — what it does, not how it does it. Who uses it, what value it delivers.}

---

## External Actors

| Actor | Type | Relationship to system |
|-------|------|----------------------|
| Administrator | Person (internal to customer org) | Configures the system; registers storage locations |
| Compliance Officer | Person (internal to customer org) | Primary beneficiary; consumes compliance findings |
| External Auditor | Person (third party) | Read-only evidence consumer |

---

## External Systems

| System | Operated by | Purpose | Integration |
|--------|------------|---------|-------------|
| Google Drive / Workspace | Customer | File storage being scanned | Google Drive API (read-only) |
| AWS S3 | Customer | Object storage being scanned | AWS SDK (read-only IAM role) |
| SharePoint / OneDrive | Customer | Microsoft file storage being scanned | Microsoft Graph API (read-only) |
| Secrets Manager | Customer | Credential storage | SDK (read-only, at scan time) |
| Identity Provider | Customer | SSO / authentication | OIDC / OAuth2 |
| Notification Channels | Customer-configured | Alert delivery | Webhook / SMTP |

---

## What the System Does NOT Do (Context Boundary)

| Out of scope | Reason |
|-------------|--------|
| Store file content | Files are scanned in customer infrastructure; no content transits or is stored on product infrastructure |
| Manage customer user accounts | Delegated to customer's identity provider |
| Write to any customer storage system | Read-only access is an architectural non-negotiable |
| Process data outside customer-controlled infrastructure | WorkerNodes execute in customer environment |
```

## Quality Checks
- [ ] System appears once as a black box — no internal components visible
- [ ] All external personas from `artifacts/ideate/personas/` are represented
- [ ] All external system integrations from functional requirements are included
- [ ] "What the system does NOT do" is populated — clarifies the boundary
- [ ] No implementation details in the diagram (no technology names in boxes, only in relationship labels where relevant)
