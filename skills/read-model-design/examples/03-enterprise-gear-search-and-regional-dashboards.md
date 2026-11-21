# Example 3 — Enterprise: A Search View Across Three Services, Regional Dashboards

Self-contained. **Lumen Rentals** is a multi-tenant SaaS for camera and lighting rental houses: about 300 tenants (each a rental house), in an EU region and a US region; tenant data stays in its home region (data-residency commitment in the tenancy design). **Enterprise** profile. Services: **Catalogue** (items for hire), **Reservations** (bookings and returns), **Workshop** (repairs). This example is Catalogue's `read-models.md`.

The CQRS decisions record gives Catalogue two projected views:
- **GearSearch**, a cross-service CQRS view owned by Catalogue: customers search a house's gear by text, category and dates free. API Composition was rejected on evidence: a date-range search over 40,000 items per large house fanned out to Reservations and Workshop for every result page (p95 2.8 s against an NFR of 400 ms). Staleness accepted: 10 seconds.
- **HouseDashboard**, per region: utilisation, items out, overdue returns, items in repair, for each house's managers. Staleness accepted: 1 minute.

Catalogue is not event-sourced.

## Input

> **User:** "For GearSearch: when a booking comes in, check the search index says the item is free before confirming. Also we renamed `ItemListed` to `ItemPublished` last spring, so the projector can just ignore `ItemListed`. And to rebuild the index, delete it on Sunday night and re-index — nobody books at 3 a.m."

## Working it

- **Shape:** GearSearch answers one question ("what can I hire, matching this text, free on these dates?"), so it holds what the results page shows and filters on: title, category, day rate, the house's own branch, thumbnail, and the dates each item is unavailable. Not the Item Aggregate's maintenance history or purchase cost.
- **Three Aggregates, three services:** items from Catalogue's own events; unavailable dates from Reservations' published `BookingConfirmed` and `BookingReturned`; repair holds from Workshop's published `ItemSentForRepair` and `ItemRepaired`. Never their tables. Reservations calls a booking a *hire*; the projector translates to Catalogue's *unavailable period*.
- **"Check the index before confirming"** is declined: the index is 10 seconds behind, so two customers can both see a camera as free and both pass. The Booking Aggregate in Reservations checks availability against its own state; the search only shows *likely* availability, and a refused booking says so.
- **"Ignore `ItemListed`"** is declined: every item listed before last spring exists in the history only as `ItemListed`. A replay that ignores it builds an index missing half the catalogue. The projector reads `ItemListed` through the upcaster `event-schema-design` registered (D047-1: the breaking change was a new type), and the old-event fixtures run in the projector's tests.
- **"Delete the index Sunday night"** is declined: 3 a.m. in the EU is evening in the US region's customers' day, and a re-index of 300 houses takes about 50 minutes. Build a new index beside the live one, catch it up, move the alias in one step, per region.
- **Ordering across streams:** a `BookingConfirmed` can arrive before the item's `ItemPublished` reaches the index (different services, different partitions). The projector holds the unavailable period against the item's ID; the item appears in results only once published.
- **Read-your-writes:** a house's staff publishing a new item expect to find it. `PublishItem` returns the item's version; the staff screen shows the item as *going live* until GearSearch has applied it.
- **Monotonic reads:** HouseDashboard is served from read replicas in each region; the client ignores a response whose *as of* is older than one it has shown.

## Output: `design/catalogue/read-models.md` (excerpt)

