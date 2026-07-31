# Widget Metric Definitions

Reference material for `dashboard-specification`. How to define each widget's metric
precisely, and a worked widget set for this repo's data-estate/compliance product.
Grounded in Croll & Yoskovitz, *Lean Analytics*
(`research/data-and-analytics/lean-analytics-croll-yoskovitz.md`) for metric selection,
and in `read-model-design` / `data-pipeline-implementation` for sourcing.

Repo stack: Go + chi + pgx + PostgreSQL + Redpanda; per-tenant **physical** isolation
(each tenant has its own schema/database, so every query is tenant-scoped by
connection, not by a `WHERE tenant_id` filter — shown below for clarity but often
implicit in the physical model); OLAP/reporting runs on Postgres Read Models.

---

## Defining a metric precisely — the five things every definition states

A metric definition is complete when two engineers, implementing from it on two
different days, produce the identical number. That requires:

1. **Source Read Model + field(s).** The named pre-aggregated projection and the
   column(s) read. Never a raw domain table if a Read Model exists.
2. **Every filter.** Status, sensitivity, tenant scope, soft-delete
   (`deleted_at IS NULL`), and any domain filter. Omitting one silently changes the
   number.
3. **Grain.** The one row the metric counts or aggregates over — per DataAsset, per
   ComplianceGap, per tenant-day snapshot. Grain is the single most common defect: a
   count "per asset" and a count "per finding" answer different questions.
4. **Time semantics.** As-of-now (point-in-time), a fixed window, or a rolling window;
   if rolling, the width; if a snapshot, the snapshot cadence.
5. **Unit.** Count, rate, ratio, or percentage — and, per Lean Analytics, prefer a
   ratio/rate with an honest denominator over a raw count wherever the question allows.

```
Bad:  "Number of compliance gaps"
Good: "Count of rows in compliance_gap_summary where status = 'open',
       grain = one ComplianceGap, as-of-now (not time-windowed),
       grouped by framework_control. Unit: count."
```

---

## Actionable, not vanity — the Lean Analytics gate

Before a metric becomes a widget, gate it on Croll & Yoskovitz's four tests plus, for
retention-flavoured metrics, a cohort check:

| Test | Question | Fix if it fails |
|---|---|---|
| **Comparative** | Compared against a period, cohort, or target? | Add a target line or a prior-period series |
| **Understandable** | Can a non-analyst remember and argue about it? | Simplify the definition or rename |
| **Ratio / rate** | Is there an honest denominator? | Convert a raw count to a rate |
| **Changes behaviour** | Would a different value change what the viewer does? | If no — it is vanity; cut it |
| **Cohort-validated** (retention/stickiness only) | Does per-cohort behaviour, not a cumulative total, drive it? | Segment by start date; compare like-elapsed time |

