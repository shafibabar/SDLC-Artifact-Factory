# Classification Techniques

The detail behind `SKILL.md` § 1–3 and § 6: the coarse-to-fine split, the three tests with the questions that probe them, sourcing by type, what the type means for modelling, and Evans's refactorings for a tangled Core. Grounded in Evans (*Domain-Driven Design*, Ch. 15), Vernon (*Implementing Domain-Driven Design*, Ch. 2) and Khononov (*Learning Domain-Driven Design*, Ch. 1, 10, 11), as summarised in `research/domain-driven-design/strategic-design-supplement.md`. Examples use several products on purpose.

## 1. The coarse-to-fine split

Start from capabilities, not from systems or teams. The Event Storming Big Picture gives them: pivotal events mark phase changes, swimlanes separate parallel flows, and each is a candidate capability.

| Level | Example (a route-planning SaaS for regional couriers) | Classifiable? |
|---|---|---|
| Department | Operations | No: mixed types |
| Capability | Route planning | Not yet: contains route optimisation and address import |
| Subdomain | Route optimisation | Yes: one type (Core) |
| Subdomain | Address import and cleaning | Yes: one type (Generic: geocoding services exist) |
| Use cases | "Re-optimise after a cancellation", "optimise for a van's capacity" | Same type as their parent: stop splitting |

Stop when the next split yields only use cases of the same type. Splitting further adds labels, not decisions.

## 2. The three tests, with probing questions

Ask all three of each subdomain; no single answer decides it.

**Competitive advantage**
- Would a customer choose us over a competitor because of how we do this?
- If we did it exactly as competitors do, would we lose deals?
- Does the strategy kernel or vision name it as the bet? (`strategy-kernel`, `vision-statement`)

**Complexity**
- Are there many rules, exceptions and interactions, or is it mostly storing and showing data?
- Does it need domain experts to get right, or only careful engineering?
- Note: technical difficulty (a hard parser, a fast sync) is not domain complexity. A capability can be technically hard and simple in business rules.

**Solved elsewhere**
- Is there a product, library, service or published model that does this the way any company would need it?
- Would we use it as is, or would we have to bend it so far that we are really building our own?

| Advantage | Complex | Solved elsewhere | Type |
|---|---|---|---|
| Yes | Yes | No | Core |
| No | Yes | Yes | Generic |
| No | No | No | Supporting |
| No | Yes | No | Supporting, built with care. Revisit: a product may appear, making it Generic |
| Yes | No | — | Not Core as stated: a simple capability is easy to copy (Khononov). The advantage usually lives in richer rules nearby; find and classify those. If none exist, it's Supporting, and the product's advantage lies outside software (service, brand, price) |

**How many Core subdomains?** Few. Most products have one or two (Khononov, Evans's advice to keep the Core small). Many Core labels mean the tests were answered with "it matters to us" rather than "customers choose us for it".

## 3. Sourcing follows the type

| Type | Usual sourcing | Notes |
|---|---|---|
| Core | In-house, the strongest people | Never outsourced: the advantage is the knowledge |
| Generic | Buy or adopt: a product, a library, an open-source component, a published model | Evans also lists outsourcing and a minimal in-house build. Bending a bought product far out of shape is a sign the subdomain was misclassified |
| Supporting | Build cheaply in-house, or outsource the build | Khononov pairs outsourcing with Supporting: specific enough that nothing can be bought, simple enough to hand to someone else |

"Would you outsource it?" doesn't separate the types, because outsourcing fits Supporting and is among Evans's Generic options. Ask the three tests; sourcing is the consequence.

## 4. What the type means for modelling

| Type | Business-logic pattern (chosen per Aggregate in `aggregate-design`) | Design attention |
|---|---|---|
| Core | Domain Model, or Event-Sourced Domain Model only when its own justifying need exists | Full Event Storming to Software Design level; careful language; most review |
| Supporting | Transaction Script or Active Record, usually | Enough to get the rules right; no more |
| Generic | Whatever the bought or adopted component brings; a thin integration behind a translation (an Anti-Corruption Layer when its model doesn't fit) | Integration and translation, not modelling |

Domain-Driven Design applies everywhere (CLAUDE.md): every subdomain gets its language and boundaries. What scales with the type is the tactical machinery, and that is decided per Aggregate, not per subdomain (Khononov). A Core subdomain often contains simple use cases that need no Aggregate.

## 5. Evans's refactorings for a tangled Core

For a system that already exists:

- **Segregated Core:** Core concepts are tangled with generic or supporting code in one model, so nobody can see where the Core is. Pull the Core parts into their own module, accepting some temporary duplication, so the Core becomes visible and bounded. Use when the classification shows a Core that can't currently be told apart in the code.
- **Abstract Core:** the Core is correctly identified but too large to reason about. Find the most fundamental concepts that run across its parts and pull them into a small abstract layer the specific parts depend on.
- **Cohesive Mechanism:** a complex, purely computational piece inside the Core (a scheduling algorithm, a pricing calculation engine) moves behind an interface, leaving the Core expressing *what* is decided while the mechanism computes *how*.

All three follow classification. They are what to do when the classification exposes a tangled or oversized Core.

## 6. Domain Vision Statement and Highlighted Core

**Domain Vision Statement** (Evans): about one page, written early and revised. It says what the Core Domain is and what value its model brings, in terms a domain expert would recognise. It is not the product vision (`vision-statement` covers market and customers); it is about the model.

> *Example (route planning):* "The Core is re-planning a day's routes in minutes when jobs are added, cancelled or delayed, while keeping drivers within their hours and vans within capacity. Our model treats a route as a living plan that is revised many times a day, not a fixed sequence computed once."

**Highlighted Core:** a short list of the Bounded Contexts, Aggregates and terms that carry the Core, so that anyone reading the design knows where the care goes.
