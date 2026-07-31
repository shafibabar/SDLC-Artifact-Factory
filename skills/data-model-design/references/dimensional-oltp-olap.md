# Dimensional Modeling for Analytical Marts (Kimball)

Reference for the **analytical (OLAP)** model shape: the Kimball star schema, the four-step
design process, fact-table types and additivity, dimension design, **Slowly Changing
Dimensions**, conformed dimensions and the bus matrix, snowflaking, and — most important for
this repo — *when* a service actually needs a dimensional mart versus a plain Read Model.

This shape is for the **presentation/BI layer only** — Read Models that back
`dashboard-specification` and `reporting-spec`. It must **never** be applied to operational
Aggregate state (that stays normalized — see `normalization-oltp.md`). In this repo a "mart"
is still a plain PostgreSQL table: no separate warehouse, no columnar store, no ETL back room.

---

## 1. When Do You Actually Need a Mart? (the decision)

Most Read Models are *not* dimensional. Reach for a star schema only when the analytics
requirement genuinely calls for it:

| Signal | → Build |
|---|---|
| A single current value looked up by key ("this asset's current classification") | Plain Read Model — no dimensional modeling |
| A live count/aggregate recomputed on read, small enough to compute each time | Plain Read Model with an aggregation query |
| A metric that must be **comparable across time** ("sensitivity distribution today vs. 30 days ago") | **Periodic snapshot** fact table |
| Multiple dashboards/reports sharing the same descriptive context (Tenant, Sensitivity, Person) that must agree | Dimensional marts with **conformed dimensions** |
| An audit question of the form "what was this attribute's value **as of** a past date" | Dimension with **SCD Type 2** history |
| An accumulating process with milestones ("remediation workflow from opened → closed") | **Accumulating snapshot** fact table |

If none of these apply, do not dimensionalize — a normalized Read Model is simpler, and
simpler wins (frugality). A mart earns its complexity only when history, cross-report
consistency, or "as-of" auditability is a real requirement.

---

## 2. The Star Schema and the Four-Step Process

A star schema is a narrow **fact table** (numeric measurements of a business event, plus
foreign keys) surrounded by wide, denormalized **dimension tables** (the descriptive
who/what/when/where/why/how context). Chosen over 3NF for the presentation layer because it
optimizes business-user comprehensibility and query speed, accepting controlled redundancy.

Design every star in this fixed order — skipping or reordering is the most-repeated failure:

1. **Select the business process** being measured (e.g. "sensitivity scanning of assets").
2. **Declare the grain** — one literal sentence for what one fact row represents.
3. **Identify the dimensions** — the descriptive context consistent with that grain.
4. **Identify the facts** — the numeric measures consistent with that grain.

### Grain declaration is step one of modeling

The **grain** is a single precise sentence: *"one row per data asset per daily sensitivity
scan"* — not "asset sensitivity data". Every dimension and every fact must fit that one
sentence; anything that does not fit is at the wrong grain and belongs elsewhere. Declaring
the grain *before* choosing dimensions and facts is what makes the schema governable.

### Worked mini-star: estate sensitivity snapshot

```
Grain: "one row per tenant per sensitivity_level per calendar day"

fact_sensitivity_snapshot
  date_key         FK → dim_date
  tenant_key       FK → dim_tenant
  sensitivity_key  FK → dim_sensitivity
  asset_count      -- measure (semi-additive: see §4)

dim_date(date_key, calendar_date, day_of_week, month, quarter, year, is_month_end)
dim_tenant(tenant_key, tenant_id, tenant_name, plan_tier, region)
dim_sensitivity(sensitivity_key, level_name, level_rank, requires_dlp)
```

---

## 3. Fact-Table Types

Three canonical shapes, each answering a different question:

| Type | One row = | Repo example |
|---|---|---|
| **Transaction fact** | one discrete event | one row per compliance gap opened |
| **Periodic snapshot** | one entity per fixed interval | sensitivity distribution captured once per day |
| **Accumulating snapshot** | one process instance, columns updated in place as milestones pass | one row per remediation workflow, a timestamp column per stage |

The `reporting-spec` "point-in-time snapshot" report is a **periodic snapshot** by another
name; the `dashboard-specification` live view that also shows a "30-days-prior" figure needs a
**periodic snapshot** table underneath it, because you cannot recompute a past day's live
count after the fact.

---

## 4. Additive, Semi-Additive, Non-Additive Facts

Every fact column's aggregation behavior must be classified explicitly — it decides whether
"today's value" and "last month's value" can be safely summed:

| Class | Sums across… | Example | Trap |
|---|---|---|---|
| **Additive** | every dimension, including time | count of gaps opened | none |
| **Semi-additive** | some dimensions but **not time** | `asset_count` in a daily snapshot; any balance/point-in-time count | summing today's + yesterday's asset counts **double-counts** the same assets |
| **Non-additive** | no dimension | a ratio or percentage (e.g. % Restricted) | can never be summed; recompute from additive components (numerator, denominator) |

State the summation rule for each fact, especially across time. A report that sums a
semi-additive balance across periods produces a meaningless total — an additivity check
prevents it.

---

## 5. Dimension Design

