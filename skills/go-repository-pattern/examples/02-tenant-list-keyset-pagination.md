# Example 2 — Lists over large tenant datasets: keyset pagination

Self-contained. A growing SaaS case: an enterprise tenant has 2 million data assets, and the UI pages through them 50 at a time. `OFFSET` pagination makes Postgres read and discard every skipped row: page 20,000 scans about a million rows, so it gets slower the deeper you go. It also returns duplicates or skips rows when data changes between pages. Keyset (cursor) pagination seeks straight to the position after the last row seen.

## Input

> Add `ListBySource(ctx, sourceID, cursor, limit)` to the read side for the "assets in this storage source" screen. Tenants range from 200 to 2,000,000 assets.

## Output

### Index — tenant-leading, matching the sort order

```sql
-- goose Up (go-migration owns how this ships)
CREATE INDEX CONCURRENTLY idx_data_assets_tenant_source_keyset
    ON data_assets (tenant_id, source_id, created_at, id)
    WHERE deleted_at IS NULL;
```

`tenant_id` leads the index because every query is tenant-scoped. `(created_at, id)` gives a total order: `id` breaks ties between rows created in the same microsecond.

### Repository method

```go
// AssetCursor is opaque to callers; the HTTP layer encodes it (e.g. base64 JSON).
type AssetCursor struct {
    CreatedAt time.Time
    ID        uuid.UUID
}

type AssetPage struct {
    Items []domain.DataAssetSummary
    Next  *AssetCursor // nil on the last page
}

func (r *DataAssetRepo) ListBySource(ctx context.Context, sourceID uuid.UUID, after *AssetCursor, limit int) (AssetPage, error) {
    if limit <= 0 || limit > 200 {
        limit = 50
    }
    afterCreatedAt, afterID := time.Time{}, uuid.Nil
    if after != nil {
        afterCreatedAt, afterID = after.CreatedAt, after.ID
    }
    const q = `
        SELECT id, created_at, name, sensitivity_level
          FROM data_assets
         WHERE tenant_id = @tenant_id AND source_id = @source_id AND deleted_at IS NULL
           AND (created_at, id) > (@after_created_at, @after_id) -- keyset seek; id breaks ties
         ORDER BY created_at, id
         LIMIT @page_size_plus_one` // one extra row tells us a next page exists
    rows, err := r.q.Query(ctx, q, pgx.StrictNamedArgs{
        "tenant_id":          tenantID(ctx),
        "source_id":          sourceID,
        "after_created_at":   afterCreatedAt,
        "after_id":           afterID,
        "page_size_plus_one": limit + 1,
    })
    if err != nil {
        return AssetPage{}, translatePgError(err, nil)
    }
    defer rows.Close()

    page := AssetPage{Items: make([]domain.DataAssetSummary, 0, limit)}
    for rows.Next() {
        var (
            assetID     uuid.UUID
            createdAt   time.Time
            name        string
            sensitivity string
        )
        if err := rows.Scan(&assetID, &createdAt, &name, &sensitivity); err != nil {
            return AssetPage{}, translatePgError(err, nil)
        }
        if len(page.Items) == limit { // the extra row: there is a next page
            last := page.Items[limit-1]
            page.Next = &AssetCursor{CreatedAt: last.CreatedAt, ID: last.ID}
            break
        }
        page.Items = append(page.Items, domain.DataAssetSummary{
            ID: assetID, CreatedAt: createdAt, Name: name, Sensitivity: domain.SensitivityLevel(sensitivity),
        })
    }
    if err := rows.Err(); err != nil {
        return AssetPage{}, translatePgError(err, nil)
    }
    return page, nil
}
```

## Why each choice

| Choice | Reason |
|---|---|
| Row-value comparison `(created_at, id) > (@after_created_at, @after_id)` | Uses the composite index directly. The `OR`-expanded form often doesn't. |
| `LIMIT limit+1` | Detects "has next page" without a `COUNT(*)`, which is a full scan on a 2-million-row tenant |
| Read-side summary type, not `Reconstitute` | A list screen needs a read model, not the Aggregate; loading Aggregates for display wastes work (see `cqrs-pattern`) |
| `defer rows.Close()` + `rows.Err()` | `rows.Next()` returning false can mean an error; checking `rows.Err()` is the only way to tell a short page from a failed one |
| No total count | A "page X of Y" total is a separate, cacheable query if the UI truly needs it |

**Trade-off:** you can jump to the next or previous page, but not to an arbitrary page number. For a large list that's the right trade; offer search and filters instead of "go to page 20,000".
