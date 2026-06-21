# Skill: deploy/feature-flag-design

## Purpose
Produce the Feature Flag Design — the specification of all runtime toggles, their purpose, their owners, their rollout plan, and their cleanup obligation. Feature flags enable safe progressive delivery. Every flag has a defined lifetime — no permanent flags.

## Inputs
- `artifacts/ideate/backlog/epics/` (features requiring flags)
- `artifacts/design/platform/deployment-architecture.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/deploy/feature-flags.md`
**Registers in manifest:** yes

## Feature Flag Rules (enforced)
- Every flag has a declared lifetime (temporary or permanent) and an owner.
- Temporary flags have a removal date target — no flag lives longer than 90 days without review.
- Flags are never used for configuration that belongs in environment config.
- Flag state changes are logged in the audit trail.
- No business logic is gated on more than 2 nested flags — complexity is a defect.

## Artifact Template

```markdown
# Feature Flag Design
**Product:** {product_name}
**Phase:** Deploy
**Artifact:** Feature Flag Design
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Flag Registry

| Flag key | Type | Purpose | Default | Owner | Lifetime | Target removal |
|----------|------|---------|---------|-------|---------|---------------|
| `enable_google_drive_connector` | Release | Gates the Google Drive storage location feature | false | PM | Temporary | After GA rollout (< 90 days) |
| `enable_entity_extraction_v2` | Experiment | A/B test new NER model accuracy vs v1 | false | Tech Lead | Temporary | After experiment concludes |
| `maintenance_mode` | Operational | Puts all APIs into maintenance mode (503) | false | Platform | Permanent | Never (operational control) |
| `enable_chaos_endpoints` | Kill switch | Enables debug/chaos injection endpoints | false | Tech Lead | Permanent | Never (safety control — always off in prod) |
| `enable_debug_endpoints` | Kill switch | Enables debug information endpoints | false | Tech Lead | Permanent | Never |

---

## Flag Type Definitions

| Type | Description | Production use |
|------|-------------|---------------|
| **Release** | Gates a new feature during rollout; removed when feature is GA | Enabled gradually via % rollout |
| **Experiment** | A/B or multivariate test; tied to an experiment definition | Random user cohort assignment |
| **Operational** | On/off control for operational reasons (maintenance, kill switch) | Manually toggled by operator |
| **Permission** | Per-tenant or per-user feature entitlement | Enabled per tenant in config |

---

## Flag Implementation

Flags are read from a key-value store (environment variable for dev; config service or feature flag platform for production). The application reads each flag on startup and caches it with a 60-second TTL.

```go
// internal/platform/flags/flags.go
type FeatureFlags struct {
    EnableGoogleDriveConnector bool
    EnableEntityExtractionV2   bool
    MaintenanceMode            bool
}

func LoadFromEnvironment() FeatureFlags {
    return FeatureFlags{
        EnableGoogleDriveConnector: getenvBool("FEATURE_ENABLE_GOOGLE_DRIVE_CONNECTOR", false),
        EnableEntityExtractionV2:   getenvBool("FEATURE_ENABLE_ENTITY_EXTRACTION_V2", false),
        MaintenanceMode:            getenvBool("FEATURE_MAINTENANCE_MODE", false),
    }
}
```

Flag state changes are published as `FeatureFlagChanged` domain events for audit trail.

---

## Rollout Plan: enable_google_drive_connector

| Date | % of tenants | Criteria to advance | Rollback trigger |
|------|-------------|--------------------|--------------------|
| Week 1 | 5% (internal) | 0 errors in logs | Any 5xx rate > 0.1% |
| Week 2 | 25% | p(99) latency within SLO | Any SLO breach |
| Week 3 | 75% | NPS stable | Any compliance gate failure |
| Week 4 | 100% | Full GA | — |
| Week 6 | Remove flag | Flag removed from code | — |

---

## Flag Cleanup

Temporary flags with a target removal date are tracked in the manifest. When a flag's target date passes, the `post-artifact-created` hook surfaces a reminder. Flags are removed by:
1. Setting the flag to `true` (or the final permanent state) in all environments
2. Removing all `if flags.EnableX` branch points from the code
3. Removing the flag from this document and from the FeatureFlags struct
4. Committing a PR titled `cleanup(flags): remove enable_google_drive_connector`
```

## Quality Checks
- [ ] Every flag has a type, owner, and lifetime
- [ ] Temporary flags have a target removal date
- [ ] Flag implementation shows actual Go code (not just concept)
- [ ] Rollout plan with % rollout and rollback triggers for release flags
- [ ] Flag cleanup procedure is documented
- [ ] Maximum 2-deep nesting rule is stated
