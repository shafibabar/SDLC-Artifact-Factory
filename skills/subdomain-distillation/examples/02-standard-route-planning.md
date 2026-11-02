# Example 2 — Standard: "the hardest code is Core" corrected, and a simple feature that isn't Core

Self-contained. **Waymark** is a route-planning SaaS for regional courier firms, at the **standard** profile. Event Storming Big Picture is done.

## Input

> **User:** "Here's my take. Address import is Core: it's the hardest thing we've built, with messy spreadsheets and bad postcodes. The 'ETA text to customer' feature is Core too, because customers love it. Billing we'll get an agency to build, so that's Generic. Route optimisation is obviously Core."

## Working it

- **Address import: hard, but not Core.** Courier firms don't choose Waymark for its spreadsheet parsing; they choose it for routes. The difficulty is technical, and geocoding and address-cleaning services already exist. **Generic**: adopt a geocoding service and keep a thin import layer.
- **ETA texts: popular, but simple.** It sends a message with a time computed elsewhere. A competitor could copy it in a sprint, so it gives no lasting advantage. The advantage is the *accuracy* of the ETA, which comes from re-planning, so it belongs to route optimisation. The texting itself is **Generic** (a messaging service).
- **Billing: outsourced doesn't mean Generic.** Courier firms are billed per drop with their own surcharges (rural, two-person lifts, timed slots). No billing product handles that out of the box, and the rules are simple. That makes it **Supporting**, and outsourcing the build is a fine choice for Supporting. Card collection inside it is Generic (a payment provider).
- **Route optimisation: Core**, and the split matters. *Re-planning the day when jobs change, within drivers' hours and van capacity* is the Core. *Map display* is Generic.
- **Driver hours** are a legal constraint: the rules are complex but defined by regulation, and the same for everyone. That makes it **Supporting**, built with care, revisited if a compliance product appears.
- **Security axis:** driver payments (financial data) and the customer contact details used for ETA texts (personal data).

## Output — the reply

> Two labels change, and one moves.
> - **Address import is Generic, not Core.** It's the hardest code, but firms don't pick Waymark for it, and geocoding services exist. Adopt one and keep the import layer thin; the effort goes to routing.
> - **ETA texts aren't Core.** Customers love the accuracy, and that comes from re-planning, which is Core. Sending the text is a messaging service.
> - **Billing is Supporting, not Generic.** Your surcharge rules are too specific to buy and simple enough to hand to an agency. Outsourcing the build is fine for Supporting; Generic means buying something that already exists.
> - **Route optimisation is Core.** It gets the Domain Model, the deepest Event Storming and the most review.
>
> Each label has a date and a revisit trigger. If a courier-specific billing product appears, billing becomes Generic.

**`artifacts/waymark/design/subdomain-classification.md`** (extract):

```markdown
| Subdomain | Type | Advantage? | Complex? | Solved elsewhere? | Sourcing | Modelling | Security-sensitive slice | Revisit when |
|---|---|---|---|---|---|---|---|---|---|
| Day re-planning | Core | Yes: firms switch for it | Yes | No | In-house | Domain Model | Checklist run: none | A competitor matches re-plan speed |
| Driver hours | Supporting | No | Yes (regulation) | No | Careful in-house build | Domain Model (rules are complex, though not Core) | None | A compliance product with an API appears |
| Per-drop billing | Supporting | No | No | No | Outsource build | Transaction Script | Payment amounts per firm | A courier billing product appears |
| Card collection | Generic | No | Solved | Yes: payment provider | Buy | Thin integration | Handled by the provider | — |
| Address import | Generic | No | Technically hard, rules simple | Yes: geocoding services | Adopt + thin layer | Thin integration | None | — |
| ETA messages | Generic | No | No | Yes: messaging service | Buy | Thin integration | Customer phone numbers | — |
| Map display | Generic | No | No | Yes: map component | Adopt | Thin integration | None | — |

## Domain Vision Statement

The Core is re-planning a courier's day in minutes as jobs are added, cancelled or delayed, while keeping every driver within legal hours and every van within capacity. The model treats a route as a living plan revised many times a day, not a sequence computed once at dawn. Nothing off the shelf does this for small regional fleets at their price point.

## Highlighted Core

Event Storming area "Re-plan": `JobAdded`, `JobCancelled`, `DelayReported`, `RouteReplanned`; terms Route Plan, Stop, Capacity Window.
```

## Why this is right

- Difficulty and popularity were tested against advantage; neither decided the label.
- Outsourcing was separated from buying: billing is Supporting, card collection Generic.
- The vision statement is about the model (re-planning), not the market.
