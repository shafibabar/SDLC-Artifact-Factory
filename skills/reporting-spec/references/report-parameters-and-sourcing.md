# Report Parameters and Sourcing

Reference for the `reporting-spec` skill. Covers the parameter types a report
accepts, how each parameter binds to the source query **safely**, how a report
sources from a Read Model or mart, aggregation grain, and the additivity rules
that govern whether a metric may be summed across the report's date-range
parameter. Grounded in this repo's stack — Go, `chi`, `pgx`, PostgreSQL,
per-tenant physical isolation — and in Kimball & Ross's dimensional-modeling
discipline (grain declaration, periodic-snapshot facts, additive /
semi-additive / non-additive classification).

---

## 1. Parameter Types

A report parameter is a value the requester supplies (or the scheduler injects)
to scope a single generated instance. Four types cover almost every report in
this product.

| Type | Example | Bound to | Notes |
|---|---|---|---|
| **Date range** | `2026-01-01` .. `2026-03-31` | A `WHERE occurred_at >= $1 AND occurred_at < $2` clause | Fixed calendar bounds only; half-open `[start, end)` avoids double-counting the boundary day |
| **Dimension filter** | `framework = 'SOC2'`, `severity >= 'medium'` | An indexed dimension column on the Read Model | One value or a bounded IN-list; validated against an allow-list of known dimension values |
| **Tenant scope** | current tenant | The tenant predicate — **from session context, never the request** | See §3; this is the security-critical one |
| **Threshold / cutoff** | `min_group_size = 5` | A `HAVING count(*) >= $n` clause | Drives k-anonymity suppression and severity floors |

### Date-range parameters

Always half-open (`>= start AND < end`) and always fixed calendar values. A
relative range ("last 90 days") computed at generation time makes the report
unreproducible: regenerating it during a dispute next year yields a different
period. Store the resolved absolute bounds on the generated instance so the same
report can be re-run byte-for-byte.

```go
// The date range arrives as fixed calendar dates, already resolved
// (never "last 90 days"). start is inclusive, end is exclusive.
type ReportPeriod struct {
    Start time.Time // 2026-01-01T00:00:00Z
    End   time.Time // 2026-04-01T00:00:00Z (exclusive — the day AFTER the period)
}
```

### Dimension-filter parameters

A dimension filter narrows the report to a subset of a categorical dimension
(compliance framework, sensitivity level, data source, department). Validate the
supplied value against a known allow-list before it reaches the query — an
unrecognized framework code is a rejected request, not an empty report. This
both prevents nonsense output and closes off a class of injection attempts at the
edge.

---

## 2. Safe Binding — No Injection at the Export Boundary

The export boundary is the highest-risk exit point in the product, and a report
generator that builds SQL by string concatenation is an injection vector even
when the caller is authenticated. **Every parameter binds as a query placeholder
via `pgx`; a value is never interpolated into the SQL text.**

### Correct — parameterized

```go
func loadGapCounts(ctx context.Context, db *pgxpool.Pool,
    tenantID string, p ReportPeriod, framework string) ([]GapRow, error) {

    const q = `
        SELECT g.severity, count(*) AS gap_count
        FROM   compliance_gap_summary g
        WHERE  g.tenant_id  = $1          -- tenant from context (see §3)
          AND  g.opened_at >= $2
          AND  g.opened_at <  $3          -- half-open range
          AND  g.framework  = $4
        GROUP  BY g.severity
        ORDER  BY g.severity`

    rows, err := db.Query(ctx, q, tenantID, p.Start, p.End, framework)
    if err != nil {
        return nil, fmt.Errorf("load gap counts: %w", err)
    }
    defer rows.Close()
    return pgx.CollectRows(rows, pgx.RowToStructByName[GapRow])
}
```

`pgx` sends the SQL and the argument values on separate protocol paths; the
value `'; DROP TABLE ...` arrives as a literal string compared against
`framework`, never as executable SQL.

### Wrong — string-built (never do this)

```go
// DEFECT: framework is concatenated into the SQL text. An injection vector,
// and a defect regardless of what the report claims to show.
q := "SELECT severity, count(*) FROM compliance_gap_summary " +
     "WHERE framework = '" + framework + "'"
```

### Dynamic filters, still safe

When a report offers optional filters, build the *placeholder list*
dynamically while the *values* still bind positionally — never fold a value into
the string.

```go
args := []any{tenantID, p.Start, p.End}
conds := []string{"tenant_id = $1", "opened_at >= $2", "opened_at < $3"}
if framework != "" {
    args = append(args, framework)
    conds = append(conds, fmt.Sprintf("framework = $%d", len(args)))
}
q := "SELECT severity, count(*) FROM compliance_gap_summary WHERE " +
     strings.Join(conds, " AND ") + " GROUP BY severity"
rows, err := db.Query(ctx, q, args...)
```

Only the `$n` index is composed from server-controlled data (`len(args)`); every
user-supplied value remains a bound argument.

---

## 3. Tenant Scope — Always From Context

Under this product's **physical per-tenant isolation**, tenant is not a report
parameter at all. It is a fact of the authenticated session, resolved
server-side and injected into every query.

- The tenant id is taken from the request's authenticated principal (the session
  / JWT claim resolved by `chi` middleware), **never** from the request body,
  query string, or a form field.
