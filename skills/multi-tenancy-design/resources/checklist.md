# Checklist: Multi-Tenancy Design

Resource for `multi-tenancy-design`. Run after `./scripts/validate-multi-tenancy-design.sh` is clean; the script checks structure, this list checks judgement.

## Inputs
- [ ] Tenant count and growth, residency, noisy-neighbour and availability NFRs read; data classification and compliance input read; contract clauses and tiers known, or listed as open questions.
- [ ] The product is actually multi-tenant (a single-tenant product skips this artifact).

## Model
- [ ] Every resource holding or processing tenant data has a row: compute, each data store, broker, caches, search, object storage, telemetry.
- [ ] Each row names its model (pool, bridge, silo) and the forces that decided it.
- [ ] No model was taken as a default; a silo or a full stamp has a named source.
- [ ] Overall model stated (pool, bridge, silo, mixed) and the tiers, if any, with what each promises.
- [ ] Residency is met by regions, not assumed to need a stamp per tenant.
- [ ] Pooled stores have a tenant-leading key; the large-tenant hot-key case is addressed.

## Compliance
- [ ] Every push toward silo or region names its source: law, contract, tier, risk (`./compliance-basis.md`).
- [ ] No claim that SOC 2 (or GDPR, HIPAA, PCI DSS) requires physical or per-tenant isolation.

## Isolation
- [ ] Tenant context from the verified token at every layer; never client-supplied; no tenant means refuse.
- [ ] Each pooled table: forced row-level security, non-owner role, tenant set per transaction.
- [ ] Broker enforcement matches the model chosen for the broker.
- [ ] Silos: default-deny network between tenants, own credentials.
- [ ] The cross-tenant test is named as a release gate.

## Lifecycle and Operations
- [ ] Onboarding automated for every tier; tier change designed in both directions.
- [ ] Offboarding: export, then deletion everywhere the tenant's data lives, including backups (or per-tenant key destruction).
- [ ] Metering, metrics and cost per tenant distinguished; how cost is attributed in a pool stated.
- [ ] Noisy-neighbour controls per tier.
- [ ] For silos: one version source, waves, bounded skew.
- [ ] The control plane never reads tenant data.

## Hand-off
- [ ] ADR for the model; deployment view (`container-diagram`), partitioning (`data-model-design`), threat model, provisioning noted as next steps.
