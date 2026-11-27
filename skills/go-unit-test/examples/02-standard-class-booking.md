# Standard: Class Booking Cancellation

Self-contained input and output. All code compiled and run on Go 1.27.4 with moq 0.8.1 and testify 1.12.1; gate output is copied from the runs (gobco 1.3.4). Module `example.test/flexfit`.

## Input

> "Cancel a class booking. Late (under 12 hours) costs £2, or £5 if someone is waiting; premium members pay nothing. Check-in opens 15 minutes before. Mock the repository and check `Save` is called."

## Output

| Part | Kind | Proof |
|---|---|---|
| `booking` | Domain logic | Decision table (late x premium x waitlisted = 8 rules, none collapsed) and every state against every event |
| `application.CancelBooking` | Controller | One row per way it can end, with a fake and a mock |
| `fakes.BookingRepo` | Test support under `internal/test/`: outside the coverage gates as the approved class, listed in the report | Its own test |

Refused: the repository mock and "`Save` is called". The repository is ours, so the test reads the stored booking. The waitlist message leaves the application, so it gets a moq mock and call assertions.

```go
// file: internal/booking/booking.go
package booking

import (
	"errors"
	"time"
)

type State int

const (
	Booked State = iota + 1
	Cancelled
	Attended
)

const (
	LateWindow   = 12 * time.Hour
	EarlyCheckIn = 15 * time.Minute
	LateFee      = 200
	BlockingFee  = 500
)

var (
	ErrNotBooked = errors.New("booking: not in the booked state")
	ErrTooEarly  = errors.New("booking: check-in is not open yet")
)

type Booking struct {
	id       string
	startsAt time.Time
	premium  bool
	state    State
}

func New(id string, startsAt time.Time, premium bool) Booking {
	return Booking{id: id, startsAt: startsAt, premium: premium, state: Booked}
}

func (b Booking) ID() string   { return b.id }
func (b Booking) State() State { return b.state }

// Cancel releases the slot and returns the fee in pence.
func (b *Booking) Cancel(now time.Time, waitlisted bool) (int, error) {
	if b.state != Booked {
		return 0, ErrNotBooked
	}
	b.state = Cancelled
	late := b.startsAt.Sub(now) < LateWindow
	if !late || b.premium {
		return 0, nil
	}
	if waitlisted {
		return BlockingFee, nil
	}
	return LateFee, nil
}

func (b *Booking) CheckIn(now time.Time) error {
	if b.state != Booked {
		return ErrNotBooked
	}
	if now.Before(b.startsAt.Add(-EarlyCheckIn)) {
		return ErrTooEarly
	}
	b.state = Attended
	return nil
}
```

```go
// file: internal/booking/booking_test.go
package booking

import (
	"errors"
	"testing"
	"time"
)

var startsAt = time.Date(2026, 5, 4, 18, 0, 0, 0, time.UTC)

// Decision table: late, premium and waitlisted give 2*2*2 = 8 rules, none collapsed.
func TestBooking_Cancel_Fee(t *testing.T) {
	t.Parallel()
	late := startsAt.Add(-LateWindow + time.Nanosecond)
	onTime := startsAt.Add(-LateWindow) // the boundary itself is not late
	tests := []struct {
		name       string
		now        time.Time
		premium    bool
		waitlisted bool
		want       int
	}{
		{"late, standard, waitlisted", late, false, true, BlockingFee},
		{"late, standard, no waitlist", late, false, false, LateFee},
		{"late, premium, waitlisted", late, true, true, 0},
		{"late, premium, no waitlist", late, true, false, 0},
		{"on time, standard, waitlisted", onTime, false, true, 0},
		{"on time, standard, no waitlist", onTime, false, false, 0},
		{"on time, premium, waitlisted", onTime, true, true, 0},
		{"on time, premium, no waitlist", onTime, true, false, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			b := New("b-1", startsAt, tt.premium)
			got, err := b.Cancel(tt.now, tt.waitlisted)
			if err != nil || got != tt.want {
				t.Errorf("Cancel(%s, %t) = %d, %v, want %d, nil", tt.now, tt.waitlisted, got, err, tt.want)
			}
			if b.State() != Cancelled {
				t.Errorf("state = %d, want %d", b.State(), Cancelled)
			}
		})
	}
}

// State transitions: every state against every event, plus the early check-in guard.
func TestBooking_Transitions(t *testing.T) {
	t.Parallel()
	opens := startsAt.Add(-EarlyCheckIn)
	cancel := func(b *Booking) error { _, err := b.Cancel(opens, false); return err }
	checkIn := func(b *Booking) error { return b.CheckIn(opens) }
	tooEarly := func(b *Booking) error { return b.CheckIn(opens.Add(-time.Nanosecond)) }
	reach := map[State]func(*Booking) error{ // each starting state, reached by behaviour
		Booked:    func(*Booking) error { return nil },
		Cancelled: cancel,
		Attended:  checkIn,
	}
	tests := []struct {
		name    string
		from    State
		event   func(*Booking) error
		want    State
		wantErr error
	}{
		{"booked can cancel", Booked, cancel, Cancelled, nil},
		{"booked can check in when it opens", Booked, checkIn, Attended, nil},
		{"check-in before it opens is refused", Booked, tooEarly, Booked, ErrTooEarly},
		{"cancelled cannot cancel", Cancelled, cancel, Cancelled, ErrNotBooked},
		{"cancelled cannot check in", Cancelled, checkIn, Cancelled, ErrNotBooked},
		{"attended cannot cancel", Attended, cancel, Attended, ErrNotBooked},
		{"attended cannot check in", Attended, checkIn, Attended, ErrNotBooked},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			b := New("b-1", startsAt, false)
			if err := reach[tt.from](&b); err != nil {
				t.Fatalf("arrange state %d: %v", tt.from, err)
			}
			if err := tt.event(&b); !errors.Is(err, tt.wantErr) {
				t.Errorf("error = %v, want %v", err, tt.wantErr)
			}
			if b.State() != tt.want {
				t.Errorf("state = %d, want %d", b.State(), tt.want)
			}
		})
	}
}

func TestNew_StartsBookedWithItsID(t *testing.T) {
	t.Parallel()
	b := New("b-7", startsAt, false)
	if b.ID() != "b-7" || b.State() != Booked {
		t.Errorf("New = %q, %d, want %q, %d", b.ID(), b.State(), "b-7", Booked)
	}
}
```

