# Standard: Ride Booking (payment provider, outbox, replacing gomock)

**Unverified:** no Go toolchain or database was available; this code has not been compiled or run.

## Input

> "Our `ConfirmRide` tests use gomock: `repo.EXPECT().Save(gomock.Any(), gomock.Any()).Times(1)` and `publisher.EXPECT().Publish(...)`. Move them to moq. Keep the publish expectation on the handler so we know the event goes out."

The service charges a payment provider and writes `ride_confirmed` to an outbox; a relay publishes it.

## Output

Plan, checked before any change:

| Port | Class | Current | New | Assert |
|---|---|---|---|---|
| `RideRepository` (writes the ride and its outbox row) | Managed | gomock, `Save` once | Fake | Ride status and outbox entry |
| `PaymentGateway.Charge` | Unmanaged: money moves outside | gomock | moq mock | One charge: ride, amount |
| `EventPublisher` in the handler | Not a handler dependency | gomock | Removed | None |
| `EventPublisher` in the relay | Unmanaged | none | moq mock | Published event |

Two requests change. The handler publish expectation is refused: with an outbox the handler publishes nothing, so the proof is the outbox row, plus the relay test. `Save().Times(1)` is replaced by reading the state. Every repository keeps a fake or a real database as the default; only the payment gateway and the relay's publisher are mocked.

```go
// internal/application/confirm_ride_test.go (package application_test)
func TestConfirmRide_ChargesOnceAndRecordsEvent(t *testing.T) {
	repo := fakes.NewRideRepo()
	requested := domain.Ride{ID: "ride-1", FareMinor: 1850, Status: domain.RideRequested}
	require.NoError(t, repo.Save(context.Background(), requested))
	gateway := &application.PaymentGatewayMock{
		ChargeFunc: func(context.Context, string, int64) error { return nil },
	}
	confirm := application.NewConfirmRide(repo, gateway)

	err := confirm.Handle(context.Background(), "ride-1")

	require.NoError(t, err)
	got, err := repo.ByID(context.Background(), "ride-1")
	require.NoError(t, err)
	require.Equal(t, domain.RideConfirmed, got.Status)
	outbox := repo.Outbox() // the fake's view of rows saved with rides
	require.Len(t, outbox, 1)
	require.Equal(t, "ride_confirmed", outbox[0].Type)
	require.Equal(t, "ride-1", outbox[0].RideID)
	charges := gateway.ChargeCalls()
	require.Len(t, charges, 1)
	require.Equal(t, "ride-1", charges[0].RideID)
	require.Equal(t, int64(1850), charges[0].AmountMinor)
}
```

```go
// internal/outbox/relay_test.go (package outbox_test)
func TestRelay_PublishesPendingRow(t *testing.T) {
	store := fakes.NewOutboxStore(outbox.Row{ID: "row-1", Type: "ride_confirmed", RideID: "ride-1"})
	publisher := &outbox.EventPublisherMock{
		PublishFunc: func(context.Context, outbox.Row) error { return nil },
	}
	relay := outbox.NewRelay(store, publisher)

	err := relay.DrainOnce(context.Background())

	require.NoError(t, err)
	published := publisher.PublishCalls()
	require.Len(t, published, 1)
	require.Equal(t, "row-1", published[0].Row.ID)
	require.Empty(t, store.Pending())
}
```

What the helpers do: `fakes.NewRideRepo` keeps rides and their outbox entries in memory, stores copies, and returns `domain.ErrNotFound` for an unknown ride. `Outbox` returns a copy of the entries. It cannot show that ride and row commit together: that is an integration test with a real commit (`test-fixture-design`). An unconfigured moq method panics and fails the test.

Then: remove the gomock directives and module dependency, run `go generate ./...`, run the validator and the freshness check. Correct a coverage or mutation filter that matches only `_mock.go` to `_moq.go`. The old controller failed a test automatically on a missing or extra call; moq does not, so each expectation that mattered is now a written assertion.
