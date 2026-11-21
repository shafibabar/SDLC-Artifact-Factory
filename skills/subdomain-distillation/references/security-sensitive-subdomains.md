# Security-Sensitive Subdomains

The detail behind `SKILL.md` § 4. Self-contained: it assumes the Core / Supporting / Generic classification and adds a second, independent axis. Grounded in *Secure by Design* (Bergh Johnsson, Deogun, Sawano), as summarised in `research/security/secure-by-design.md`. Stack-neutral; how a Domain Primitive is written in a given language belongs to the implementation skills (`access-control-model` covers the access-control attributes).

## 1. Two questions, two axes

The type answers *how much advantage does this subdomain create?* Secure by Design (Ch. 3) asks a different question: *would a mistake in this model cause unauthorised data exposure, financial loss or a safety failure?* The two are rated side by side, not folded together. A Generic subdomain can be highly sensitive; a Core one can be harmless.

The usual case is a bought or adopted component with a product-specific slice:

- **The component stays Generic.** Nobody gains an advantage by writing their own password hashing or sign-in flow. Buy or adopt it.
- **The product-specific slice doesn't.** *Which role may see which field, for which tenant, under what condition* depends on this product's own model. No bought component can know it, and getting it wrong is a breach. That slice gets Core-level rigor.

## 2. Why a gateway or middleware isn't the answer

A common argument: "the gateway authenticates every request and the middleware checks roles, so the model needn't encode access rules." Secure by Design calls this backwards for business-level questions. "Can a clinic receptionist at one practice see a patient record created by another practice in the same group?" is a domain question. Infrastructure checks the caller's identity; only the model knows how records, practices and roles relate. Domain-level invariants are often the last and most reliable defence (and every service still verifies identity itself; the gateway is only the first check, D047-12).

## 3. The checklist

Run it for every subdomain, alongside the type:

1. Does it handle personal data, secrets, credentials, payment or other financial data directly?
2. Is it a trust boundary: does it cross tenants, privilege levels or organisations?
3. Could a **model** error here (not a misconfiguration) plausibly cause unauthorised exposure, or a financial or safety failure?

**Any yes** flags the subdomain's sensitive slice. Name the slice. The rest of the subdomain keeps its type's level of effort. A "no" is recorded as the result of running the checklist, not assumed.

## 4. What Core-level rigor means for the slice

- **Domain Primitives:** small, self-validating value types that make illegal states impossible to build, including security-relevant ones. Not only "an email that validates its format", but an access scope that can't exist without a valid tenant and role, or a redacted field that a raw personal value can't slip past.
- **Assertions at construction:** validity checked once, where the value is created, not scattered through callers. If an invariant can be broken, the type that should have prevented it wasn't strict enough.
- **Security in the language:** access and trust concepts become named terms in the context's Ubiquitous Language (`ubiquitous-language`), such as Access Scope, Tenant Boundary or Redaction Policy, rather than unnamed framework settings.
- **Aggregates as trust boundaries:** decide which Aggregates require an authorisation check to cross, and which operate inside an already-trusted context. That is a modelling decision, recorded in `aggregate-design`, not a middleware setting.

## 5. Short examples

| Product | Subdomain (type) | Checklist | Sensitive slice |
|---|---|---|---|
| Volunteer rota app | Sign-in (Generic, adopted) | 1 yes (personal data) | Which coordinator may see which volunteers' contact details |
| Courier route planning | Payments to drivers (Generic, bought) | 1 yes (financial) | Mapping completed jobs to payable amounts per driver; nothing else |
| Loan origination | Identity and access (Generic, bought) | 1, 2, 3 yes | Which underwriter may approve which loan size, by delegated authority; segregation of duties between who submits and who approves |
| Clinic group booking | Patient records access (Supporting) | 1, 2 yes | Cross-practice visibility rules inside the group |
