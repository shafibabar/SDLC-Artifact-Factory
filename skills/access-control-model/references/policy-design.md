# ABAC Policy Design — Full Rule Blocks

Self-contained — loadable without reading `SKILL.md` first. The `SKILL.md`
body carries a compact summary table of these four baseline policies and
their evaluation order; this file holds the full natural-language rule
block and pseudo-code for each, the reference-grade elaboration.

Policies are expressed as rules that combine attributes to reach an `allow`
or `deny` decision. Write policies in natural language first, then translate
to code.

---

## Policy 1: Tenant Isolation (mandatory on all resources)

```
Allow access to resource R if:
  subject.tenant_id == resource.tenant_id

Deny otherwise — regardless of any other attributes.
```

This is the first check, always. No other attribute matters if the tenant IDs don't match.

## Policy 2: Role-Based Permission Check

```
Allow action A on resource type T if:
  action.operation is in subject.permissions

Example:
  Allow "classify-data-asset" if "data-assets:write" in subject.permissions
  Allow "generate-report" if "reports:generate" in subject.permissions
```

## Policy 3: Sensitivity-Based Access

```
Allow read of resource R if:
  resource.sensitivity is in subject.accessible_sensitivity_levels
  (defined per role: Compliance Officer → [Public, Internal, Confidential, Restricted])
  (read-only analyst → [Public, Internal, Confidential])
```

## Policy 4: Resource Ownership (for personal resources)

```
Allow modification of resource R if:
  subject.id == resource.owner_id
  OR subject has "admin" permission
```
