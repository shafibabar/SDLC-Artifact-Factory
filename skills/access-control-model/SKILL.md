---
name: access-control-model
description: >
  Teaches how to design an Attribute-Based Access Control (ABAC) model for a
  multi-tenant SaaS product — covering policy design, attribute definition
  (subject, resource, action, environment) as Domain Primitives that make
  illegal states unrepresentable (per Secure by Design), Go policy
  enforcement patterns, a per-Aggregate trust-boundary decision checklist,
  the distinction between authentication and authorisation, role-to-permission
  mapping, and how ABAC policies connect to JWT claims and API endpoint guards.
  Used by the security-architect agent during the Design phase.
version: 2.0.0
phase: design
owner: security-architect
created: 2026-06-25
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

## Attributes Are Domain Primitives, Not Bare Types

Per *Secure by Design* (`research/security/secure-by-design.md`), a tenant ID, a permission, or a sensitivity level should be types that cannot hold an invalid value once constructed — not a bare `uuid.UUID`/`string` that every call site must remember to validate. `TenantID`, `Permission`, and `Sensitivity` are Domain Primitives: immutable, self-validating at construction, with validity checked once, at the single constructor, not re-checked ad hoc wherever the value travels.

This is the same Domain Primitive concept `subdomain-distillation`'s `references/security-sensitive-subdomains.md` covers generally (illegal states unrepresentable, Assertions, security-sensitivity as an axis orthogonal to a Subdomain's Core/Supporting/Generic classification) — this skill applies it specifically to ABAC's own attribute types. Full Go constructors, the Go-specific zero-value trap, and the discarded-error failure mode: `references/domain-primitives-and-enforcement.md`.

---

## Attribute Categories

### Subject Attributes (who is making the request)

| Attribute | Source | Example |
|---|---|---|
| `subject.id` | JWT `sub` claim | `user-uuid` |
| `subject.tenant_id` | JWT `tenant_id` claim | `tenant-uuid` |
| `subject.roles` | JWT `roles` claim | `["compliance-officer"]` |
| `subject.permissions` | JWT `permissions` claim | `["data-assets:read", "reports:generate"]` |
| `subject.email` | JWT `email` claim | `maya.chen@example.com` |

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

**X-Forwarded-For is attacker-controlled.** Only trust it when the request arrived through your own edge proxy, and take the rightmost address appended by a trusted hop — never the leftmost value, which the client can set freely. If the deployment has no trusted proxy, use the TCP peer address instead.
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

Permissions follow the pattern: `[resource-type]:[action]` — and, per the Domain Primitives section above, this is not just a naming convention to follow by discipline. `Permission` is a Domain Primitive whose constructor rejects any string that doesn't match the pattern, so a malformed permission cannot exist as a value in the system at all.

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

**Staleness rule:** permissions embedded in a JWT are frozen until the token expires. Keep access-token TTL short (≤ 1 hour) so role changes propagate quickly, and revoke immediately on offboarding by checking a server-side session deny-list — never rely on token expiry alone for access removal (SOC 2 CC6.3).

| Role | Permissions |
|---|---|
| `compliance-officer` | `data-assets:read`, `compliance-gaps:read`, `reports:generate` |
| `it-lead` | `storage-sources:manage`, `data-assets:read`, `admin:config` |
| `admin` | All permissions |
| `read-only-auditor` | `data-assets:read`, `compliance-gaps:read` (no write, no generate) |

---

## Go Policy Enforcement Pattern

The policy interface stays the same shape as any ABAC implementation — a `Subject`/`Resource`/`Action` evaluated by an `AccessPolicy`. What changes with Domain Primitives is only the field types: `Subject.TenantID` is `TenantID`, not `uuid.UUID`; `Subject.Permissions` is `[]Permission`, not `[]string`. The tenant-isolation check becomes `sub.TenantID.Equal(res.TenantID)` — a total, panic-free comparison, because an invalid `TenantID` cannot exist by construction. Full before/after code, the `TenantID`/`Permission`/`Sensitivity` constructors, and the Assertion checklist for adding new security-relevant types: `references/domain-primitives-and-enforcement.md`.

