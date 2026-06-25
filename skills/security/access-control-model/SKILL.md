---
name: access-control-model
description: >
  Teaches how to design an Attribute-Based Access Control (ABAC) model for a
  multi-tenant SaaS product — covering policy design, attribute definition
  (subject, resource, action, environment), Go policy enforcement patterns,
  the distinction between authentication and authorisation, role-to-permission
  mapping, and how ABAC policies connect to JWT claims and API endpoint guards.
  Used by the security-architect agent during the Design phase.
version: 1.0.0
phase: design
owner: security-architect
tags: [design, security, abac, access-control, authorisation, rbac, jwt, go]
---

# Access Control Model

## Purpose

Access control governs what an authenticated identity is permitted to do. Authentication answers "who are you?" Access control answers "what are you allowed to do?"

This skill teaches Attribute-Based Access Control (ABAC) — a model that evaluates access decisions based on attributes of the subject (the user), the resource being accessed, the action being requested, and the environment (time, tenant, network context). ABAC is more expressive than simple Role-Based Access Control (RBAC) and is required for the first product's compliance use case.

---

## ABAC vs RBAC

| | RBAC | ABAC |
|---|---|---|
| **Decision basis** | User's role | Combination of subject, resource, action, and environment attributes |
| **Expressiveness** | "Compliance Officers can read compliance gaps" | "Compliance Officers can read compliance gaps in their own tenant, but only during business hours if the gap is not under legal hold" |
| **Complexity** | Simple to implement and reason about | More complex; requires policy engine or explicit policy evaluation |
| **Fit for** | Simple, stable permission structures | Complex, context-sensitive permissions; multi-tenant; compliance requirements |

**This plugin uses ABAC as the primary model.** Roles are implemented as a bundle of pre-defined attributes — they are a convenience shortcut, not the source of truth. The policy always evaluates attributes, not roles directly.

---

## Attribute Categories

### Subject Attributes (who is making the request)

| Attribute | Source | Example |
|---|---|---|
| `subject.id` | JWT `sub` claim | `user-uuid` |
| `subject.tenant_id` | JWT `tenant_id` claim | `tenant-uuid` |
| `subject.roles` | JWT `roles` claim | `["compliance-officer"]` |
| `subject.permissions` | JWT `permissions` claim | `["data-assets:read", "reports:generate"]` |
| `subject.email` | JWT `email` claim | `yuki@example.com` |

### Resource Attributes (what is being accessed)

| Attribute | Source | Example |
|---|---|---|
| `resource.type` | Derived from the endpoint path | `data-asset` |
| `resource.id` | Path parameter | `asset-uuid` |
| `resource.tenant_id` | Loaded from the database | `tenant-uuid` |
| `resource.sensitivity` | Loaded from the database | `Restricted` |
| `resource.owner_id` | Loaded from the database | `user-uuid` (who created it) |

### Action Attributes (what is being done)

| Attribute | Source | Example |
|---|---|---|
| `action.type` | HTTP method | `read`, `write`, `delete`, `admin` |
| `action.operation` | Endpoint identifier | `classify-data-asset`, `generate-report` |

### Environment Attributes (contextual conditions)

| Attribute | Source | Example |
|---|---|---|
| `env.ip_address` | Request header (X-Forwarded-For, validated) | `203.0.113.1` |
| `env.time` | Server time | `2026-06-25T14:30:00Z` |
| `env.request_id` | Request context | `req-uuid` |

---

## Policy Design

Policies are expressed as rules that combine attributes to reach an `allow` or `deny` decision. Write policies in natural language first, then translate to code.

### Policy 1: Tenant Isolation (mandatory on all resources)

```
Allow access to resource R if:
  subject.tenant_id == resource.tenant_id

Deny otherwise — regardless of any other attributes.
```

This is the first check, always. No other attribute matters if the tenant IDs don't match.

### Policy 2: Role-Based Permission Check

```
Allow action A on resource type T if:
  action.operation is in subject.permissions

Example:
  Allow "classify-data-asset" if "data-assets:write" in subject.permissions
  Allow "generate-report" if "reports:generate" in subject.permissions
```

### Policy 3: Sensitivity-Based Access

```
Allow read of resource R if:
  resource.sensitivity is in subject.accessible_sensitivity_levels
  (defined per role: Compliance Officer → [Public, Internal, Confidential, Restricted])
  (read-only analyst → [Public, Internal, Confidential])
```

