# Example 2 — Standard: Simple Queries Beside One Projected Summary

Self-contained. **Mealbridge** takes school-meal pre-orders for 30 primary schools run by one catering company: parents order by 09:30 for that day, kitchens cook from a prep sheet. **Standard** profile. This example is the **Ordering** context. Its CQRS decisions record (`design/architecture/cqrs-decisions.md`) puts Ordering on **projections** for one view, on a load trigger: between 09:00 and 09:30 about 6,000 orders arrive while 30 kitchen screens refresh the day's counts every 10 seconds, and summing the day's orders per refresh slowed ordering in the load test (NFR-04). Staleness accepted: 30 seconds. Everything else in Ordering is a Simple Read Model.

## Input

> **User:** "Make one `MealOrderView` that mirrors the MealOrder Aggregate so the parent app, the school office and the kitchen all reuse it. Also, last Tuesday the prep sheet showed 14 extra fish pies at Hillcrest — just correct the count in the table."

## Working it

- **Queries and who asks** (from the user stories and the Process Modelling read models): a parent's orders for the week; this week's menu for a school; the school office's list of pupils with no order today; the kitchen's prep sheet (dish counts per school for today).
- **"One `MealOrderView` for everyone"** is declined. The MealOrder Aggregate is drawn around one rule (an order can change until the 09:30 cut-off). The parent wants dish names and prices for their children; the office wants pupils *without* an order, which the Aggregate can't even express; the kitchen wants counts, not orders. One Aggregate-shaped view makes each caller fetch and reshape. Four Read Models, one per question.
- **Rungs:** the parent, menu and office questions are queries over the write tables (joins allowed, immediate). Only the prep sheet is projected, as the decision says.
- **Copied values:** the prep sheet shows dish names; it copies them and handles `DishRenamed` from the Menu Aggregate.
- **The 14 extra pies:** the order relay redelivered a batch after a restart, and the projector added each `MealOrdered` to the running count again. "Apply only if newer" doesn't protect a running total (the row is per school and day, not per order). Correcting the count by hand is declined: the next rebuild replays the same duplicates into the same bug. Instead: the projector records processed event IDs in the same transaction as each count change, then the view is rebuilt into a copy from the order events and switched in.
- **Read-your-writes:** parents never read the prep sheet; they see their own order on their rung-1 list, immediately. The kitchen writes nothing that feeds it. So the document says why no pending state is needed.
- **Rebuild source:** the broker keeps 7 days; the outbox archive keeps every order event for the school year, which is all a prep sheet ever needs.

## Output: `design/ordering/read-models.md` (excerpt)