```markdown
---
name: read-model-design
product: lumen-rentals
bounded-context: Catalogue
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-05-18
summary: Catalogue projects GearSearch from three services' events (10 s) and a per-region HouseDashboard (1 min); both rebuild into a copy from the event archive.
profile: enterprise
traces-to: [design/architecture/cqrs-decisions.md, design/catalogue/aggregates.md, design/catalogue/domain-event-catalog.md, design/reservations/domain-event-catalog.md, design/workshop/domain-event-catalog.md, design/architecture/multi-tenancy-design.md, ideate/nfr-specification.md]
---

# Read Models: Catalogue

**Read side (from `cqrs-decisions.md`):** projections for GearSearch (cross-service, composition too slow: p95 2.8 s vs 400 ms) and HouseDashboard; item admin screens use a Simple Read Model

## Read Models

| Read Model | Answers | Rung | Staleness accepted |
|---|---|---|---|
| ItemAdminList | a house's staff: our items, with status, for editing | simple read model | immediate |
| GearSearch | a customer: what can I hire, matching this text, free on these dates | projection | 10 seconds |
| HouseDashboard | a house's managers: utilisation, items out, overdue, in repair | projection | 1 minute |

## Read Model: ItemAdminList

| Field | Value |
|---|---|
| **Answers** | a house's staff: every item, with its status, to find and edit |
| **Rung** | simple read model |
| **Built from** | item table joined to category, through a query type; keyset paging by title |
| **Filters and order** | category, status, text on title; ordered by title |
| **Tenant scope** | tenant on every row (row-level security); every query filters on the house |

### Fields

| Field | Meaning | Source |
|---|---|---|
| title | the item's name | item.title |
| category | its category | category.name |
| status | draft, published or withdrawn | item.status |

## Read Model: GearSearch

| Field | Value |
|---|---|
| **Answers** | a customer on a house's hire site: items matching text and category, free on the chosen dates |
| **Rung** | projection |
| **Mechanic** | from published events — the three services' outboxes publish them; the data spans services |
| **Store** | a search index per region, one document per item; no cache |
| **Keyed on** | tenant and item |
| **Staleness accepted** | 10 seconds in normal running; during a rebuild the live index keeps serving |
| **Freshness shown** | the item version applied per document; results never claim certainty ("likely free") |
| **Read-your-writes** | PublishItem returns the version; the staff screen shows "going live" until the document reaches it |
| **Idempotency** | apply only if newer by item version for item events; processed-event record for booking and repair events (they add and remove periods) |
| **Lag alert** | 5 seconds behind, per region, to the on-call platform engineer |
| **Rebuild source** | the event archive in each region: every published event of Catalogue, Reservations and Workshop, retained indefinitely; broker topics keep 14 days and are not used for rebuilds |
| **Rebuild** | build a new index beside the live one from the first archived event, catch up, move the alias in one step, drop the old index after a day; per region; never deleted and re-indexed live |
| **Old event types** | ItemListed → read through the upcaster to ItemPublished; old-event fixtures in the projector's tests |
| **Tenant scope** | tenant on every document and in every query; EU tenants' documents only in the EU index |

### Fields

| Field | Meaning | Source | Copied from |
|---|---|---|---|
| title | what the customer searches for | ItemPublished.title | — |
| category | for filtering | ItemPublished.category | — |
| dayRate | the price shown | ItemPublished.dayRate | — |
| unavailablePeriods | dates the item can't be hired | BookingConfirmed / BookingReturned periods | Reservations (its change events: BookingConfirmed, BookingReturned) |
| inRepair | held by the workshop | ItemSentForRepair / ItemRepaired | Workshop (its change events: ItemSentForRepair, ItemRepaired) |

### Events

| Event | Effect on the view |
|---|---|
| ItemPublished | creates or updates the item's document; it becomes searchable |
| ItemListed | the same as ItemPublished, through the upcaster (history before last spring) |
| ItemWithdrawn | removes the item's document |
| BookingConfirmed | adds the booking's period to the item's unavailable periods (held against the ID if the item isn't indexed yet) |
| BookingReturned | ends the period on the return date |
| ItemSentForRepair | marks the item in repair |
| ItemRepaired | clears the repair mark |

## Read Model: HouseDashboard

| Field | Value |
|---|---|
| **Answers** | a house's managers: utilisation this month, items out now, overdue returns, items in repair |
| **Rung** | projection |
| **Mechanic** | from published events — the same three services' events |
| **Store** | Catalogue's database in each region, one row per house; read replicas serve it |
| **Keyed on** | tenant |
| **Staleness accepted** | 1 minute in normal running |
| **Freshness shown** | an *as of* time on the dashboard; the client ignores a response older than one it has shown (monotonic reads across replicas) |
| **Read-your-writes** | not needed: managers act on bookings in Reservations, which shows its own state; the dashboard is a summary |
| **Idempotency** | processed-event record for every event (counts are running totals) |
| **Lag alert** | 30 seconds behind, per region |
| **Rebuild source** | the regional event archive, retained indefinitely |
| **Rebuild** | build a copy table beside the live one, catch up, rename in one transaction, per region |
| **Old event types** | ItemListed → read through the upcaster |
| **Tenant scope** | one row per house; row-level security; each region holds only its tenants |

### Fields

| Field | Meaning | Source | Copied from |
|---|---|---|---|
| itemsOut | items on hire now | BookingConfirmed less BookingReturned | — |
| overdueReturns | items past their return date | BookingConfirmed.returnDue, BookingReturned | — |
| inRepair | items at the workshop | ItemSentForRepair less ItemRepaired | — |
| asOf | when the dashboard last changed | time of the last event applied | — |

### Events

| Event | Effect on the view |
|---|---|
| BookingConfirmed | adds to items out, records the return due |
| BookingReturned | removes from items out and from overdue |
| ItemSentForRepair | adds to in repair |
| ItemRepaired | removes from in repair |
| ItemPublished | adds to the house's item count (utilisation base) |
| ItemListed | the same, through the upcaster |

## Open questions

- Should overdue be computed at a daily cut-off per house's time zone, or on the hour? (product owner)
```

## Why this is right

- Each view answers one question; GearSearch combines three Aggregates across three services through their published events, translated into Catalogue's language.
- No booking rule reads the index; availability is checked by the Booking Aggregate.
- The replaced event type is replayed through the upcaster, so a rebuild keeps the whole catalogue.
- Rebuilds build beside the live view and switch in one step, per region, from a source with the full history.
- Tenant data stays in its home region; replicas don't show a reader older data after newer.
- `validate-read-models.sh` exits clean on the excerpt.