### Policy 4: Resource Ownership (for personal resources)

```
Allow modification of resource R if:
  subject.id == resource.owner_id
  OR subject has "admin" permission
```

---

## Permission Naming Convention

Permissions follow the pattern: `[resource-type]:[action]`

| Permission | Meaning |
|---|---|
| `data-assets:read` | Read any data asset in the tenant |
| `data-assets:write` | Classify or modify data assets |
| `storage-sources:manage` | Connect, configure, and disconnect storage sources |
| `compliance-gaps:read` | Read compliance gap reports |
| `reports:generate` | Generate and export reports |
| `admin:users` | Manage user accounts within the tenant |
| `admin:config` | Modify tenant configuration |

---

## Role → Permission Mapping

Roles are shorthand for a bundle of permissions. A user's permissions are derived from their roles but stored as explicit claims in the JWT.

| Role | Permissions |
|---|---|
| `compliance-officer` | `data-assets:read`, `compliance-gaps:read`, `reports:generate` |
| `it-lead` | `storage-sources:manage`, `data-assets:read`, `admin:config` |
| `admin` | All permissions |
| `read-only-auditor` | `data-assets:read`, `compliance-gaps:read` (no write, no generate) |

---

## Go Policy Enforcement Pattern

```go
// Policy interface — defined in domain layer
type AccessPolicy interface {
    Evaluate(ctx context.Context, subject Subject, resource Resource, action Action) error
}

// Subject — built from the JWT at request entry
type Subject struct {
    ID          uuid.UUID
    TenantID    uuid.UUID
    Roles       []string
    Permissions []string
}

// Policy check — called in every handler or application layer
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    subject := SubjectFromContext(ctx)
    resource := Resource{Type: "data-asset", ID: cmd.DataAssetID, TenantID: cmd.TenantID}
    action := Action{Operation: "classify-data-asset"}

    if err := h.policy.Evaluate(ctx, subject, resource, action); err != nil {
        return ErrForbidden // never leak the reason to the caller
    }
    // ... proceed with command
}

// Policy implementation
type ABACPolicy struct {
    assetRepo DataAssetRepository
}

func (p *ABACPolicy) Evaluate(ctx context.Context, sub Subject, res Resource, act Action) error {
    // Rule 1: Tenant isolation — always first
    if sub.TenantID != res.TenantID {
        return ErrForbidden
    }
    // Rule 2: Permission check
    if !sub.HasPermission(act.RequiredPermission()) {
        return ErrForbidden
    }
    return nil
}
```

**Enforcement location:** Policy evaluation happens in the Application layer (command/query handlers) — not in the API layer. The API layer validates the JWT structure; the Application layer evaluates the policy. This prevents policy bypass by calling internal methods directly.

---

## Multi-Tenancy and Access Control

For physical multi-tenancy (separate deployments per tenant), the tenant isolation check is partially redundant — the network routing already prevents cross-tenant requests. However, the tenant isolation policy check is still enforced as a defence-in-depth measure. If the routing layer is misconfigured, the policy check is the backstop.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Tenant isolation first | Tenant ID check is the first policy evaluation | Tenant check is optional or only on some endpoints |
| ABAC not just RBAC | Policies evaluate resource attributes, not just roles | All decisions based solely on role membership |
| Permissions in JWT | JWT carries explicit permissions, not just roles | JWT carries only roles; server re-derives permissions |
| Policy in application layer | Access checks in Application layer command/query handlers | Access checks only in API handler middleware |
| Permission naming convention | `[resource-type]:[action]` pattern | Ad-hoc permission names |
| Deny by default | Default policy result is deny; allow is explicit | Default allow with explicit deny |

---

## Output Format

```markdown
---
artifact: access-control-model
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Access Control Model

## Attribute Schema
[Subject, Resource, Action, Environment attributes with sources]

## Policies
| Policy ID | Rule (natural language) | Attributes evaluated | Decision |
|---|---|---|---|

## Role → Permission Mapping
| Role | Permissions |
|---|---|

## Permission Registry
| Permission | Resource type | Action | Description |
|---|---|---|---|

## Go Policy Interface
[Policy interface and Subject/Resource/Action types]

## Enforcement Locations
| Layer | What is checked | Who calls the policy |
|---|---|---|
```
