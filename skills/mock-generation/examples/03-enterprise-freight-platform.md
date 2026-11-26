# Enterprise: Freight Platform (sibling services, tenants, faults)

**Unverified:** no Go toolchain or database was available; this code has not been compiled or run.

## Input

> "The dispatch service calls our own pricing service for a quote, tells our own yard service to reserve a bay, and stores shipments per shipper. Schema per shipper. Give us doubles; the shipment fake should also simulate the database being down. Coverage is failing on the test support code, so exclude the fakes."

## Output

| Port | Class | Double | Assert |
|---|---|---|---|
| `ShipmentRepository` | Managed | Fake, scoped by shipper | State |
| `PricingClient.Quote` | Other service, a query | Stub (moq struct) | Nothing about the call |
| `YardClient.ReserveBay` | Other service, a command | moq mock | One reservation: shipper, shipment |

Refused: excluding the fakes. They are hand-written, so the 100% gate counts them; only the `_moq.go` files leave it automatically. Cover each fake method and fault field. Any line that still cannot be covered goes to the product owner with its reason.

```go
// internal/test/fakes/shipment_repo.go
type shipmentKey struct{ shipper, id string }

// ShipmentRepo holds copies per shipper. A shipper never sees another's shipment:
// ByID returns domain.ErrNotFound. A non-nil SaveErr makes Save fail and store nothing.
type ShipmentRepo struct {
	SaveErr error
	byKey   map[shipmentKey]domain.Shipment
}

func NewShipmentRepo() *ShipmentRepo { return &ShipmentRepo{byKey: map[shipmentKey]domain.Shipment{}} }

func (r *ShipmentRepo) Save(_ context.Context, shipper string, s domain.Shipment) error {
	if r.SaveErr != nil {
		return r.SaveErr
	}
	r.byKey[shipmentKey{shipper, s.ID}] = s
	return nil
}

func (r *ShipmentRepo) ByID(_ context.Context, shipper, id string) (domain.Shipment, error) {
	s, ok := r.byKey[shipmentKey{shipper, id}]
	if !ok {
		return domain.Shipment{}, domain.ErrNotFound
	}
	return s, nil
}

var _ application.ShipmentRepository = (*ShipmentRepo)(nil)
```

The behaviour suite includes isolation, and runs against this fake and against the PostgreSQL adapter (with a throwaway schema per shipper, as the tenancy design says):

```go
// inside portsuite.ShipmentRepository(t, newRepo)
t.Run("hides another shipper's shipment", func(t *testing.T) {
	repo := newRepo(t)
	require.NoError(t, repo.Save(context.Background(), "shipper-a", domain.Shipment{ID: "shipment-1"}))

	_, err := repo.ByID(context.Background(), "shipper-b", "shipment-1")

	require.ErrorIs(t, err, domain.ErrNotFound)
})
```

```go
// internal/application/dispatch_test.go (package application_test)
func TestDispatch_SaveFailureReservesNoBay(t *testing.T) {
	repo := fakes.NewShipmentRepo()
	repo.SaveErr = errors.New("database unavailable")
	pricing := &application.PricingClientMock{ // stub: calls are not asserted
		QuoteFunc: func(context.Context, string) (int64, error) { return 42000, nil },
	}
	yard := &application.YardClientMock{} // any reservation panics and fails the test
	dispatch := application.NewDispatch(repo, pricing, yard)

	err := dispatch.Handle(context.Background(), "shipper-a", "shipment-1")

	require.ErrorIs(t, err, repo.SaveErr)
	require.Empty(t, yard.ReserveBayCalls())
}
```

This assumes the product's rule is save first, then reserve; confirm it in the design. The success test asserts the saved quote and exactly one `ReserveBayCalls` entry with `shipper-a` and `shipment-1`.

Contract checks: the quote and reservation shapes belong to `go-contract-test`. Until those checks exist for both clients, "stubbed responses match the real services" is an open question. Real connection failures and timeouts are proven in `go-integration-test` and `go-chaos-test`; a `SaveErr` field proves only how dispatch reacts to an error.