```go
// file: internal/application/cancel.go
package application

import (
	"context"
	"fmt"
	"time"

	"example.test/flexfit/internal/booking"
)

type BookingRepository interface {
	ByID(ctx context.Context, id string) (booking.Booking, error)
	Waitlisted(ctx context.Context, id string) (bool, error)
	Save(ctx context.Context, b booking.Booking) error
}

//go:generate go run github.com/matryer/moq@v0.8.1 -out waitlist_notifier_moq.go . WaitlistNotifier
type WaitlistNotifier interface {
	SlotFreed(ctx context.Context, bookingID string) error
}

type CancelBooking struct {
	Repo     BookingRepository
	Notifier WaitlistNotifier
}

func (c CancelBooking) Handle(ctx context.Context, id string, now time.Time) (int, error) {
	b, err := c.Repo.ByID(ctx, id)
	if err != nil {
		return 0, fmt.Errorf("load booking %s: %w", id, err)
	}
	waitlisted, err := c.Repo.Waitlisted(ctx, id)
	if err != nil {
		return 0, fmt.Errorf("read waitlist for %s: %w", id, err)
	}
	fee, err := b.Cancel(now, waitlisted)
	if err != nil {
		return 0, fmt.Errorf("cancel booking %s: %w", id, err)
	}
	if err := c.Repo.Save(ctx, b); err != nil {
		return 0, fmt.Errorf("save booking %s: %w", id, err)
	}
	if waitlisted {
		if err := c.Notifier.SlotFreed(ctx, id); err != nil {
			return fee, fmt.Errorf("notify waitlist for %s: %w", id, err)
		}
	}
	return fee, nil
}
```

```go
// file: internal/test/fakes/booking_repo.go
package fakes

import (
	"context"
	"errors"

	"example.test/flexfit/internal/application"
	"example.test/flexfit/internal/booking"
)

var ErrNotFound = errors.New("fakes: booking not found")

// BookingRepo stores copies. Fail maps a method name to the error it returns.
// It is not safe for concurrent use: build one per test.
type BookingRepo struct {
	Fail    map[string]error
	Waiting map[string]bool
	rows    map[string]booking.Booking
}

func NewBookingRepo(seed ...booking.Booking) *BookingRepo {
	r := &BookingRepo{Fail: map[string]error{}, Waiting: map[string]bool{}, rows: map[string]booking.Booking{}}
	for _, b := range seed {
		r.rows[b.ID()] = b
	}
	return r
}

func (r *BookingRepo) ByID(_ context.Context, id string) (booking.Booking, error) {
	b, ok := r.rows[id]
	if !ok {
		return booking.Booking{}, ErrNotFound
	}
	return b, r.Fail["ByID"]
}

func (r *BookingRepo) Waitlisted(_ context.Context, id string) (bool, error) {
	return r.Waiting[id], r.Fail["Waitlisted"]
}

func (r *BookingRepo) Save(_ context.Context, b booking.Booking) error {
	if err := r.Fail["Save"]; err != nil {
		return err
	}
	r.rows[b.ID()] = b
	return nil
}

var _ application.BookingRepository = (*BookingRepo)(nil)
```

