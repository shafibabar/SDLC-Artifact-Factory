# Domain Primitives and Policy Enforcement

Concrete Go patterns making ABAC's core types illegal-state-proof, and the
updated policy enforcement code that uses them. Per *Secure by Design*
(Bergh Johnsson, Deogun, Sawano — `research/security/secure-by-design.md`).
Self-contained — loadable without reading `SKILL.md` first. For the general
Domain Primitive / Assertion / trust-boundary concepts this file applies,
see `subdomain-distillation`'s `references/security-sensitive-subdomains.md`
— this file does not re-explain them, only shows the ABAC-specific
application.

---

## Why Bare Types Aren't Enough

`Subject`, `Resource`, and `Action` today are plain structs with bare
`uuid.UUID`/`string`/`[]string` fields. Nothing stops a
`Resource{TenantID: uuid.Nil}` or a permission string with an
off-convention shape from being constructed and passed straight into
`ABACPolicy.Evaluate` — the Permission Naming Convention table is
documentation, not an enforced invariant. Domain Primitives close this
gap: `TenantID`, `Permission`, and `Sensitivity` become types that cannot
hold an invalid value once constructed, checked once at the single
constructor, never re-validated ad hoc at each call site.

## Domain Primitive: TenantID

```go
// TenantID is a Domain Primitive: constructible only through NewTenantID,
// which is the single place validity is enforced. Once constructed, every
// caller can treat a TenantID as always-valid — no defensive re-checking.
type TenantID struct {
    value uuid.UUID
}

func NewTenantID(raw string) (TenantID, error) {
    id, err := uuid.Parse(raw)
    if err != nil {
        return TenantID{}, fmt.Errorf("invalid tenant id %q: %w", raw, err)
    }
    if id == uuid.Nil {
        return TenantID{}, fmt.Errorf("tenant id cannot be nil")
    }
    return TenantID{value: id}, nil
}

func (t TenantID) String() string           { return t.value.String() }
func (t TenantID) Equal(other TenantID) bool { return t.value == other.value }
```

**The Go zero-value trap**: unlike the book's Java/Kotlin examples, Go
always has an accessible zero value (`TenantID{}`). A Domain Primitive
constructor must explicitly guard against the zero value looking valid —
the `uuid.Nil` check above exists specifically for this reason, not as
generic defensive coding.

## Domain Primitive: Permission

```go
// Permission enforces the [resource-type]:[action] convention at
// construction — the Permission Naming Convention table becomes a type
// invariant, not documentation a call site might not follow.
type Permission struct {
    resourceType string
    action       string
}

var permissionPattern = regexp.MustCompile(`^[a-z][a-z-]*:[a-z][a-z-]*$`)

func NewPermission(raw string) (Permission, error) {
    if !permissionPattern.MatchString(raw) {
        return Permission{}, fmt.Errorf("permission %q does not match [resource-type]:[action]", raw)
    }
    parts := strings.SplitN(raw, ":", 2)
    return Permission{resourceType: parts[0], action: parts[1]}, nil
}

func (p Permission) String() string { return p.resourceType + ":" + p.action }
```

## Domain Primitive: Sensitivity

```go
// Sensitivity is a closed enumeration, not an arbitrary string — a value
// outside the four defined levels cannot be constructed at all.
type Sensitivity int

const (
    Public Sensitivity = iota
    Internal
    Confidential
    Restricted
)

func NewSensitivity(raw string) (Sensitivity, error) {
    switch raw {
    case "Public":
        return Public, nil
    case "Internal":
        return Internal, nil
    case "Confidential":
        return Confidential, nil
    case "Restricted":
        return Restricted, nil
    default:
        return 0, fmt.Errorf("unknown sensitivity level %q", raw)
    }
}
```

## Assertion Checklist for Any New Security-Relevant Type

Before adding a new type that carries a security-relevant value:

1. Can this type ever hold a value the domain considers invalid or
   dangerous once constructed? If yes, it is not yet a Domain Primitive.
2. Is validity checked in more than one place? If yes, collapse to a
   single constructor.
3. Does the zero value accidentally look valid? Guard against the
   zero-value trap explicitly, as `NewTenantID` does above.
4. **Is the constructor's error return ever discarded?** `tid, _ :=
   NewTenantID(raw)` silently reintroduces the exact illegal-state risk
   the pattern exists to prevent — Go offers no automatic exception
   propagation the way the book's source-language examples rely on, so a
   discarded error is a sharper failure mode in Go than in the book's own
   examples, not a weaker one.

## Updated Go Policy Enforcement Pattern

```go
// Subject — built from the JWT at request entry, using Domain Primitives
type Subject struct {
    ID          uuid.UUID
    TenantID    TenantID     // Domain Primitive — always valid once constructed
    Roles       []string
    Permissions []Permission // Domain Primitive — always well-formed
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
    // Rule 1: Tenant isolation — always first. TenantID.Equal is total: it
    // can never panic or compare an invalid value, because an invalid
    // TenantID cannot exist by construction.
    if !sub.TenantID.Equal(res.TenantID) {
        return ErrForbidden
    }
    // Rule 2: Permission check
    if !sub.HasPermission(act.RequiredPermission()) {
        return ErrForbidden
    }
    return nil
}
```

The behavior is identical to the bare-type version — the change is where
invalidity becomes *impossible* (at `NewTenantID`/`NewPermission`
construction) instead of merely *checked* (inside `Evaluate`, hopefully,
if nobody forgot).

## Per-Aggregate Trust-Boundary Checklist

For every Aggregate, answer explicitly and record the answer — this turns
"the Application layer handles it" from an assumption into a reviewable
decision per resource type:

1. Can this Aggregate be reached by more than one tenant's request path?
2. Does crossing into this Aggregate require an authorization decision
   beyond "the caller is authenticated"?
3. If yes to (2), is that check expressed as a domain concept (`Subject` +
   `AccessPolicy.Evaluate`) or left implicit in a middleware function with
   no name a domain expert would recognize?

A "yes" to (2) with a "no" to (3) is the gap this checklist exists to
catch — an authorization decision that exists but has no domain name.
