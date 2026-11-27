# Pact Tests: Consumer, Provider and Provider States

Self-contained. Copy for every direct request/response call between two services, at every product size. Every file starts with `//go:build pact`, so `make ci` never compiles it; the daily run does (`./workflows.md`). Compiled and run on Go 1.27.4 with pact-go v2.9.1 (native library `pact_ffi` 0.5.12) against Pact Broker 2.124.0 (the code is the lean example's; replace the names).

Name every test `TestPact...` and every file `*_pact_test.go`: the make targets select them with `-run '^TestPact'`.

## Consumer test: adapt

Beside the consumer's client. The **real client** runs against Pact's mock; the pact file in `./pacts` is a by-product, never written by hand. Record only the fields the consumer reads.

### `internal/signup/classesclient/client_pact_test.go`

```go
//go:build pact

package classesclient_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"testing"

	"github.com/pact-foundation/pact-go/v2/consumer"
	"github.com/pact-foundation/pact-go/v2/matchers"

	"example.com/studio/internal/signup/classesclient"
)

func newPact(t *testing.T) *consumer.V4HTTPMockProvider {
	t.Helper()
	pact, err := consumer.NewV4Pact(consumer.MockHTTPProviderConfig{
		Consumer: "signup",
		Provider: "classes",
		PactDir:  "../../../pacts",
	})
	if err != nil {
		t.Fatalf("start Pact: %v", err)
	}
	return pact
}

func TestPactSignupReadsAnOpenClass(t *testing.T) {
	err := newPact(t).
		AddInteraction().
		Given("class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 is open with 4 seats left").
		UponReceiving("a request for an open class").
		WithRequest(http.MethodGet, "/v1/classes/"+salsa).
		WillRespondWith(http.StatusOK, func(b *consumer.V4ResponseBuilder) {
			// Only the fields sign-up reads. The status is matched against the
			// values sign-up understands, not just "some string".
			b.Header("Content-Type", matchers.S("application/json")).
				JSONBody(matchers.Map{
					"id":        matchers.S(salsa),
					"title":     matchers.Like("Salsa for beginners"),
					"status":    matchers.Regex("open", "^(open|full|cancelled)$"),
					"seatsLeft": matchers.Integer(4),
				})
		}).
		ExecuteTest(t, func(server consumer.MockServerConfig) error {
			client := classesclient.Client{BaseURL: fmt.Sprintf("http://%s:%d", server.Host, server.Port), HTTP: http.DefaultClient}
			class, err := client.Class(context.Background(), salsa)
			if err != nil {
				return err
			}
			if !class.Bookable() || class.SeatsLeft != 4 {
				return fmt.Errorf("class = %+v, want a bookable class with 4 seats", class)
			}
			return nil
		})
	if err != nil {
		t.Fatal(err)
	}
}

func TestPactSignupLearnsAClassIsMissing(t *testing.T) {
	err := newPact(t).
		AddInteraction().
		Given("no class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 exists").
		UponReceiving("a request for a class that does not exist").
		WithRequest(http.MethodGet, "/v1/classes/"+salsa).
		WillRespondWith(http.StatusNotFound).
		ExecuteTest(t, func(server consumer.MockServerConfig) error {
			client := classesclient.Client{BaseURL: fmt.Sprintf("http://%s:%d", server.Host, server.Port), HTTP: http.DefaultClient}
			if _, err := client.Class(context.Background(), salsa); !errors.Is(err, classesclient.ErrNotFound) {
				return fmt.Errorf("err = %v, want ErrNotFound", err)
			}
			return nil
		})
	if err != nil {
		t.Fatal(err)
	}
}
```

## Provider verification: adapt

Beside the provider's router. The verifier replays each recorded request against the **real router**. Each `Given(...)` text from the consumer must be a key of the handler map, character for character.

### `internal/classes/provider_pact_test.go`

```go
//go:build pact

package classes_test

import (
	"context"
	"errors"
	"fmt"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/pact-foundation/pact-go/v2/models"
	"github.com/pact-foundation/pact-go/v2/provider"

	"example.com/studio/internal/classes"
)

// stateStore is the provider's data for one verification run. Each Provider
// State replaces its content, so no interaction depends on an earlier one.
type stateStore struct {
	mu      sync.Mutex
	ready   bool
	classes map[string]classes.Class
}

func (s *stateStore) Find(_ context.Context, id string) (classes.Class, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.ready {
		return classes.Class{}, false, errors.New("no Provider State handler ran for this interaction")
	}
	class, found := s.classes[id]
	return class, found, nil
}

// forget runs before every interaction. Until a state handler calls set, the
// provider fails every request, so an interaction whose state name matches no
// handler cannot pass by accident.
func (s *stateStore) forget() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ready, s.classes = false, nil
	return nil
}

func (s *stateStore) set(all ...classes.Class) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ready, s.classes = true, map[string]classes.Class{}
	for _, class := range all {
		s.classes[class.ID] = class
	}
}

// states maps each Provider State name, exactly as the consumer wrote it, to
// its setup. It is built per test, so setup code has the store it needs.
func states(store *stateStore) models.StateHandlers {
	return models.StateHandlers{
		"class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 is open with 4 seats left": func(setup bool, _ models.ProviderState) (models.ProviderStateResponse, error) {
			if setup {
				store.set(classes.Class{ID: salsa, Title: "Salsa for beginners", Status: "open", SeatsLeft: 4})
			}
			return nil, nil
		},
		"no class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 exists": func(setup bool, _ models.ProviderState) (models.ProviderStateResponse, error) {
			if setup {
				store.set()
			}
			return nil, nil
		},
	}
}

func TestPactClassesHonoursItsConsumers(t *testing.T) {
	store := &stateStore{}
	server := httptest.NewServer(classes.NewRouter(store))
	defer server.Close()

	wipSince := time.Now().AddDate(0, 0, -14)
	request := provider.VerifyRequest{
		Provider:        "classes",
		ProviderBaseURL: server.URL,
		ProviderVersion: mustEnv(t, "GIT_SHA"),
		ProviderBranch:  mustEnv(t, "GIT_BRANCH"),
		BrokerURL:       mustEnv(t, "PACT_BROKER_URL"),
		BrokerUsername:  os.Getenv("PACT_BROKER_USERNAME"),
		BrokerPassword:  os.Getenv("PACT_BROKER_PASSWORD"),
		ConsumerVersionSelectors: []provider.Selector{
			&provider.ConsumerVersionSelector{MainBranch: true},
			&provider.ConsumerVersionSelector{MatchingBranch: true},
			&provider.ConsumerVersionSelector{DeployedOrReleased: true},
		},
		EnablePending:        true,
		IncludeWIPPactsSince: &wipSince,
		FailIfNoPactsFound:   true,
		// Results are recorded only by the scheduled run, never from a laptop.
		PublishVerificationResults: os.Getenv("PACT_PUBLISH_RESULTS") == "true",
		BeforeEach:                 store.forget,
		StateHandlers:              states(store),
	}
	if err := provider.NewVerifier().VerifyProvider(t, request); err != nil {
		t.Fatalf("a consumer's expectation is not met: %v", err)
	}
}

func mustEnv(t *testing.T, name string) string {
	t.Helper()
	value := os.Getenv(name)
	if value == "" {
		t.Fatal(fmt.Sprintf("%s is not set; the verification would not know what it is recording", name))
	}
	return value
}
```

When the provider reads from PostgreSQL, a state handler seeds **real, committed rows scoped to that state** (`test-fixture-design`), because the verifier's request arrives on another connection and cannot see an open transaction; `forget` then deletes exactly those rows.

## When the provider checks a token: adapt

Most providers sit behind token-checking middleware. The verifier replays the header the consumer recorded, and the real middleware rejects it: the run fails with `expected 200 but was 401`, buried among body and header mismatches. The fix keeps the **real router and the real middleware** and changes one thing only: the key they trust is made for this run, and a request filter swaps the recorded example token for one signed with it. Run on Go 1.27.4 with pact-go v2.9.1, chi v5.2.3 and golang-jwt v5.3.0 against an RS256 middleware checking signature, issuer, audience, expiry and scope. `classes.TokenRules` is this example's own way of handing the router its key and rules; use the provider's.

### Consumer: add to `client_pact_test.go`

```go
const (
	// exampleToken has the shape of a token and is not one: no key signed it,
	// so the pact file holds no credential.
	exampleToken = "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJleGFtcGxlIn0.c2lnbmF0dXJl"
	bearerShape  = `^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$`
)

// Regex on the shape: the mock then refuses a request with no token.
// Like would accept any string at all.
func withToken(b *consumer.V4RequestBuilder) {
	b.Header("Authorization", matchers.Regex("Bearer "+exampleToken, bearerShape))
}

// Every interaction that needs a token: .WithRequest(http.MethodGet, "/v1/classes/"+salsa, withToken)

// No header is recorded, so verification sends none.
func TestPactSignupIsRefusedWithoutAToken(t *testing.T) {
	err := newPact(t).
		AddInteraction().
		Given("class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 is open with 4 seats left").
		UponReceiving("a request for an open class without a token").
		WithRequest(http.MethodGet, "/v1/classes/"+salsa).
		WillRespondWith(http.StatusUnauthorized).
		ExecuteTest(t, func(server consumer.MockServerConfig) error {
			if _, err := clientFor(server, "").Class(context.Background(), salsa); !errors.Is(err, classesclient.ErrUnauthorized) {
				return fmt.Errorf("err = %v, want ErrUnauthorized", err)
			}
			return nil
		})
	if err != nil {
		t.Fatal(err)
	}
}

// One Provider State carries both facts: BeforeEach runs again before every
// state of an interaction, so a second Given would undo the first.
func TestPactSignupIsRefusedWithAnExpiredToken(t *testing.T) {
	err := newPact(t).
		AddInteraction().
		Given("class 7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11 is open with 4 seats left and the caller's token has expired").
		UponReceiving("a request for an open class with an expired token").
		WithRequest(http.MethodGet, "/v1/classes/"+salsa, withToken).
		WillRespondWith(http.StatusUnauthorized).
		ExecuteTest(t, func(server consumer.MockServerConfig) error {
			if _, err := clientFor(server, exampleToken).Class(context.Background(), salsa); !errors.Is(err, classesclient.ErrUnauthorized) {
				return fmt.Errorf("err = %v, want ErrUnauthorized", err)
			}
			return nil
		})
	if err != nil {
		t.Fatal(err)
	}
}
```

`clientFor(server, token)` builds the real client with that token; an empty token sends no header.

### Provider: add to `provider_pact_test.go`

`stateStore` gains a `tokenExpired bool` that `forget` clears, `set(tokenExpired, classes...)` writes and `expired()` reads; the expired-token state calls `store.set(true, …)`, every other state `store.set(false, …)`.

```go
// signToken signs with the key made for this run; it carries what the
// consumer's real token carries.
func signToken(t *testing.T, key *rsa.PrivateKey, expiry time.Time) string {
	signed, err := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": issuer, "aud": audience, "sub": "signup", "scope": "classes:read", "exp": expiry.Unix(),
	}).SignedString(key)
	if err != nil {
		t.Errorf("sign the test token: %v", err)
	}
	return signed
}

// replaceToken swaps the recorded example token for one signed in this run.
// It never adds a header: a request recorded without a token is sent bare.
func replaceToken(t *testing.T, key *rsa.PrivateKey, store *stateStore) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Authorization") != "" {
				expiry := time.Now().Add(5 * time.Minute)
				if store.expired() {
					expiry = time.Now().Add(-time.Minute)
				}
				r.Header.Set("Authorization", "Bearer "+signToken(t, key, expiry))
			}
			next.ServeHTTP(w, r)
		})
	}
}

// In TestPactClassesHonoursItsConsumers, before the VerifyRequest:
//
//	key, err := rsa.GenerateKey(rand.Reader, 2048) // exists only for this run
//	...
//	server := httptest.NewServer(classes.NewRouter(store, classes.TokenRules{
//		Key: &key.PublicKey, Issuer: issuer, Audience: audience, Scope: "classes:read",
//	}))
//
// and in the VerifyRequest:
//
//	RequestFilter: replaceToken(t, key, store),
```

### What was seen with a token

| Situation | Result |
|---|---|
| Real middleware, no request filter | Fails, exit 1: `expected 200 but was 401` |
| The filter above, key made per run | Passes. A provider demanding another audience still fails with 401, another scope with 403 |
| **Token middleware removed or bypassed in the test router** | **Passes**, also for a pact with no token at all. Only the two refusal interactions notice (`expected 401 but was 200`) |
| A filter that always sets the header | **Passes for a consumer that never sends a token**; the "no token" interaction is what goes red |
| "Expired token → 401" with no filter | **Passes for the wrong reason** (the example token is unsigned) and stays green when the provider stops checking claims |
| The same with the filter signing an expired token | Goes red when the provider stops checking expiry |
| A working token recorded in the pact | The pact file, and the broker, then hold a credential |
| Header matched with `Like` | The mock accepts `Bearer not a token at all` |
| Two `Given` states on one interaction | The second setup wiped the first (`expected 401 but was 500`): `BeforeEach` runs before each state |
| Provider drops only its audience check | **Stays green**: no interaction covers it. Pact proves a check only where a refusal interaction exists |

The filter runs for interaction requests only, never for the Provider State call. `CustomProviderHeaders` does not exist in v2.9.1 (compile error); `RequestFilter` is the only header option. A state handler can also return the token for a consumer that recorded the header with `matchers.FromProviderState`; it works, but the consumer must opt in and the rule weakens to "any string", so the filter is the default here.

## What was seen

| Situation | Result |
|---|---|
| Broker holds no pact, `FailIfNoPactsFound: true` | Test fails: `No pacts found for provider` |
| Broker holds no pact, `FailIfNoPactsFound: false` | **Test passes**; one `ERROR` log line is the only sign |
| Provider renames a field the consumer reads (pact verified before on `main`) | Test fails, exit 1; the failed result is recorded |
| Consumer adds an expectation the provider does not meet, `EnablePending: true` | **Test passes**, exit 0, printing `Pending Failures`; the failed result is recorded, and `can-i-deploy` refuses the consumer |
| The same with `EnablePending: false` | Test fails |
| Consumer publishes from a feature branch; `IncludeWIPPactsSince` set | The pact is verified as "work in progress"; a failure is printed and does not fail the test |
| A state name with no handler, no `BeforeEach` guard | The request runs with no setup. The "nothing exists" interaction **passed** by accident |
| The same with the `forget` guard above | Fails: expected `404` but was `500` |
| Provider starts returning `waitlist`; consumer matched `status` with `Regex` | Fails: `Expected 'waitlist' to match '^(open|full|cancelled)$'` |
| The same, consumer matched `status` with `Like("open")` | **Passes**: a type-only matcher accepts any string |

## Setup notes

- `go install github.com/pact-foundation/pact-go/v2@v2.9.1` gives a binary named `pact-go`; `pact-go install` downloads the native library to `/usr/local/lib` (needs `sudo`) or to `-d <folder>`. It also writes `~/.pact/pact-go.yml`.
- Building needs cgo and a C compiler. With `-d`, pass `CGO_LDFLAGS=-L<folder>` and make the folder known to the loader. On macOS the official `go` binary dropped `DYLD_LIBRARY_PATH`, and the installer's rename step failed for a long folder path; `go test -exec "env DYLD_LIBRARY_PATH=<folder>"` worked. The Linux install path was not run for this skill.
- Set `PACT_DO_NOT_TRACK=true` wherever Pact runs, a laptop included: the native library otherwise sends anonymous usage events (its version, the operating system).
- Message pacts are not used: events are checked by schema (`./event-contract-tests.md`).
