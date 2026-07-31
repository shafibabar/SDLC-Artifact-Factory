# Cache-Aside Standard — Key Construction, TTL Policy, and Invalidate-on-Write

Full worked material referenced from `SKILL.md`'s "Cache-Aside Standard" section.
Self-contained — reads without the parent body already in context. Covers: which
query handlers qualify, the exact cache-key construction rule, the TTL policy and its
staleness rationale, and the invalidate-on-write rule that keeps a command handler's
write from leaving a stale cache entry live for the rest of its TTL.

---

## 1. Which Query Handlers Qualify

Cache-aside is opt-in, not a default every query handler carries. It applies only to
a query handler fronting a view `read-model-design` has already named cache-eligible —
"high-frequency, low-change dashboard summaries... with TTL; use only for reads that
tolerate short staleness" (`read-model-design`, its cache-candidates table). A query
handler with no documented latency problem stays uncached — `ListDataAssetsHandler`
(`SKILL.md`'s Query Handler Standard) is the standing example of one that should.
Adding a cache layer speculatively "because it can't hurt" is the anti-pattern this
standard exists to prevent: an extra moving part with an invalidation obligation, paid
for on every write, that no read pattern has actually earned.

---

## 2. Cache-Key Construction — One Shared Function, Never Two Independent Strings

The key is deterministic from the resource type, the tenant, and the business
identity or filter parameters that select the cached value — never from anything else
(never a request id, never a timestamp, nothing that would make two callers asking the
same question miss each other's cache entry):

```go
// internal/application/queries/cache_keys.go
// Called from BOTH the query handler that populates a key and the command handler
// that invalidates it. This is the one and only place the format is written down.
func dataAssetCacheKey(tenantID, id uuid.UUID) string {
    return fmt.Sprintf("dataasset:%s:%s", tenantID, id)
}
```

**Why this must be one shared function, not a format string copy-pasted into two
files.** A cache-aside layer only works if the key a command handler deletes is
*byte-for-byte* the key a query handler wrote. Two independently-written
`fmt.Sprintf` calls that happen to agree today drift the moment either one is edited
in isolation — the delete silently stops matching, the entry survives past its
logical invalidation, and nothing errors: a query handler serves stale data with no
symptom until someone notices. Treat a second, differently-shaped key-construction
call site for the same cached resource as a defect, not a style nit.

The tenant segment is mandatory and comes from `ctx` via the same `tenantID(ctx)`
helper `go-repository-pattern` uses for SQL `WHERE` clauses — a cache key with no
tenant segment is the caching-layer equivalent of a query missing its `tenant_id`
filter: one tenant's cached read becomes reachable by another tenant's key
collision-free path through the cache, bypassing physical isolation entirely
(`multi-tenancy-design`).

---

## 3. TTL Policy — A Stated Bound, Not a Guess

The TTL is the staleness contract, chosen from the same "tolerate short staleness"
criterion `read-model-design` already uses to decide *whether* a view is cache-
eligible at all — a bounded window the caller has explicitly accepted, not an
arbitrary performance knob:

| View shape | TTL | Rationale |
|---|---|---|
| Dashboard summary, human-viewed | 30s–5min | A human reloading a dashboard does not perceive staleness inside this window; this skill's own prior compliance-dashboard example already used 30s at the short end — `read-model-design` sanctions caching this view shape but does not itself name a TTL number |
| Single-entity lookup fronting a hot path | 10–30s | Shorter, because a single entity's state (e.g. this asset's current sensitivity) is more likely to be acted on immediately after a write than an aggregate summary is |
| Anything with no stated tolerance for staleness | Do not cache | If no one can say how stale is acceptable, cache-aside is the wrong tool — serve the view directly |

Every cache-eligible Read Model already carries an `AsOf` timestamp
(`read-model-design`'s Handling Eventual Consistency section, staleness rule) — the cached DTO's `AsOf`
is exactly as stale as the moment it was populated, and the TTL is the outer bound on
how long that staleness is allowed to persist before the next reader forces a refresh.
A TTL is not a substitute for `AsOf`; the response still carries it.

---

## 4. The Cache-Aside Read Path

```go
func (h *GetDataAssetSummaryHandler) Handle(ctx context.Context, q GetDataAssetSummary) (DataAssetSummaryDTO, error) {
    key := dataAssetCacheKey(q.TenantID, q.DataAssetID)
    if dto, ok := h.cache.Get(ctx, key); ok {
        return dto, nil
    }
    dto, err := h.view.Summary(ctx, q.TenantID, q.DataAssetID)
    if err != nil {
        return DataAssetSummaryDTO{}, err
    }
    h.cache.Set(ctx, key, dto, 30*time.Second) // bounded TTL — the staleness contract, not an afterthought
    return dto, nil
}
```

Check cache → on miss, query the view → populate with the bounded TTL from the table
above. No handler ever writes to the cache on anything but a genuine miss — a
cache-aside layer never becomes a write-through cache; the Read Model view remains the
one source of truth the cache is *beside*, not a second copy of.

---

## 5. Invalidate-on-Write — In the Same Command Handler, After Commit, Never a Separate Step

**The rule:** the command handler that wrote the change deletes the cache key itself,
as the step immediately following a successful `tx.Commit()` — never before commit,
and never as a separate deferred job, reconciliation sweep, or event-driven
invalidation consumer.

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) (Result, error) {
    // ... idempotency, load, authorise, domain call, save — see
    // references/command-handler-transaction-and-idempotency.md ...
    if err := tx.Commit(ctx); err != nil {
        return Result{}, fmt.Errorf("commit: %w", err)
    }
    h.cache.Delete(ctx, dataAssetCacheKey(cmd.TenantID, cmd.DataAssetID)) // invalidate-on-write, post-commit
    return Result{}, nil
}
```

**Why after commit, not before.** Deleting the key before `tx.Commit()` runs means a
transaction that ends up rolling back has already evicted a still-valid cache entry
for a write that never actually happened — not a correctness bug (the next reader just
pays one avoidable cache miss), but a needless one, and it is free to get right: commit
first, invalidate second, in the same function, in that order.

**Why in the same handler, not a separate step.** A separate invalidation path —
a background sweep, a second consumer reacting to the just-published Domain Event —
introduces exactly the gap between "the write is durable" and "the stale cache entry
is gone" that the TTL was already bounding. Deleting inline, in the handler that
already holds the tenant id and business identity needed to construct the key, closes
that gap to zero extra hops with no new moving part. This is a **delete**, never a
**re-populate-with-the-new-value** — the command handler wrote the Write Model, not
the Read Model; recomputing the view's new value here would require the command
handler to know how the view is projected, which is exactly the coupling CQRS's
Read/Write Model split exists to avoid. The next reader's ordinary cache-aside miss
does that work correctly, against whatever the projector has actually caught up to.

**What this does not fix.** Invalidate-on-write bounds how long a *stale* cached value
can survive a write — it does not close the separate read-your-own-writes gap between
"the command committed" and "the projector has caught up the Read Model itself"
(`read-model-design`'s `appliedVersion`-polling contract). A cache miss immediately
after this delete can still return a Read Model row one version behind the write that
just committed; that is the Read Model's own eventual-consistency window, not a
caching defect, and the client-side fix is `read-model-design`'s `appliedVersion`
poll, not a longer or shorter TTL here.