```go
// file: internal/test/fakes/booking_repo_test.go
package fakes_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"example.test/flexfit/internal/booking"
	"example.test/flexfit/internal/test/fakes"
)

// The branch gate counts only a package's own tests, so the fake has its own.
// The same promises are also run against the real repository in integration tests.
func TestBookingRepo(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	saved := booking.New("b-1", time.Date(2026, 5, 4, 18, 0, 0, 0, time.UTC), false)
	repo := fakes.NewBookingRepo(saved)

	got, err := repo.ByID(ctx, "b-1")
	require.NoError(t, err)
	require.Equal(t, saved, got)

	_, err = repo.ByID(ctx, "missing")
	require.ErrorIs(t, err, fakes.ErrNotFound)

	require.NoError(t, repo.Save(ctx, saved))
	repo.Fail["Save"] = errors.New("disk full")
	require.ErrorIs(t, repo.Save(ctx, saved), repo.Fail["Save"])

	waiting, err := repo.Waitlisted(ctx, "b-1")
	require.NoError(t, err)
	require.False(t, waiting)
}
```

```go
// file: internal/application/cancel_test.go
package application_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"example.test/flexfit/internal/application"
	"example.test/flexfit/internal/booking"
	"example.test/flexfit/internal/test/fakes"
)

func TestCancelBooking(t *testing.T) {
	t.Parallel()
	startsAt := time.Date(2026, 5, 4, 18, 0, 0, 0, time.UTC)
	late := startsAt.Add(-time.Hour)
	boom := errors.New("boom")

	tests := []struct {
		name      string
		id        string
		repoFails string
		cancelled bool
		waiting   bool
		sendErr   error
		wantErr   error
		wantFee   int
		wantState booking.State
		wantSends int
	}{
		{name: "late with a waitlist charges and notifies", id: "b-1", waiting: true,
			wantFee: booking.BlockingFee, wantState: booking.Cancelled, wantSends: 1},
		{name: "no waitlist sends nothing", id: "b-1",
			wantFee: booking.LateFee, wantState: booking.Cancelled},
		{name: "unknown booking", id: "nope", wantErr: fakes.ErrNotFound, wantState: booking.Booked},
		{name: "load fails", id: "b-1", repoFails: "ByID", wantErr: boom, wantState: booking.Booked},
		{name: "waitlist read fails", id: "b-1", repoFails: "Waitlisted", wantErr: boom, wantState: booking.Booked},
		{name: "already cancelled", id: "b-1", cancelled: true, waiting: true,
			wantErr: booking.ErrNotBooked, wantState: booking.Cancelled},
		{name: "save fails, nothing sent", id: "b-1", repoFails: "Save", waiting: true,
			wantErr: boom, wantState: booking.Booked},
		{name: "send fails after the save", id: "b-1", waiting: true, sendErr: boom,
			wantErr: boom, wantFee: booking.BlockingFee, wantState: booking.Cancelled, wantSends: 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			seed := booking.New("b-1", startsAt, false)
			if tt.cancelled {
				_, err := seed.Cancel(late, false)
				require.NoError(t, err)
			}
			repo := fakes.NewBookingRepo(seed) // managed: assert state
			repo.Waiting["b-1"] = tt.waiting
			if tt.repoFails != "" {
				repo.Fail[tt.repoFails] = boom
			}
			notifier := &application.WaitlistNotifierMock{ // unmanaged: assert calls
				SlotFreedFunc: func(context.Context, string) error { return tt.sendErr },
			}
			handler := application.CancelBooking{Repo: repo, Notifier: notifier}

			fee, err := handler.Handle(context.Background(), tt.id, late)

			require.ErrorIs(t, err, tt.wantErr)
			require.Equal(t, tt.wantFee, fee)
			delete(repo.Fail, "ByID") // read the stored state back
			stored, err := repo.ByID(context.Background(), "b-1")
			require.NoError(t, err)
			require.Equal(t, tt.wantState, stored.State())
			calls := notifier.SlotFreedCalls()
			require.Len(t, calls, tt.wantSends)
			for _, call := range calls {
				require.Equal(t, "b-1", call.BookingID)
			}
		})
	}
}
```

`go generate ./...` writes `internal/application/waitlist_notifier_moq.go`.

## Gate output

```text
excluded internal/test/fakes/booking_repo.go: test support (class approved by the product owner)
excluded internal/application/waitlist_notifier_moq.go: generated mock (by name)
Statement coverage: 33/33 statements, 0 block(s) not run
Branch coverage (gobco 1.3.4): 22/22 outcomes
```

The fake keeps its own test although the gates no longer count it: the application tests rely on its behaviour.

## What the answer says

- `Fail["ByID"]` makes the fake return that error; `Save` stores nothing when told to fail; the fake hands out copies and is built per test. The compile-time line checks signatures only: `mock-generation` requires the same promises to be run against the real repository.
- A moq mock verifies nothing by itself: the test asserts `SlotFreedCalls()`, including zero.
- "Send fails after the save" records current behaviour: the booking stays cancelled and the fee is returned with an error. Whether that is wanted is a decision for the product owner.
- Excluded: the generated mock, and `internal/test/fakes/booking_repo.go` as test support (approved class; no production file imports it). Unmeasured: `select`; `range` and zero-iteration loops; booleans outside conditions; functions without conditions.
- Run: `go test -race -shuffle=on`, both gates. Not run: the integration tests against a real database.
