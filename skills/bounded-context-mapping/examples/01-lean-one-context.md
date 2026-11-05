# Example 1 — Lean: one context and two external systems (simplest case)

Self-contained. **Purlwise** books places on knitting workshops for one studio, Wren Yarns, at the **lean** profile. The Big Picture (agent-run), the subdomain classification (Core: workshop places and waitlists; Generic: card payments, email) and the language document for "Workshops" exist.

## Input

> **User:** "Do the Context Map. I suppose we need several contexts: Bookings, Payments, Emails, Customers?"

## Working it

- **Does any word change meaning?** "Booking", "place", "waitlist" and "customer" mean the same thing everywhere in this product. The Big Picture has one pivotal event (`WorkshopPublished`) and no change of actor that shifts the words. No fracture, so one context.
- **Payments and emails** are Generic and bought: external systems, not contexts the product models.
- **Something exists today:** the studio takes bookings in a shared spreadsheet and by email. Lean or not, that gets a small current map, drawn as one region, so the move off it is visible.
- **"Customers" as its own context?** Nothing else writes customer records, and the word means the same thing; it stays inside Workshops.
- **Later:** if Wren Yarns starts selling yarn online, "order" would mean something new. That is recorded as a candidate split with its trigger, not drawn now.

## Output — the reply, and `artifacts/purlwise/design/context-map.md`

> One context is enough, and I've also drawn today's setup (the spreadsheet and the email inbox) so we can see what Purlwise replaces. No word in Purlwise means different things in different places, which is what a second context needs. Payments and emails are services you buy, so they appear on the map as outside systems. If you start selling yarn online, "order" would mean something new, and that's when a second context would earn its place. I've noted that as the trigger.

````markdown
---
name: context-map
product: purlwise
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-05-20
summary: Purlwise has one context, Workshops, with card payments and email as external systems; a Shop context is a candidate if yarn sales start.
profile: lean
mode: agent-run
traces-to: [design/subdomain-classification.md, design/event-storming/big-picture.md, design/workshops/ubiquitous-language.md]
---

# Context Map: Purlwise

## Contexts

### Workshops

| Field | Value |
|---|---|
| **Responsibility** | Publishes workshops and fills their places and waitlists |
| **Subdomain(s)** | Workshop places and waitlists (Core) |
| **Boundary evidence** | No term changes meaning anywhere in the product (language document; one pivotal event, WorkshopPublished, with no change of words around it) |
| **Language** | `design/workshops/ubiquitous-language.md` |
| **Owns (Aggregates)** | Workshop, Booking |
| **Publishes** | WorkshopPublished, PlaceBooked, PlaceReleased |
| **Consumes** | PaymentTaken (from the payment provider) |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | Shop, if Wren Yarns sells yarn online ("order" would mean a parcel, not a place) |

## External Systems

| System | Used by | What it provides |
|---|---|---|
| Payment Provider | Workshops | Card payments and refunds |
| Email Service | Workshops | Confirmation and waitlist emails |

## Current Map

```
┌─────────────────────────────────────┐        ┌────────────────────┐
│ Booking spreadsheet + email inbox   │◀─D──U──│ Payment Provider   │
│ [today, no single model]            │        │ [external]         │
└─────────────────────────────────────┘        └────────────────────┘
```

## Target Map

```
┌────────────────────┐            ┌──────────────────────┐
│ Payment Provider   │──U──────D─▶│ Workshops     (Core) │
│ [external]         │            │ owns: Workshop,      │
└────────────────────┘            │       Booking        │
                                  └─────────┬────────────┘
                                            U
                                            │
                                            D
                                            ▼
                                  ┌──────────────────────┐
                                  │ Email Service        │
                                  │ [external]           │
                                  └──────────────────────┘
```

## Relationships

| Upstream | Downstream | Pattern | Reason |
|---|---|---|---|
| Payment Provider | Workshops | Conformist | The provider's payment model is good enough to adopt and Workshops isn't affected by its shape |
| Workshops | Email Service | Conformist | Workshops sends in the email service's format; nothing in the model depends on it |
````

## Why this is right

- One context, because no word changes meaning: a context is a language boundary, not one per feature.
- Bought Generic capabilities are external boxes, not modelled contexts. Today's spreadsheet gets a current map even at lean, because the move off it is real work.
- The likely future split is recorded with its trigger instead of being built now. The patterns came from `context-map-patterns`.