- A cross-tenant report — "all tenants," a tenant list, or a tenant id that
  differs from the caller's — is structurally out of scope, not a feature to add
  later. Reject it; do not silently scope it down.
- Because isolation is physical, the tenant predicate also selects the correct
  physical database / schema for the caller. Binding tenant from context is what
  keeps a report from ever reading another tenant's rows.

```go
// Middleware has already authenticated and resolved the tenant. The report
// generator reads it from context — it is never a function parameter the
// caller can influence.
tenantID, ok := auth.TenantFromContext(ctx)
if !ok {
    return nil, ErrNoTenant // fail closed — never default to a tenant
}
```

A tenant value accepted from the request is a defect **even if it happens to
match the caller's own tenant**, because the code path that trusts it once will
trust it when it does not match.

---

## 4. Sourcing — Read Model or Mart, Not the Write Model

A report reads from a **Read Model** (a query-optimized projection) or a
purpose-built reporting mart, never from an Aggregate's Write Model. This keeps
reporting load off the transactional path and lets the projection carry
pre-shaped, pre-aggregated columns.

| Source shape | Use when | Example |
|---|---|---|
| **Live Read Model aggregation** | The metric can be computed correctly at read time from current rows | Count of open gaps right now |
| **Periodic snapshot table** | The report needs the value *as of* a past period boundary | `estate_sensitivity_snapshot` — sensitivity distribution captured daily |
| **Accumulating snapshot** | One row per long-running process, columns filled as milestones complete | One row per remediation workflow, a timestamp column per stage |

### Grain declaration is the first sourcing step

Before choosing columns, write the **grain** of each source as one literal
sentence — what one row represents (Kimball's four-step process: business
process → grain → dimensions → facts). "One row per compliance gap per day it was
open" is a grain; "gap data" is not. Every column the report reads must be
consistent with that one sentence. A section that mixes two grains (per-gap rows
joined to per-day snapshot rows without reconciling the grain) produces
double-counted totals.

### Aggregation grain vs. report grain

The source's grain and the report section's presentation grain can differ — the
report rolls the source up. State both: e.g., source grain "one row per gap per
day open"; section grain "one row per severity, counting distinct gaps in the
period." The roll-up SQL (`count(distinct gap_id)`) is what bridges them, and
getting it wrong is where additivity errors (§5) creep in.

---

## 5. Additivity — Can This Metric Be Summed Across the Period?

A report is a **periodic snapshot**: it freezes metrics as of its parameterized
period. The moment a section aggregates a metric across that date range, its
additivity must be classified. This is the single most consequential sourcing
check, because a wrong sum prints a plausible-looking, meaningless number.

| Class | Sums across… | Example in this product | Rule |
|---|---|---|---|
| **Additive** | every dimension, including time | Count of gaps *opened* in the period | Safe to `sum()` across days, severities, sources |
| **Semi-additive** | some dimensions but **not time** | Count of gaps *open* at each day's close; total assets under management at period end | Never `sum()` across periods — pick the period-end value, or average across time; summing double-counts |
| **Non-additive** | no dimension | Percentage of assets classified; gap-closure rate | Never sum or average the ratio; recompute from the additive numerator and denominator |

### The classic semi-additive trap

A "gaps open" figure is a point-in-time balance. Summing Monday's 40 open gaps +
Tuesday's 41 + Wednesday's 39 to report "120 open gaps this week" is nonsense —
the same gap open all three days is counted three times. A **semi-additive** fact
sums across entities but not across time; for a period figure you take the value
at the period boundary (or a time-average), never the cross-period sum.

```sql
-- WRONG: sums a semi-additive balance across days → meaningless triple-count
SELECT sum(open_gap_count) FROM daily_gap_snapshot
WHERE tenant_id = $1 AND snapshot_date >= $2 AND snapshot_date < $3;

-- RIGHT: semi-additive → take the value at the period-end boundary
SELECT open_gap_count FROM daily_gap_snapshot
WHERE tenant_id = $1 AND snapshot_date = ($3::date - 1);  -- last day of period

-- RIGHT: additive → gaps OPENED (a discrete event) IS summable across the range
SELECT count(*) FROM compliance_gap_summary
WHERE tenant_id = $1 AND opened_at >= $2 AND opened_at < $3;
```

### Non-additive: recompute, never average the ratio

A classification-coverage percentage cannot be averaged across periods (averaging
per-day percentages weights a low-volume day equally with a high-volume one).
Carry the additive numerator (classified assets) and denominator (total assets)
through to the report and compute the ratio once at the presentation grain.

### The per-section additivity check

For every report section that aggregates across the date-range parameter, the
spec states the metric's additivity class and the aggregation rule that follows
from it. A section that sums a value without this check having been done is a
defect waiting to print a wrong total to an auditor.

---

## 6. Sourcing Checklist

- [ ] Each section sources from a Read Model or mart, never a Write Model.
- [ ] Every source has a one-sentence grain declaration.
- [ ] Section (presentation) grain is stated where it differs from source grain.
- [ ] Every parameter binds as a `pgx` placeholder; no value is string-built.
- [ ] Tenant comes from session context and fails closed if absent.
- [ ] Date ranges are fixed, half-open, and stored on the generated instance.
- [ ] Dimension-filter values are validated against an allow-list.
- [ ] Every cross-period aggregate is classified additive / semi-additive /
      non-additive, with the summing rule stated.
