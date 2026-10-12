# Example 4 — An event-sourced Aggregate: the same concurrency rule, a different store

Self-contained. Some Aggregates are stored as their **stream of Domain Events** rather than as a current-state row. An example is a `RetentionCase` whose full history must be auditable. Khononov (*Learning Domain-Driven Design*) points out that event sourcing does not need a new concurrency model. The current-state compare-and-swap ("`UPDATE … WHERE version = $N`, 0 rows means a concurrent write") becomes a **conditional append**: append the new events only if the stream is still at the expected version, and a rejected append means a concurrent writer.

## Input

> Persist `RetentionCase` as an event stream. Loading rebuilds it from its events. Saving appends the new events and must never interleave with a concurrent writer.

## Output

### Event store table

```sql
CREATE TABLE retention_case_events (
    tenant_id   uuid        NOT NULL,
    stream_id   uuid        NOT NULL,               -- the Aggregate ID
    version     bigint      NOT NULL,               -- 1, 2, 3 … per stream, no gaps
    event_type  text        NOT NULL,
    payload     jsonb       NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, stream_id, version)     -- the concurrency guard
);
```

The primary key is what enforces the rule. Two writers that both read version 7 both try to insert version 8, and Postgres rejects the second with a unique violation (`23505`).

### Repository

```go
type RetentionCaseRepo struct{ q Querier }

func (r *RetentionCaseRepo) WithTx(tx pgx.Tx) *RetentionCaseRepo { return &RetentionCaseRepo{q: tx} }

var _ domain.RetentionCaseRepository = (*RetentionCaseRepo)(nil)

func (r *RetentionCaseRepo) Load(ctx context.Context, id uuid.UUID) (*domain.RetentionCase, error) {
    rows, err := r.q.Query(ctx, `
        SELECT version, event_type, payload
          FROM retention_case_events
         WHERE tenant_id = $1 AND stream_id = $2
         ORDER BY version`, tenantID(ctx), id)
    if err != nil {
        return nil, translatePgError(err, nil)
    }
    defer rows.Close()

    var history []domain.RecordedEvent
    for rows.Next() {
        var recorded domain.RecordedEvent
        if err := rows.Scan(&recorded.Version, &recorded.Type, &recorded.Payload); err != nil {
            return nil, translatePgError(err, nil)
        }
        history = append(history, recorded)
    }
    if err := rows.Err(); err != nil {
        return nil, translatePgError(err, nil)
    }
    if len(history) == 0 {
        return nil, domain.ErrNotFound
    }
    // Rehydrate is the event-sourced Reconstitute: it applies stored events to
    // rebuild state, validates nothing, and emits nothing new.
    return domain.RehydrateRetentionCase(id, history)
}

// Append writes the pending events at expectedVersion+1, +2, …; it must run
// tx-bound (WithTx) so all events of one command commit together.
func (r *RetentionCaseRepo) Append(ctx context.Context, rc *domain.RetentionCase) error {
    next := rc.LoadedVersion() // the version this command read
    for _, event := range rc.PullEvents() {
        next++
        payload, err := json.Marshal(event)
        if err != nil {
            return fmt.Errorf("marshalling %s: %w", event.EventType(), err)
        }
        _, err = r.q.Exec(ctx, `
            INSERT INTO retention_case_events (tenant_id, stream_id, version, event_type, payload)
            VALUES (@tenant_id, @stream_id, @version, @event_type, @payload)`,
            pgx.StrictNamedArgs{
                "tenant_id":  rc.TenantID(),
                "stream_id":  rc.ID(),
                "version":    next,
                "event_type": event.EventType(),
                "payload":    payload,
            })
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) && pgErr.Code == "23505" {
            // Someone appended version `next` first: the same signal as a
            // compare-and-swap UPDATE that touched 0 rows.
            return fmt.Errorf("retention case %s at version %d: %w", rc.ID(), next-1, domain.ErrConcurrentModification)
        }
        if err != nil {
            return translatePgError(err, nil)
        }
    }
    return nil
}
```

## How it maps to the current-state repository

| Concern | Current-state (`DataAssetRepo`) | Event-sourced (`RetentionCaseRepo`) |
|---|---|---|
| Read | `SELECT` one row → `Reconstitute` | `SELECT` the stream → `Rehydrate` (applies events, emits none) |
| Concurrency guard | `WHERE version = $N`, 0 rows affected | `PRIMARY KEY (…, version)`, unique violation |
| Caller-visible conflict | `domain.ErrConcurrentModification` | `domain.ErrConcurrentModification`, the same sentinel, so the application layer handles both identically |
| Publishing events | Insert into the outbox in the same transaction | The event table *is* the source; a relay reads new rows by version (or the same outbox insert, if downstream consumers need the outbox's shape) |
| Transaction | Opened by the application layer, repository bound with `WithTx` | Unchanged |

**When not to event-source:** only where the full history has a business use (audit, temporal queries, replaying decisions). For most Aggregates, the current-state repository plus outbox events is simpler and enough.