```markdown
---
name: read-model-design
product: mealbridge
bounded-context: Ordering
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-03-10
summary: Ordering answers parents, offices and kitchens; only the kitchen prep sheet is projected (30 s behind), rebuilt from the outbox archive.
profile: standard
traces-to: [design/architecture/cqrs-decisions.md, design/ordering/aggregates.md, design/ordering/domain-event-catalog.md, design/menu/domain-event-catalog.md, ideate/nfr-specification.md]
---

# Read Models: Ordering

**Read side (from `cqrs-decisions.md`):** projections for the prep sheet only — 09:00–09:30 refresh load (NFR-04)

## Read Models

| Read Model | Answers | Rung | Staleness accepted |
|---|---|---|---|
| ChildrensOrders | a parent: what each of my children is eating this week | simple read model | immediate |
| SchoolMenuWeek | a parent or office: what's on at this school this week | simple read model | immediate |
| PupilsWithoutOrder | a school office: who has no meal ordered today | simple read model | immediate |
| KitchenPrepSheet | a kitchen: how many of each dish to cook today | projection | 30 seconds |

## Read Model: ChildrensOrders

| Field | Value |
|---|---|
| **Answers** | a parent: what each of my children is eating this week, and what it costs |
| **Rung** | simple read model |
| **Built from** | meal orders for the parent's children joined to the school's menu dishes, through a query type |
| **Filters and order** | parent, week; ordered by child then day |
| **Tenant scope** | single catering company; filtered by the parent's children |

### Fields

| Field | Meaning | Source |
|---|---|---|
| childName | the child | pupil_roll.display_name |
| serviceDate | the day | meal_order.service_date |
| dishName | what they are having | menu_dish.name |
| price | what it costs | menu_dish.price |
| changeableUntil | the cut-off for changing it | meal_order.service_date at 09:30 |

## Read Model: SchoolMenuWeek

| Field | Value |
|---|---|
| **Answers** | a parent or school office: the dishes on at this school each day this week |
| **Rung** | simple read model |
| **Built from** | menu and menu-dish tables for the school and week, through a query type |
| **Filters and order** | school, week; ordered by day |
| **Tenant scope** | single catering company; filtered by school |

### Fields

| Field | Meaning | Source |
|---|---|---|
| serviceDate | the day | menu.service_date |
| dishName | the dish | menu_dish.name |
| price | its price | menu_dish.price |

## Read Model: PupilsWithoutOrder

| Field | Value |
|---|---|
| **Answers** | the school office, at 09:35: which pupils have no meal ordered for today |
| **Rung** | simple read model |
| **Built from** | pupil roll table left-joined to today's meal orders for the school, through a query type |
| **Filters and order** | school, date; ordered by class then surname |
| **Tenant scope** | single catering company; filtered by school |

### Fields

| Field | Meaning | Source |
|---|---|---|
| pupilName | the pupil, as the office knows them | pupil_roll.display_name |
| className | their class | pupil_roll.class_name |
| freeMealEligible | whether a meal is provided anyway | pupil_roll.free_meal_eligible |

## Read Model: KitchenPrepSheet

| Field | Value |
|---|---|
| **Answers** | each school kitchen, refreshed every 10 seconds before service: how many of each dish to cook today |
| **Rung** | projection |
| **Mechanic** | from published events — the outbox already publishes order events; the write path must not pay for 30 kitchens' refreshes |
| **Store** | Ordering's own database, one row per school, day and dish; no cache |
| **Keyed on** | school, service date, dish |
| **Staleness accepted** | 30 seconds in normal running; during a rebuild the old copy keeps serving |
| **Freshness shown** | an *as of* time on the sheet; the kitchen sees "as of 09:31:40" |
| **Read-your-writes** | not needed: parents never read this view (they see their order on ChildrensOrders, immediately) and kitchens write nothing that feeds it |
| **Idempotency** | processed-event record for every event: counts are running totals, so "apply only if newer" per row would not catch a duplicate order |
| **Lag alert** | 15 seconds behind, to the catering operations channel |
| **Rebuild source** | outbox archive, every order event for the school year; the broker's 7-day retention is not enough for a term-long rebuild |
| **Rebuild** | build into a copy beside the live sheet from the first event of the term, catch up, switch in one step, drop the old copy; never patched by hand |
| **Old event types** | none yet |
| **Tenant scope** | single catering company; each kitchen's query filters on its school |

### Fields

| Field | Meaning | Source | Copied from |
|---|---|---|---|
| school | the school the kitchen serves | MealOrdered.schoolId | — |
| serviceDate | the day | MealOrdered.serviceDate | — |
| dishName | what the kitchen calls the dish | MenuPublished.dishName | Menu (its change event: DishRenamed) |
| portions | how many to cook | count of MealOrdered less MealOrderCancelled, moved by MealOrderChanged | — |
| asOf | when the sheet last changed | time of the last event applied | — |

### Events

| Event | Effect on the view |
|---|---|
| MealOrdered | adds one portion to the dish's row for the school and day (creates the row if absent) |
| MealOrderChanged | moves one portion from the old dish to the new dish |
| MealOrderCancelled | removes one portion from the dish's row |
| MenuPublished | creates rows at zero for each dish on the school's menu that day, with the dish name |
| DishRenamed | re-projects the dish name on every row holding it |

## Open questions

- Should portions ordered after the cut-off by the office (late changes) show separately on the sheet? (product owner)
```

## Why this is right

- Four questions, four Read Models; the Aggregate-shaped view was declined with its reason.
- Only the view the CQRS decision projected is projected; the office's "who has no order" is a plain join.
- The drift was fixed in the projector and rebuilt into a copy, not corrected by hand; the guard matches the shape of the row (a running total needs a processed-event record).
- The rebuild source covers the history the view needs, and the document says why no read-your-writes is needed.
- `validate-read-models.sh` exits clean on the excerpt.