The classic trap: **cumulative totals** ("total assets scanned," "total files
processed") trend up-and-to-the-right regardless of whether the product is improving,
because they never subtract. They pass four of the tests while still being an illusion.
The cohort comparison — group DataAssets by ingestion week, compare each cohort's
day-30 classification-review rate — is what exposes it.

---

## Worked widget set for this repo

### Widget 1 — DataAsset Classification Coverage

Answers: "What fraction of my estate has been classified?" (an actionable rate — a
falling coverage % means ingestion is outrunning classification, and the viewer acts by
scaling the classification stage).

```
Grain: one DataAsset
Unit: percentage (ratio — classified assets / total assets)
Source Read Model: asset_classification_summary (Bounded Context: Data Estate;
  populated by the Classification pipeline stage from DataAssetClassified /
  DataAssetIngested events)
Filters: deleted_at IS NULL; tenant scope (implicit — physical isolation)
Time semantics: as-of-now
Chart: single number (%), with a target line — see chart-selection-guide
```

```sql
-- asset_classification_summary is pre-aggregated; this is the widget read.
SELECT classified_assets,
       total_assets,
       CASE WHEN total_assets = 0 THEN NULL
            ELSE round(100.0 * classified_assets / total_assets, 0)
       END AS coverage_pct
  FROM asset_classification_summary
 WHERE tenant_id = $1;          -- implicit under physical isolation
-- Empty-state condition: total_assets = 0 (no assets ingested yet) —
-- distinct from coverage_pct = 0 (assets exist, none classified).
```

Why a rate, not a count: "12,904 assets classified" is a vanity metric — it only rises.
"77% coverage" falls when ingestion outpaces classification, which is exactly the
behaviour-changing signal.

### Widget 2 — Ingestion Throughput

Answers: "Is ingestion keeping up over the last 24h, and where did it dip?" (an
operational trend; the viewer acts by investigating a dip against the connector SLO).

```
Grain: one tenant-minute bucket (assets ingested per minute)
Unit: rate (assets / minute)
Source Read Model: ingestion_throughput_1m (Bounded Context: Ingestion;
  populated by a Redpanda consumer projecting DataAssetIngested events into
  1-minute buckets — NOT a live scan of the assets table)
Filters: connector_type (default: all); tenant scope
Time semantics: rolling 24h window
Chart: line; accent the segment below the SLO threshold
```

```sql
SELECT bucket_start,
       connector_type,
       assets_ingested
  FROM ingestion_throughput_1m
 WHERE tenant_id = $1
   AND bucket_start >= now() - interval '24 hours'
 ORDER BY bucket_start;
-- Aggregation lives in the projection, not the browser: the widget reads
-- ~1,440 pre-bucketed rows, never raw DataAssetIngested events.
```

### Widget 3 — Open Compliance-Gap Count by Framework Control

Answers: "Which framework controls have the most open gaps?" (a ranked comparison;
the viewer acts by escalating the top control).

```
Grain: one ComplianceGap
Unit: count, grouped by framework_control + severity
Source Read Model: compliance_gap_summary (Bounded Context: Compliance;
  populated by the Compliance Rule Engine stage from ComplianceGapOpened /
  ComplianceGapClosed / DataAssetReclassified events)
Filters: status = 'open'; tenant scope
Time semantics: as-of-now
Chart: horizontal bar, sorted by open_gap_count desc; accent the top bar
Drill-down: click a framework_control row -> individual ComplianceGap rows
  (data_asset_id, opened_at, lineage link) from compliance_gap_detail,
  filtered by the selected framework_control. Terminates at an auditable record.
```

```sql
SELECT framework_control,
       severity,
       count(*) AS open_gap_count
  FROM compliance_gap_summary
 WHERE tenant_id = $1
   AND status = 'open'
 GROUP BY framework_control, severity
 ORDER BY open_gap_count DESC,
          CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                        WHEN 'medium' THEN 3 ELSE 4 END;
-- Empty-state condition: zero rows where status = 'open' (good news),
-- distinct from "no scan has run" (compliance_gap_summary itself empty).
```

---

## Sourcing rules (why Read Models, not raw tables)

- **Aggregate in the Read Model, never in the browser.** If a widget's SQL would scan
  raw `data_assets` or `extracted_entities` to compute a count, that computation is a
  missing Read Model projection (`read-model-design`), not a client-side reduction. A
  paginated fetch over raw rows *undercounts*.
- **Name the Bounded Context and populating stage.** This lets the frontend generate a
  typed client and lets the data-engineer trace which pipeline stage's output the
  widget depends on (`data-pipeline-implementation`).
- **Physical isolation.** Because each tenant is physically separate, a cross-tenant
  aggregate is impossible by construction — a property to state, not a filter to add.
- **Snapshots for trend.** A "30 days ago" comparison reads a daily snapshot table
  (e.g. `estate_sensitivity_snapshot`), never a live historical scan — otherwise every
  render scans full history.

---

## Grain, filter, and aggregation defects to check

| Defect | Symptom | Correct |
|---|---|---|
| Grain confusion | "gap count" mixes per-asset and per-finding | Declare grain explicitly, once |
| Missing soft-delete filter | Deleted assets inflate totals | `deleted_at IS NULL` on every asset count |
| Raw-count vanity | Monotonic "total X" that only rises | Convert to a rate with a denominator |
| Client aggregation | Widget reads thousands of rows to count | Push the aggregate into a Read Model |
| Snapshot vs live confusion | Trend series scans history live | Read a dedicated daily snapshot table |