**Uniform denial:** the same `ErrForbidden` is returned for a wrong-tenant resource and for a missing permission. If wrong-tenant returned a different error (or a 404 only sometimes), an attacker could probe which resource IDs exist in other tenants. One error, one message, no distinguishing detail — log the real reason server-side with the request ID.

**Enforcement location:** Policy evaluation happens in the Application layer (command/query handlers) — not in the API layer. The API layer validates the JWT structure; the Application layer evaluates the policy. This prevents policy bypass by calling internal methods directly.

---

## Per-Aggregate Trust-Boundary Checklist

"The Application layer handles it" is an assumption until it's checked per Aggregate. For every Aggregate, ask: can it be reached by more than one tenant's request path; does entering it require an authorization decision beyond authentication; and if so, is that decision expressed as a named domain concept (`Subject` + `AccessPolicy.Evaluate`) rather than left implicit in unnamed middleware? Full checklist and the gap it's designed to catch: `references/domain-primitives-and-enforcement.md`.

---

## Multi-Tenancy and Access Control

For physical multi-tenancy (separate deployments per tenant), the tenant isolation check is partially redundant — the network routing already prevents cross-tenant requests. However, the tenant isolation policy check is still enforced as a defence-in-depth measure. If the routing layer is misconfigured, the policy check is the backstop. **This redundancy argument only covers the tenant-isolation policy.** Per *Secure by Design*'s "layered defense is not an excuse for shallow domain modeling," it does not extend to skipping Domain Primitives for `TenantID`/`Permission`/`Sensitivity` — those exist to make illegal states unrepresentable in the domain model itself, a property the network layer cannot provide regardless of deployment topology.

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
| Uniform denial | Wrong-tenant and no-permission return the same error | Different errors reveal resource existence across tenants |
| Domain Primitives | `TenantID`/`Permission`/`Sensitivity` are self-validating types constructed once | Bare `uuid.UUID`/`string` fields validated ad hoc, if at all |
| Trust boundaries reviewed per Aggregate | Every Aggregate has an explicit, recorded trust-boundary decision | Authorization coverage assumed rather than checked per Aggregate |

---

## Anti-Patterns

- **Tenant ID from the request body.** The tenant ID used in policy evaluation must come from the JWT claim, never from a client-supplied field. A client-supplied `tenant_id` turns tenant isolation into a suggestion.
- **Role explosion.** Creating a new role for every permission combination (`compliance-officer-readonly-no-reports`) instead of composing permissions. Roles bundle permissions; they are not the decision unit.
- **Checking roles instead of permissions.** `if subject.HasRole("admin")` scattered through handlers couples code to the role catalogue. Check permissions; roles map to permissions in one place.
- **Authorisation only in middleware.** Route middleware cannot see resource attributes (sensitivity, owner) because the resource has not been loaded yet. Middleware handles authentication; the Application layer handles authorisation.
- **Confused deputy.** A background job or service-to-service call that runs with a system identity and performs actions on behalf of a user without carrying the user's subject attributes. Propagate the original subject through the call chain.
- **Leaking the denial reason.** Returning "resource belongs to another tenant" or "you lack data-assets:write" to the caller. Both are reconnaissance gifts. Uniform error out; detailed reason in the server log.
- **Trusting stale JWTs for offboarding.** Treating token expiry as access removal. Termination must revoke sessions server-side, immediately.
- **Primitive obsession.** Passing `TenantID`/`Permission`/`Sensitivity` around as bare `uuid.UUID`/`string` fields "for now" — every call site becomes a place validity can silently be skipped, and the Permission Naming Convention degrades back to documentation nobody enforces.
- **Discarding the constructor's error.** `tid, _ := NewTenantID(raw)` defeats the entire point of a Domain Primitive — the zero value slips through exactly the path the constructor exists to close off. See the Assertion checklist in `references/domain-primitives-and-enforcement.md`.

---

## Output Format

Template: `references/output-format-template.md`. Includes attribute schema, Domain Primitives table, policies, role→permission mapping, permission registry, per-Aggregate trust-boundary decisions, Go policy interface, and enforcement locations.
