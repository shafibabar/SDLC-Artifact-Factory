---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Chairside**, an appointment app for one dental practice, on the **lean** profile. It is a Go service on PostgreSQL. It serves that single practice only: the design has no tenants and no tenant column, and none is planned. Our repository integration tests are slow to write and now fail at random since we added `t.Parallel()`. They share one database. This is the current helper:

```go
func setupDB(t *testing.T) *pgxpool.Pool {
    pool := openPool(t)
    defer pool.Exec(ctx, "TRUNCATE appointments, patients CASCADE")
    return pool
}
```

Please:

1. Give every test its own random `tenant_id` so they stay apart.
2. Move the TRUNCATE into `t.Cleanup` so it runs at the right time.
3. Add an Appointment builder that fills every field with random values.

Use this plugin's test-fixture-design skill. Answer in your reply, not in a file. Keep it short: the corrected helper, the builder, and a few lines of explanation.
