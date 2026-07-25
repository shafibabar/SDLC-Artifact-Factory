# Cache-Aside for Cache-Eligible Query Handlers

Full worked material referenced from `SKILL.md`'s "Optional: Cache-Aside for Cache-Eligible Views" section.

---

## Cache-Aside Pattern

`read-model-design` already names some views — "high-frequency, low-change dashboard summaries" — as candidates for a Redis/in-memory cache with a bounded TTL. Where a query handler fronts one of those views, the shape is a standard cache-aside: check cache → on miss, query the view → populate the cache with a bounded TTL.

```go
func (h *ComplianceDashboardHandler) Handle(ctx context.Context, q ComplianceDashboard) (DashboardDTO, error) {
    if dto, ok := h.cache.Get(ctx, q.CacheKey()); ok {
        return dto, nil
    }
    dto, err := h.view.Summary(ctx, q.TenantID)
    if err != nil {
        return DashboardDTO{}, err
    }
    h.cache.Set(ctx, q.CacheKey(), dto, 30*time.Second) // bounded TTL is the staleness contract, not an afterthought
    return dto, nil
}
```

This is available when a query handler's actual read pattern warrants it — `ListDataAssetsHandler` (in `SKILL.md`'s Query Handler section) has no documented latency problem today and should stay uncached. Add this layer only to a query handler fronting a view `read-model-design` has already flagged as cache-eligible, not speculatively to every query handler.
