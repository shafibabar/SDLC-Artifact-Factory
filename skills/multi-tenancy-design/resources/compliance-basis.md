# Compliance Basis

Resource for `multi-tenancy-design`. Cross-check the artifact's Compliance Basis section against this table before hand-off: every push toward a silo or a region names its source, and no row claims a framework requires what it doesn't.

This is the repo's reading of the frameworks, not legal advice and not from Golding's text (`research/software-architecture/building-multi-tenant-saas-golding.md`, Caveats). Where a customer's lawyers or auditors say otherwise, record what they said as a **contract** push, with its source. Framework controls themselves belong to `compliance-design`.

## Frameworks and Laws

| Framework or law | What it asks for | What it does **not** require | Pushes toward silo or region when |
|---|---|---|---|
| **SOC 2** (AICPA Trust Services Criteria) | An auditor attests that the provider's own controls meet outcome criteria: logical access restricted, changes controlled, incidents handled, data protected | Any deployment model; physical isolation; a database per tenant. A pool with enforced, tested logical isolation can pass | The provider itself *promises* customers physical isolation; then that promise is a control it must meet (a contract push, not a SOC 2 one) |
| **ISO/IEC 27001** | A managed information security system and the risk-based controls it selects | A deployment model | Its own risk assessment selects a silo for a named risk |
| **GDPR** | Appropriate technical and organisational safeguards; rules on transfers outside the EEA | Physical separation; in-region storage by itself | Transfers must be avoided by policy or contract; then a region (a pool per region is enough) |
| **HIPAA** | Safeguards for protected health information; business associate agreements | Physical separation | A business associate agreement or customer contract asks for dedicated resources |
| **PCI DSS** | Protect cardholder data; segmentation to reduce scope; extra requirements for shared hosting providers | Physical separation; logical segmentation is accepted | Keeping systems out of scope is cheaper with a separate cardholder-data environment (a per-resource silo, not per tenant) |
| **Data-localisation laws** (some countries) | Certain data stored or processed in-country | — | Always for the affected data: a region or in-country deployment |
| **Government cloud programmes** | Their own authorised boundaries | — | The programme's boundary: often a separate deployment for those tenants |

## Other Sources of a Push

| Source | Example | Record as |
|---|---|---|
| **Contract** | "Dedicated database", "customer-managed keys", "no co-mingled processing" | `contract: <customer>, <clause>` |
| **Tier** | Premium tier sells dedicated resources or a performance guarantee | `tier: <tier name>` |
| **Customer hosting** | The customer runs it in their own account | `contract: customer-hosted` |
| **Risk** | A tenant's load or data can't be contained in the pool | `risk: <named risk>` |

## Wording to Avoid

| Don't write | Write |
|---|---|
| "SOC 2 requires physical isolation" | "SOC 2 attests our access controls; tenants are isolated by <mechanism>, tested by <cross-tenant test>" |
| "GDPR requires a stamp per EU tenant" | "EU tenants' data stays in the EU region (pool per region)" |
| "Compliance requires a silo" | "Silo for <tenant>: contract clause <n>" |
