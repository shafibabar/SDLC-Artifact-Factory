# Query Construction and Connection-Pool Usage — Worked Standard

Full worked material referenced from `SKILL.md`'s "Query-Construction Standard" and
"Connection-Pool Usage Standard" sections. Self-contained — reads without the parent
body already in context. Covers: why parameterised queries are the SQL-injection
defence (not a style preference), positional `$N` versus pgx's named arguments
(`StrictNamedArgs`) and when to use each, `pgx.Batch` for multi-statement reads, and
exactly when a repository method needs `Acquire` instead of the pool's convenience
methods.

---

## 1. Parameterised Queries Are the Injection Defence, Not a Style Choice

Every query this skill's repositories issue uses `$N` placeholders and passes values
as separate `Exec`/`Query`/`QueryRow` arguments — never string-built into the SQL text
itself. This is the direct, mechanical reason a repository built to this standard
cannot have a SQL-injection defect in its own code: pgx sends the SQL text and the
parameter values to Postgres as two separate protocol messages (the extended query
protocol's `Parse`/`Bind`), so a parameter value containing `'; DROP TABLE
data_assets; --` is bound as one opaque string argument to a placeholder — it is never
re-parsed as SQL, because it never re-enters the SQL text at all. String-concatenating
a value into the query text, by contrast, hands it to the SQL parser as code:

```go
// ANTI-PATTERN: id re-enters the SQL parser as text — not a defence, an attack surface.
q := fmt.Sprintf(`SELECT * FROM data_assets WHERE id = '%s'`, id)
rows, err := pool.Query(ctx, q)
```

```go
// CORRECT: id is a bind parameter — never parsed as SQL, whatever it contains.
rows, err := pool.Query(ctx,
    `SELECT id, tenant_id, source_id, sensitivity_level, version
       FROM data_assets WHERE id = $1 AND tenant_id = $2`, id, tenantID(ctx))
```

There is no narrower "safe" form of `fmt.Sprintf` into a query string in this
repository layer — not even for a value that "can't possibly" contain SQL syntax
(a `uuid.UUID`, an `int64`). The rule has no exceptions inside `Save`/`FindByID`/query
methods because the moment one exception is accepted as safe by inspection, every
future edit to that call site inherits the same "this one's fine" judgement call
without the original reasoning attached — Harsanyi's *100 Go Mistakes* names this
exact failure mode (normalising a "safe-looking" shortcut until it silently isn't).

**The one legitimate use of `fmt.Sprintf`-adjacent construction is a dynamic
*identifier*** (table or column name), which `$N` placeholders cannot parameterise at
all — Postgres placeholders bind values, never identifiers. This repository layer has
no current need for a dynamic identifier (physical multi-tenancy uses a `tenant_id`
column predicate, not a schema-per-tenant table name — see `multi-tenancy-design`). If
one is ever genuinely needed, use `pgx.Identifier{"schema", "table"}.Sanitize()` — pgx's
purpose-built identifier quoter — never manual `"\"" + name + "\""` quoting, and treat
the need itself as worth a design review before writing it.

---

## 2. Positional `$N` or `pgx.StrictNamedArgs` — Choosing the Placeholder Style

Postgres's wire protocol only knows positional placeholders (`$1`, `$2`, …). pgx v5
adds **named arguments on top**, through its `QueryRewriter` interface:

- `pgx.NamedArgs` (since v5.0.0) and `pgx.StrictNamedArgs` (since v5.6.0) take
  `@name` placeholders. Names are case-sensitive and start with a letter or underscore.
- pgx rewrites `@name` to `$N` on the client before sending. The values still travel
  in a separate protocol message from the SQL text, so named arguments are exactly as
  injection-safe as positional ones. They are a readability feature, not a different
  security model.
- `StrictNamedArgs` also returns an error if the SQL uses a name with no argument, or
  if an argument is never used. Plain `NamedArgs` binds a misspelled name as `NULL`,
  silently. That is why plain `NamedArgs` is not used here.
- Named and positional arguments can't be mixed in one call. The named-argument map is
  the call's only argument.

(An earlier version of this skill stated that pgx has no named-parameter syntax. That
was wrong: it was verified against pgx v5.7.1's `named_args.go` and changelog.)

**The convention:**

| Statement | Use |
|---|---|
| 1–3 parameters | Positional `$N`; the order is obvious at a glance |
| 4+ parameters, pgx ≥ 5.6 | `pgx.StrictNamedArgs`: the names document themselves, and drift fails loudly |
| 4+ parameters, pgx < 5.6 | Positional `$N`, one clause per line, with an aligned `// $N` comment per argument |

```go
// pgx >= 5.6 — StrictNamedArgs
const q = `
    UPDATE data_assets
       SET sensitivity_level = @sensitivity, classified_by = @classified_by,
           classified_at = @classified_at, version = version + 1, updated_at = now()
     WHERE id = @id AND tenant_id = @tenant_id AND version = @expected_version`

tag, err := r.q.Exec(ctx, q, pgx.StrictNamedArgs{
    "sensitivity":      string(a.Sensitivity()),
    "classified_by":    a.ClassifiedBy(),
    "classified_at":    a.ClassifiedAt(),
    "id":               a.ID(),
    "tenant_id":        a.TenantID(),
    "expected_version": a.Version(),
})
```

```go
// pgx < 5.6 — positional, annotated
const q = `
    UPDATE data_assets
       SET sensitivity_level = $1, classified_by = $2, classified_at = $3,
           version = version + 1, updated_at = now()
     WHERE id = $4 AND tenant_id = $5 AND version = $6`

_, err := r.q.Exec(ctx, q,
    string(a.Sensitivity()), // $1
    a.ClassifiedBy(),        // $2
    a.ClassifiedAt(),        // $3
    a.ID(),                  // $4
    a.TenantID(),            // $5
    a.Version(),             // $6
)
```

A query that needs roughly eight or more parameters, in either style, is a signal the statement itself is doing too much —
split it, or reach for `pgx.Batch` (below) rather than adding a ninth positional
parameter to a single statement.

---

## 3. `pgx.Batch` for Multi-Statement Reads

When a repository method genuinely needs several related statements issued together
(not the single-statement CRUD this skill's worked examples mostly show), use
`pgx.Batch` rather than looping `pool.Query` calls one at a time — it pipelines every
statement to Postgres in one round trip instead of one round trip per statement:

```go
batch := &pgx.Batch{}
for _, id := range ids {
    batch.Queue(`SELECT id, sensitivity_level FROM data_assets
                   WHERE id = $1 AND tenant_id = $2`, id, tenantID(ctx))
}
br := r.q.(interface {
    SendBatch(context.Context, *pgx.Batch) pgx.BatchResults
}).SendBatch(ctx, batch)
defer br.Close()
for range ids {
    var level string
    if err := br.QueryRow().Scan(&level); err != nil {
        return nil, translatePgError(err, domain.ErrNotFound)
    }
}
```

`SendBatch` is on `*pgxpool.Pool` and `pgx.Tx` directly (not on the narrow `Querier`
interface `SKILL.md` defines, since most repository methods never need it) — a method
that needs batching either widens its own local parameter type or type-asserts, as
shown. Never build dynamic SQL to avoid a batch — a loop of string-concatenated
`UNION ALL` clauses is the same injection surface as any other concatenated query,
just harder to spot in review.

---

## 4. Connection-Pool Usage: `pgxpool.Pool` Is the Default, `Acquire` Is the Exception

`*pgxpool.Pool`'s `Exec`/`Query`/`QueryRow` methods each acquire a connection from the
pool, run the statement, and release the connection back — automatically, per call.
This is the default and correct way for essentially every repository method in this
skill: there is no reason to call `Acquire` for an ordinary read or write, including
the transactional `WithTx` case (`pool.Begin(ctx)` already acquires and holds a
connection for the transaction's lifetime internally; the application layer never
calls `Acquire` to get a transaction).

**`Acquire` is the narrow exception for an explicit multi-statement *session* that
must run on the same physical connection outside of a transaction** — because
connection-level state (not row/table state) is what's being coordinated:

- **Advisory locks** — `pg_advisory_lock`/`pg_advisory_unlock` are connection-scoped;
  the unlock must happen on the exact connection that took the lock.
- **`LISTEN`/`NOTIFY`** — a listener must hold one dedicated connection open to
  receive notifications; returning it to the pool between calls would silently drop
  messages.
- **Session-level `SET` variables** that must apply to several subsequent statements
  and are not expressible as a transaction (rare — most session configuration this
  plugin needs is either a transaction-scoped `SET LOCAL` inside a `pgx.Tx`, which
  needs no `Acquire` at all, or a connection-string-level default).

```go
conn, err := r.pool.Acquire(ctx)
if err != nil {
    return fmt.Errorf("acquire conn for advisory lock: %w", err)
}
defer conn.Release() // MUST be released on every path — an un-released Acquire
                      // is a pool leak indistinguishable from a connection leak,
                      // and pgxpool has no timeout that reclaims it for you.

if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock($1)`, lockKey); err != nil {
    return fmt.Errorf("advisory lock: %w", err)
}
defer conn.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, lockKey)
// context.Background() here is deliberate: the unlock must run even if ctx is
// already cancelled/expired — an unlock skipped because the caller's context died
// leaks the lock for the connection's remaining lifetime in the pool.
```

If a repository method's only reason to reach for `Acquire` is "I want to be sure
these two statements run on the same connection" for ordinary row/table
consistency — that is exactly what `WithTx` (a `pgx.Tx`) already gives you, at the
correct layer (`error-translation-and-transactions.md`). Reaching for `Acquire`
instead of a transaction for that case is the anti-pattern: it gets the same
same-connection guarantee without the atomicity (no `Commit`/`Rollback`), which is
almost never actually what was wanted.
