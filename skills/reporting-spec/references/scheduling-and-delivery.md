# Scheduling and Delivery

Reference for the `reporting-spec` skill. Covers when a report runs (cadence /
cron), what file it produces (CSV / PDF / XLSX), how it reaches its recipients
(delivery channels), how a large report is generated without exhausting memory
(pagination / streaming), and what happens when generation or delivery fails
(retry and backoff). Grounded in this repo's stack — Go, PostgreSQL + `pgx`,
Redpanda, Kubernetes, OpenTelemetry.

---

## 1. Cadence — Scheduled, On-Demand, or Both

A report definition declares one or more trigger modes.

| Mode | Trigger | Typical use |
|---|---|---|
| **On-demand** | A user request (`chi` HTTP handler) | An auditor-prep evidence pull ahead of a specific audit window |
| **Scheduled** | A cron expression evaluated by a scheduler | A monthly compliance-gap report emailed on the 1st |
| **Both** | Either path invokes the same generator | The SOC 2 evidence report: monthly snapshot *and* on-demand before an audit |

Scheduled and on-demand must invoke the **same generation code** against the
same definition — the only difference is who supplies the parameters (a user vs.
the scheduler's fixed configuration). Two code paths that can diverge produce two
subtly different reports under the same name.

### Cron expressions

Cadence is a standard 5-field cron expression stored on the definition, always
evaluated in an explicit timezone (store the timezone; never rely on the host's
local time — a report period boundary that shifts with DST is unreproducible).

| Cadence | Cron | Notes |
|---|---|---|
| Daily 02:00 | `0 2 * * *` | Operational worklists; runs after the nightly snapshot job |
| Weekly Mon 06:00 | `0 6 * * 1` | Weekly operational summaries |
| Monthly 1st 03:00 | `0 3 1 * *` | Analytical period reports — the period is the *previous* calendar month |
| Quarterly | `0 3 1 1,4,7,10 *` | Quarter-end compliance reporting |

For a monthly report run on the 1st, the parameterized period is the **month
that just ended**, resolved to fixed calendar bounds at trigger time (e.g. a run
on 2026-04-01 reports `2026-03-01 .. 2026-04-01`). Resolve and store those bounds
on the generated instance so a re-run reproduces it exactly.

### Scheduling mechanism in this stack

A report run is a discrete job, not a long-lived service. Prefer the simplest
mechanism that fits (frugality): a Kubernetes `CronJob` that invokes the report
generator is the default; a scheduler service that emits a
`report.generation.requested` event onto Redpanda (consumed by a generator
worker) is the pattern once report volume or fan-out (many tenants, staggered)
justifies decoupling trigger from execution. Do not reach for the event-driven
version until the CronJob is genuinely insufficient.

---

## 2. Output Formats

| Format | Content model | Rendering | Use when |
|---|---|---|---|
| **CSV** | Flat, one row per record, UTF-8 with header row | Streamed server-side, row by row | Tabular data for re-analysis, import, or a ticket queue |
| **PDF** | Formatted, sectioned, with charts and a parameter block | Rendered server-side (never in the browser) | External human audiences: auditor, board, customer |
| **XLSX** | Multiple tabbed sheets, typed cells, light formatting | Written server-side with a streaming writer | A spreadsheet consumer wanting several sections as tabs |

### CSV specifics

One row per record; column headers use Ubiquitous Language names, not internal
field names (`sensitivity_level`, not `sens_lvl`). RFC 4180 quoting for any field
containing a comma, quote, or newline. Never place a free-text field sourced from
document content into a CSV cell — CSV is structured metadata only. Emit a UTF-8
BOM only if a known consumer (older Excel) requires it; prefer none.

### PDF specifics — server-side, always

PDF rendering happens server-side. A compliance PDF library shipped to every
browser session is wasted bundle weight and scatters the sensitive-formatting
logic across clients. Server-side rendering gives consistent fidelity and keeps
redaction/classification logic in one controlled place. Every PDF carries the
parameter block (period, tenant, framework), a generation timestamp, and a
definition-version footer on every page.

### XLSX specifics

Use a streaming writer (e.g. a stream-mode workbook writer) so a large sheet does
not materialize entirely in memory. One section per sheet/tab; a summary sheet
first. Typed cells (dates as dates, counts as integers) so the consumer does not
re-parse strings.

---

## 3. Delivery Channels

| Channel | Mechanism | Suits |
|---|---|---|
| **In-app download** | Generated file stored to object storage; a signed, expiring URL returned to the requester | On-demand pulls; the default and most secure |
| **Email attachment / link** | Scheduled reports emailed to a configured recipient list | Recurring analytical reports; prefer a link to a signed URL over attaching a sensitive file |
| **Object-storage drop** | Written to a tenant-scoped bucket/prefix (S3, tenant-isolated) | Machine consumers; another system polls the prefix |
| **Webhook / event** | A `report.generated` event on Redpanda with a reference to the stored artifact | Downstream automation reacting to a fresh report |

### Delivery security rules

- A report carrying Confidential+ content is **distributed through
  access-controlled channels only** (signed expiring URL, tenant-scoped bucket) —
  never an open email attachment. This follows `data-classification`'s control
  mapping: the report's own classification governs how it may travel.
- Signed URLs expire (minutes to hours, not days) and are single-tenant scoped.
- Recipient lists are validated against the tenant's own users — a scheduled
  report never delivers across a tenant boundary, the same isolation rule that
  governs the query also governs delivery.
- Store the artifact encrypted at rest; deliver over TLS (encryption in transit).

---

## 4. Large Reports — Pagination and Streaming

A report spanning a large estate can produce hundreds of thousands of rows.
Loading them all into memory before writing the file risks OOM-killing the job.

### Stream, do not buffer

Write the output file incrementally as rows arrive from the database. For CSV,
flush each row to the output writer (which streams to object storage or the HTTP
response) rather than building a slice of all rows first.

```go
// Stream rows straight to the CSV writer; never accumulate all rows in memory.
func streamGapCSV(ctx context.Context, db *pgxpool.Pool, w io.Writer,
    tenantID string, p ReportPeriod) error {

    cw := csv.NewWriter(w)
    _ = cw.Write([]string{"gap_id", "severity", "framework", "opened_at"})

    rows, err := db.Query(ctx, gapDetailQuery, tenantID, p.Start, p.End)
    if err != nil {
        return fmt.Errorf("query gaps: %w", err)
    }
    defer rows.Close()

    for rows.Next() {
        var r GapDetail
        if err := rows.Scan(&r.ID, &r.Severity, &r.Framework, &r.OpenedAt); err != nil {
            return err
        }
        if err := cw.Write(r.CSVRecord()); err != nil {
            return err
        }
    }
    cw.Flush()
    return errors.Join(rows.Err(), cw.Error())
}
```

### Keyset pagination for chunked reads

When a report is assembled in chunks (or resumed after a failure), page the
source with **keyset (seek) pagination** — `WHERE (opened_at, gap_id) > ($n, $m)
ORDER BY opened_at, gap_id LIMIT $k` — not `OFFSET`. `OFFSET` re-scans and skips
rows, degrading badly at depth; keyset pagination stays constant-cost per page
and is stable if rows are inserted during the run.

### Bounded work

Set a statement timeout and a maximum row cap for on-demand reports so a mistaken
unbounded request cannot hold a connection indefinitely. A report that would
exceed the cap is redirected to the scheduled/async path, not run inline.

---

## 5. Failure Handling and Retry

Report generation touches the database, a renderer, object storage, and a
delivery channel — any of which can fail transiently. Generation and delivery
have different retry semantics and must be separated.

### Generation is idempotent and retryable

- Model a run as a job with a status: `pending → generating → generated →
  delivered`, or `failed`. Persist the status so a crashed run is recoverable.
- Generation is a **pure function of (definition version, resolved parameters)** —
  re-running it produces the identical artifact. This makes retry safe: a failed
  generation is simply re-attempted.
- **Retry and backoff**: transient failures (DB timeout, renderer hiccup) retry
  with exponential backoff and jitter, capped at a small number of attempts.
- A run that keeps failing after its attempts is moved to a **Dead Letter Queue**
  (when generation is event-driven on Redpanda) or a `failed` terminal state with
  the error recorded, and an operator is alerted — never silently dropped.

### Delivery retries separately from generation

Once an artifact is generated and stored, delivery retries independently — a
transient email/SMTP failure must not trigger regeneration of the (already
correct, already stored) artifact. Retry delivery against the stored artifact by
reference. This separation also keeps generation idempotent: re-delivering is
cheap; re-generating is not, and re-generating an evidence report risks producing
a second instance where one is expected.

### Never partially deliver

A report that failed midway is not delivered as a truncated file. Either the full
artifact is generated and stored, then delivered, or the run is marked failed and
retried — a recipient never receives a half-written CSV or a PDF missing its last
section. Write to a temporary object and atomically promote it on success.

### Observability

Emit OpenTelemetry spans for generation and delivery, and metrics for run
duration, row count, output size, and failure count per definition. A report
that silently stops running (a broken CronJob) is a compliance risk; alert on a
scheduled report that has not produced an instance within its expected window.

---

## 6. Scheduling and Delivery Checklist

- [ ] Scheduled and on-demand paths invoke the same generator against the same definition.
- [ ] Cron cadence stored with an explicit timezone; period resolved to fixed bounds at trigger time.
- [ ] Format chosen for the audience (PDF external/human; CSV/XLSX tabular).
- [ ] PDF rendered server-side, never in the browser.
- [ ] Confidential+ reports delivered only over access-controlled channels (signed expiring URL, tenant bucket).
- [ ] Recipient lists validated within the tenant; no cross-tenant delivery.
- [ ] Output streamed, not buffered; keyset pagination for chunked reads.
- [ ] Generation idempotent; retry with backoff and jitter; DLQ / failed state after cap.
- [ ] Delivery retries against the stored artifact, separately from generation.
- [ ] No partial delivery — temp object promoted atomically on success.
- [ ] OpenTelemetry spans/metrics emitted; alert on a missed scheduled window.
