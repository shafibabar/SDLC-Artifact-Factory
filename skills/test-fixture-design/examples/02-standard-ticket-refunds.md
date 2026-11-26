# Standard: Event Ticket Refunds (Go, PostgreSQL, Redpanda)

**Unverified:** no Go toolchain, PostgreSQL or broker was available; this code has not been compiled or run.

## Input

> "Add integration tests for refunds. Saving a refund must write the `refund_issued` outbox row atomically, and we compare the refund statement against a golden file. Just wrap everything in the rollback transaction so it's consistent."

One database shared by all tenants (event organisers), `organiser_id` on every row.

## Output

| Test | Isolation | Reason |
|---|---|---|
| Repository save and reload | Roll back | One connection sees everything it needs |
| Refund above the paid amount is rejected by the constraint | Roll back | Same |
| Refund row and outbox row commit together, or neither | Scoped data | The subject is the commit boundary; a second connection must see the result |
| Statement matches golden file | None | Rendering is pure; no database |

```go
// internal/infrastructure/postgres/refund_repo_integration_test.go
func TestRefundRepo_SaveAndReload(t *testing.T) {
	t.Parallel()
	tx := db.WithTx(t, testPool)
	repo := postgres.NewRefundRepo(tx) // accepts pool or transaction
	refund := builders.NewRefund().WithAmountMinor(4500)

	if err := repo.Save(context.Background(), refund.Build(t)); err != nil {
		t.Fatalf("save: %v", err)
	}
	got, err := repo.ByID(context.Background(), refund.Build(t).ID())
	if err != nil {
		t.Fatalf("reload: %v", err)
	}
	if got.AmountMinor() != 4500 {
		t.Errorf("amount = %d, want 4500", got.AmountMinor())
	}
}

func TestRefundRepo_CommitsRefundAndOutboxTogether(t *testing.T) {
	t.Parallel()
	// Real commit needed: the subject is that both rows commit together.
	ctx := context.Background()
	organiser := db.ID(t, "organiser")
	db.Scoped(t, testPool, organiser, // registered before any write
		`DELETE FROM outbox WHERE organiser_id = $1`,
		`DELETE FROM refunds WHERE organiser_id = $1`,
	)
	refund := builders.NewRefund().WithID(db.ID(t, "refund")).WithOrganiser(organiser).Build(t)

	if err := postgres.NewRefundRepo(testPool).Save(ctx, refund); err != nil {
		t.Fatalf("save: %v", err)
	}

	var refunds, events int
	err := testPool.QueryRow(ctx, `SELECT
		(SELECT count(*) FROM refunds WHERE organiser_id = $1),
		(SELECT count(*) FROM outbox  WHERE organiser_id = $1)`, organiser).Scan(&refunds, &events)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if refunds != 1 || events != 1 {
		t.Errorf("refunds=%d events=%d, want 1 and 1", refunds, events)
	}
}
```

The "or neither" half uses the same scope: make the outbox insert fail through a real constraint (a seeded conflicting event ID, listed in the cleanup) and assert zero refunds. A running relay would read every unsent row, so it is not started in this package; its test gets its own schema, topic and consumer group.

```go
// internal/report/statement_test.go
func TestStatement_Golden(t *testing.T) {
	got := report.Render(builders.NewRefund().WithAmountMinor(4500).Build(t), builders.FixedNow)
	golden.Assert(t, "statement", got)
}
```

Regenerate only with `go test ./internal/report -run TestStatement_Golden -update`, then read the diff.

## The answer states

- **Isolation:** rollback by default; scoped data for the outbox test only, because it tests the commit itself.
- **Refused:** wrapping the outbox test in the rollback transaction. Nothing would be committed, so the atomicity claim could not be observed. This is not offered as an option.
- **Size:** the same rules as any size; here two builders, one transaction helper, one scoped helper.
- **Product-owner decisions:** none now; a golden diff that changes what a customer's statement shows goes to them.
- **Run:** nothing; all code is unverified. Next: `./scripts/validate-test-fixtures.sh`, then `go test -shuffle=on ./...`.
