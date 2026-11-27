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
- Message pacts are not used: events are checked by schema (`./event-contract-tests.md`).