- **Surrogate keys.** Each dimension's primary key is a meaningless, sequentially assigned
  integer — **not** the source's natural/business key. Surrogate keys are what make SCD Type 2
  possible (the same real-world entity gets multiple dimension rows) and insulate the star
  from source-system key reuse or change. Keep the natural key as an ordinary attribute.
- **Wide and flat.** Dimensions are denormalized on purpose — the descriptive attributes live
  directly on the dimension row, not in sub-tables.
- **Degenerate dimension.** An operational identifier (an order/scan number) kept as a bare
  column on the fact table with no dimension table of its own.
- **Junk dimension.** Several low-cardinality flags bundled into one small dimension to keep
  the fact table narrow.
- **Role-playing dimension.** One physical dimension (classically `dim_date`) used several
  times in one fact under different aliases (opened_date, closed_date) — via views/aliases,
  not by duplicating the table.
- **Factless fact table.** Records that a combination of dimension values co-occurred with no
  numeric measure — e.g. "this control was tested and passed."

---

## 6. Slowly Changing Dimensions (SCD)

How a dimension attribute that changes over time is handled. **The Type distinction is the
core decision** — do not let "overwrite" be the silent default where a historical "as of"
answer is actually required.

| SCD Type | Mechanism | History kept | Use when |
|---|---|---|---|
| **Type 0** | attribute never changes / changes ignored | n/a | a truly immutable attribute (original source kind) |
| **Type 1** | **overwrite in place** — the old value is lost | **none** | corrections; nobody ever asks "what was it before" |
| **Type 2** | **insert a new dimension row** with a new surrogate key + effective/expiration dates (or a current-row flag); facts join to the row that was true when the fact occurred | **full** | you must answer "what was this Person's classification **as of** last quarter" |
| **Type 3** | **add a column** holding the previous value | one step only | a single "previous vs. current" comparison suffices |

The load-bearing distinction: **Type 1 overwrites and destroys history; Type 2 versions and
preserves it.** In this product, compliance evidence that needs the sensitivity state "as of"
an audit date is a Type 2 requirement; the golden-record survivorship in
`canonical-data-model` defaults to Type-1-style overwrite and should be reconsidered as Type 2
for any attribute an audit trail must reconstruct historically.

### Type 2 mechanics (worked)

```sql
CREATE TABLE dim_person (
    person_key    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- surrogate
    person_id     UUID NOT NULL,          -- natural key (repeats across versions)
    tenant_id     UUID NOT NULL,
    display_name  TEXT NOT NULL,
    risk_tier     TEXT NOT NULL,          -- the SCD-tracked attribute
    valid_from    TIMESTAMPTZ NOT NULL,
    valid_to      TIMESTAMPTZ,            -- NULL = current row
    is_current    BOOLEAN NOT NULL DEFAULT true
);
-- On change: close the current row (set valid_to, is_current=false),
-- then insert a NEW row with a fresh person_key. A fact recorded last quarter
-- joins to whichever version had valid_from <= fact_date < valid_to.
```

---

## 7. Conformed Dimensions and the Bus Matrix

A **conformed dimension** is built once with a consistent structure, meaning, and value set,
then shared across every fact table/mart that needs it — this is what lets two reports be
compared ("drilled across") without disagreeing about what "Tenant" or "Sensitivity Level"
means. The **bus matrix** is the planning artifact: business processes as rows, conformed
dimensions as columns, marked cells showing which process uses which dimension.

| Business process ↓ / Dimension → | Date | Tenant | Sensitivity | Person | DataSource |
|---|---|---|---|---|---|
| Sensitivity scanning | ✓ | ✓ | ✓ | | ✓ |
| Compliance gap tracking | ✓ | ✓ | ✓ | ✓ | |
| Remediation workflow | ✓ | ✓ | | ✓ | |

Sketch the bus matrix once more than one dashboard/report shares dimensions — it verifies
`Tenant`, `Sensitivity Level`, `Person` are used identically everywhere, letting marts be
built incrementally without creating incompatible stovepipes.

---

## 8. Snowflaking Is Generally Discouraged

Keep dimensions flat and denormalized (a *star*), even at the cost of redundancy. Normalizing
a dimension into sub-tables (a *snowflake*) trades simpler joins and query speed for a
tidiness the BI layer does not need. Snowflake only when a dimension is genuinely huge and a
sub-dimension is shared and volatile — the exception, not the rule.

> Do **not** force any of these concepts onto the Apache AGE graph model. The graph is for
> relationship traversal, not aggregation; dimensional concepts have nothing to say about it.

---

## Checklist

- [ ] A mart was justified against §1 — not built reflexively; a plain Read Model was ruled out.
- [ ] Grain declared as one literal sentence before dimensions or facts were chosen.
- [ ] Fact-table type named (transaction / periodic snapshot / accumulating snapshot).
- [ ] Every fact classified additive / semi-additive / non-additive with its summation rule.
- [ ] Dimensions use surrogate keys; natural keys kept as attributes.
- [ ] Every changeable dimension attribute has a documented SCD type (Type 2 where "as-of" is required).
- [ ] Shared dimensions are conformed; a bus matrix exists once >1 mart shares them.
