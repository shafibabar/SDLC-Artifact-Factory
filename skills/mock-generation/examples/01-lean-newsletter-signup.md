# Lean: Newsletter Sign-up (one Go service, no tenancy)

**Unverified:** no Go toolchain was available; this code has not been compiled or run.

## Input

> "Test the sign-up handler. Mock the database and check `Save` is called once, and check the welcome email goes out. It's a tiny app, keep it simple."

## Output

| Dependency | Class | Double | Assert |
|---|---|---|---|
| `SubscriberRepository` | Managed: our table | Fake | Stored state |
| `WelcomeSender` | Unmanaged: email leaves the app | moq mock | One call, to the new address |

Refused: the database mock and "`Save` called once". The repository is ours, so the test reads the subscriber back; a call count would still pass if the wrong data were saved. Small size means one fake and one mock, not different rules.

```go
// internal/test/fakes/subscriber_repo.go
// Keyed by email. Exists reports false for an unknown address.
type SubscriberRepo struct{ byEmail map[string]domain.Subscriber }

func NewSubscriberRepo() *SubscriberRepo {
	return &SubscriberRepo{byEmail: map[string]domain.Subscriber{}}
}

func (r *SubscriberRepo) Save(_ context.Context, s domain.Subscriber) error {
	r.byEmail[s.Email] = s // a copy: Subscriber holds no slices or maps
	return nil
}

func (r *SubscriberRepo) Exists(_ context.Context, email string) (bool, error) {
	_, ok := r.byEmail[email]
	return ok, nil
}

var _ signup.SubscriberRepository = (*SubscriberRepo)(nil)
```

```go
// internal/signup/ports.go
//go:generate go run github.com/matryer/moq@v0.8.1 -out welcome_sender_moq.go . WelcomeSender
type WelcomeSender interface {
	SendWelcome(ctx context.Context, email string) error
}
```

```go
// internal/signup/service_test.go (package signup_test)
func TestSignUp_StoresSubscriberAndSendsOneWelcome(t *testing.T) {
	repo := fakes.NewSubscriberRepo()
	sender := &signup.WelcomeSenderMock{
		SendWelcomeFunc: func(context.Context, string) error { return nil },
	}
	service := signup.NewService(repo, sender)

	err := service.SignUp(context.Background(), "ana@example.test")

	require.NoError(t, err)
	stored, err := repo.Exists(context.Background(), "ana@example.test")
	require.NoError(t, err)
	require.True(t, stored)
	calls := sender.SendWelcomeCalls()
	require.Len(t, calls, 1)
	require.Equal(t, "ana@example.test", calls[0].Email)
}

func TestSignUp_ExistingAddressSendsNothing(t *testing.T) {
	repo := fakes.NewSubscriberRepo()
	require.NoError(t, repo.Save(context.Background(), domain.Subscriber{Email: "ana@example.test"}))
	sender := &signup.WelcomeSenderMock{} // SendWelcomeFunc is nil: a send panics and fails the test
	service := signup.NewService(repo, sender)

	err := service.SignUp(context.Background(), "ana@example.test")

	require.ErrorIs(t, err, signup.ErrAlreadySubscribed)
	require.Empty(t, sender.SendWelcomeCalls())
}
```

The fake gets a behaviour suite (`../references/keeping-fakes-honest.md`) run against it and against the real repository. The mock verifies nothing by itself: without the `SendWelcomeCalls` assertions a missing email would pass. The coverage filter excludes files ending `_moq.go` by name (`grep -v '_moq\.go:'` on the profile), so `welcome_sender_moq.go` is out and listed in the exclusion register; the fake is counted. A filter matching only `_mock.go` must be corrected to `_moq.go`.
