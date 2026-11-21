# Example 1 — Lean: Conformist to a good vendor model (simplest case)

Self-contained. **Rinkside** books ice-time slots for one skating club, at the **lean** profile. Contexts (from `bounded-context-mapping`): **Bookings** (Core). External systems: a payment provider (Generic) and an email service.

## Input

> **User:** "Put an ACL on the payment provider. Every external system gets one, right?"

## Working it

- **Question one, who has to cooperate:** the provider is a vendor with thousands of customers; it won't accommodate Rinkside. Customer–supplier group, with the power on the vendor's side. Customer/Supplier is out: the vendor doesn't commit to Rinkside's needs, and paying it doesn't change that.
- **Question two, is its model good enough?** The collision check on its terms (Payment, Refund, Payout): none means something different in Bookings, none imports a concept Bookings lacks, none breaks a Bookings rule. Payments aren't Core here. So **Conformist** is the cheap, legitimate choice (Evans).
- **Rejected: Anticorruption Layer.** There's nothing to translate; a layer would rename fields one-to-one and protect nothing.
- **Contract:** none from the vendor; note its API version and release pace so drift is planned for.

## Output — the reply, and the Relationships rows in `design/context-map.md`

> I'd use Conformist, not a translation layer. A translation layer earns its cost when the receiving side is Core, when the outside model is messy, or when it changes often. None of that applies: the provider's model is clean, payments aren't where Rinkside competes, and a translator would just copy the same fields. Paying them doesn't make them a supplier who adapts to us either. So we take their model as it is, and track their API version.

```markdown
| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| Payment Provider | Bookings | Conformist | The vendor's model passes the collision check and payments aren't Core; an Anticorruption Layer was rejected because it would copy fields one-to-one; Customer/Supplier was rejected because the vendor makes no commitment to us | None; note the provider's API version and release pace. Loose: Bookings reads only the payment status and amount with a tolerant reader |
| Bookings | Email Service | Conformist | Bookings sends in the service's format; nothing in the model depends on it. A translation layer was rejected: no meaning differs | None |
```

## Why this is right

- The three questions were asked in order; "external means translate" was replaced by the trade-off.
- The rejected alternatives are in the reason, so a reviewer can see what was weighed.
- The contract matches the pattern: a Conformist owes nothing but watching the upstream's version.
