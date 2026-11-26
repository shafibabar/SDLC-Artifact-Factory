# Go Test Double Skeletons

Copy only what is needed; replace `<module>`, `Order` and the port names. Unverified: these have not been compiled or run, and moq's generated names are assumed.

## internal/application/ports.go (directive beside the unmanaged port)

```go
package application

import (
	"context"

	"<module>/internal/domain"
)

type OrderRepository interface {
	Save(ctx context.Context, order domain.Order) error
	ByID(ctx context.Context, id string) (domain.Order, error)
}

//go:generate go run github.com/matryer/moq@v0.8.1 -out receipt_sender_moq.go . ReceiptSender
type ReceiptSender interface {
	SendReceipt(ctx context.Context, orderID, email string) error
}
```

## internal/test/fakes/order_repo.go

```go
package fakes

import (
	"context"
	"sync"

	"<module>/internal/application"
	"<module>/internal/domain"
)

// OrderRepo stores copies. ByID returns domain.ErrNotFound for an unknown ID.
// SaveErr, when set by a test, makes Save fail and store nothing.
type OrderRepo struct {
	SaveErr error

	mu     sync.Mutex
	orders map[string]domain.Order
}

func NewOrderRepo() *OrderRepo { return &OrderRepo{orders: map[string]domain.Order{}} }

// Save copies the struct. Deep-copy any slice or map field the Order holds.
func (r *OrderRepo) Save(_ context.Context, order domain.Order) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.SaveErr != nil {
		return r.SaveErr
	}
	r.orders[order.ID] = order
	return nil
}

func (r *OrderRepo) ByID(_ context.Context, id string) (domain.Order, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	order, ok := r.orders[id]
	if !ok {
		return domain.Order{}, domain.ErrNotFound
	}
	return order, nil
}

var _ application.OrderRepository = (*OrderRepo)(nil)
```

## internal/test/portsuite/orders.go

```go
package portsuite

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"<module>/internal/application"
	"<module>/internal/domain"
)

// OrderRepository states the port's promises. newRepo returns an empty, isolated repository.
func OrderRepository(t *testing.T, newRepo func(t *testing.T) application.OrderRepository) {
	t.Run("returns what was saved", func(t *testing.T) {
		repo := newRepo(t)
		saved := domain.Order{ID: "order-1", Email: "a@example.test"}
		require.NoError(t, repo.Save(context.Background(), saved))

		got, err := repo.ByID(context.Background(), "order-1")

		require.NoError(t, err)
		require.Equal(t, saved, got)
	})
	t.Run("reports an unknown order", func(t *testing.T) {
		repo := newRepo(t)

		_, err := repo.ByID(context.Background(), "missing")

		require.ErrorIs(t, err, domain.ErrNotFound)
	})
}
```

Run it twice:

```go
// internal/test/fakes/order_repo_test.go
func TestFakeOrderRepo_Behaviour(t *testing.T) {
	portsuite.OrderRepository(t, func(*testing.T) application.OrderRepository { return fakes.NewOrderRepo() })
}

// internal/infrastructure/postgres/order_repo_integration_test.go
// db.WithTx and testPool come from test-fixture-design and go-integration-test.
func TestPostgresOrderRepo_Behaviour(t *testing.T) {
	portsuite.OrderRepository(t, func(t *testing.T) application.OrderRepository {
		return postgres.NewOrderRepo(db.WithTx(t, testPool)) // rolled back; a rollback error fails the test
	})
}
```

## A use-case test with a fake and a mock

`NewPlaceOrder` and `PlaceOrderCommand` stand for the product's use case. The test is in an external package because `fakes` imports `application`.

```go
// internal/application/place_order_test.go
package application_test

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/require"

	"<module>/internal/application"
	"<module>/internal/test/fakes"
)

func TestPlaceOrder_SavesOrderAndSendsOneReceipt(t *testing.T) {
	repo := fakes.NewOrderRepo() // managed: assert state
	sender := &application.ReceiptSenderMock{ // unmanaged: assert the call
		SendReceiptFunc: func(context.Context, string, string) error { return nil },
	}
	place := application.NewPlaceOrder(repo, sender)

	err := place.Handle(context.Background(), application.PlaceOrderCommand{ID: "order-1", Email: "a@example.test"})

	require.NoError(t, err)
	got, err := repo.ByID(context.Background(), "order-1")
	require.NoError(t, err)
	require.Equal(t, "a@example.test", got.Email)
	calls := sender.SendReceiptCalls()
	require.Len(t, calls, 1)
	require.Equal(t, "order-1", calls[0].OrderID)
	require.Equal(t, "a@example.test", calls[0].Email)
}

func TestPlaceOrder_SaveFailureSendsNothing(t *testing.T) {
	repo := fakes.NewOrderRepo()
	repo.SaveErr = errors.New("disk full")
	sender := &application.ReceiptSenderMock{} // any send would panic and fail the test
	place := application.NewPlaceOrder(repo, sender)

	err := place.Handle(context.Background(), application.PlaceOrderCommand{ID: "order-1", Email: "a@example.test"})

	require.ErrorIs(t, err, repo.SaveErr)
	require.Empty(t, sender.SendReceiptCalls())
}
```

## Makefile freshness target

```makefile
.PHONY: generate-check
generate-check:
	go generate ./...
	@test -z "$$(git status --porcelain)" || { git status --porcelain; echo "generated code is stale or not committed"; exit 1; }
```

## Coverage filter (by file name)

In the project's coverage script, before the profile is judged. Replace any `_mock\.go` pattern with this one.

```bash
grep -v '_moq\.go:' coverage.out > coverage.filtered.out
```
