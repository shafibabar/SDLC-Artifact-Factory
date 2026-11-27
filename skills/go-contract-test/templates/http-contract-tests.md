# HTTP Contract Tests: Harness and Skeletons

Self-contained. Copy when a Go service provides or calls an HTTP API. These tests have no build tag: they run in `make ci` on every pull request and count towards the coverage gates. Compiled and run on Go 1.27.4 with kin-openapi v0.153.0 (the code is the lean example's; replace `classes`, `signup` and the module path with the product's names).

## Contents

Harness (`spec.go`, `double.go`), provider conformance test, consumer test, what each one fails on.

## Harness: copy unchanged into `internal/test/contract/`

It is test support, so it sits in the module's `internal/test/` folder (left out of coverage as the approved class; nothing that ships may import it).

### `internal/test/contract/spec.go`

```go
// Package contract is test support for contract tests: it checks real
// responses against an OpenAPI description. It must never be imported by
// code that ships.
package contract

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"sort"
	"strconv"
	"sync"
	"testing"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers"
	"github.com/getkin/kin-openapi/routers/gorillamux"
)

// Spec is a loaded OpenAPI description plus a record of which documented
// responses a test run has exercised.
type Spec struct {
	doc    *openapi3.T
	router routers.Router
	mu     sync.Mutex
	seen   map[string]bool
}

// LoadSpec reads and validates the description. Server entries are dropped,
// so a request matches by path whatever host the test uses.
func LoadSpec(path string) (*Spec, error) {
	doc, err := openapi3.NewLoader().LoadFromFile(path)
	if err != nil {
		return nil, fmt.Errorf("load %s: %w", path, err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		return nil, fmt.Errorf("%s is not a valid OpenAPI description: %w", path, err)
	}
	if doc.Paths == nil || doc.Paths.Len() == 0 {
		return nil, fmt.Errorf("%s documents no paths; nothing could be checked", path)
	}
	doc.Servers = nil
	router, err := gorillamux.NewRouter(doc)
	if err != nil {
		return nil, fmt.Errorf("route %s: %w", path, err)
	}
	return &Spec{doc: doc, router: router, seen: map[string]bool{}}, nil
}

// Check sends the request through the handler and fails the test unless the
// response is one the description documents. It returns the recorded response
// so the test can assert values as well.
func (s *Spec) Check(t testing.TB, handler http.Handler, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if err := s.Validate(req, rec.Code, rec.Header(), rec.Body.Bytes()); err != nil {
		t.Errorf("%s %s: %v", req.Method, req.URL.Path, err)
	}
	return rec
}

// Validate reports why a response to the request is not what the description
// documents. It is stricter than the library alone: the status must be
// documented explicitly (a "default" entry does not count), and a body is
// accepted only where a schema exists to check it against.
func (s *Spec) Validate(req *http.Request, status int, header http.Header, body []byte) error {
	route, params, err := s.router.FindRoute(req)
	if err != nil {
		return fmt.Errorf("request is not in the description: %w", err)
	}
	documented := route.Operation.Responses.Value(strconv.Itoa(status))
	if documented == nil || documented.Value == nil {
		return fmt.Errorf("status %d is not documented for this operation", status)
	}
	if len(body) > 0 {
		media := documented.Value.Content.Get(header.Get("Content-Type"))
		if media == nil || media.Schema == nil {
			return fmt.Errorf("status %d has a body, but the description gives no schema for content type %q",
				status, header.Get("Content-Type"))
		}
	}
	input := &openapi3filter.ResponseValidationInput{
		RequestValidationInput: &openapi3filter.RequestValidationInput{Request: req, PathParams: params, Route: route},
		Status:                 status,
		Header:                 header,
		Body:                   io.NopCloser(bytes.NewReader(body)),
		Options: &openapi3filter.Options{
			IncludeResponseStatus: true,
			MultiError:            true,
			SchemaValidationOptions: []openapi3.SchemaValidationOption{
				openapi3.WithStringFormatValidator("uuid",
					openapi3.NewRegexpFormatValidator(openapi3.FormatOfStringForUUIDOfRFC4122)),
			},
		},
	}
	if err := openapi3filter.ValidateResponse(context.Background(), input); err != nil {
		return fmt.Errorf("status %d does not match the description: %w", status, err)
	}
	s.mu.Lock()
	s.seen[key(req.Method, route.Path, strconv.Itoa(status))] = true
	s.mu.Unlock()
	return nil
}

// Unexercised lists every documented operation and status that no Validate
// call has passed for. A "default" entry is listed too: it can never be
// exercised, so it has to be replaced by the statuses it stands for.
func (s *Spec) Unexercised() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	var missing []string
	for path, item := range s.doc.Paths.Map() {
		for method, operation := range item.Operations() {
			for status := range operation.Responses.Map() {
				if k := key(method, path, status); !s.seen[k] {
					missing = append(missing, k)
				}
			}
		}
	}
	sort.Strings(missing)
	return missing
}

func key(method, path, status string) string { return method + " " + path + " " + status }
```

### `internal/test/contract/double.go`

```go
package contract

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
)

// Double stands in for a provider in a consumer's test. Every canned response
// is checked against the provider's description when it is added, so the
// consumer is never tested against a response the provider does not promise.
type Double struct {
	t      testing.TB
	spec   *Spec
	server *httptest.Server
	mu     sync.Mutex
	canned map[string]canned
}

type canned struct {
	status int
	body   string
}

// NewDouble starts the double; it stops when the test ends.
func NewDouble(t testing.TB, spec *Spec) *Double {
	t.Helper()
	d := &Double{t: t, spec: spec, canned: map[string]canned{}}
	d.server = httptest.NewServer(http.HandlerFunc(d.serve))
	t.Cleanup(d.server.Close)
	return d
}

// URL is the double's base address.
func (d *Double) URL() string { return d.server.URL }

// Respond makes the double answer method and path with the JSON body. It
// fails the test at once when the description does not allow that response.
func (d *Double) Respond(method, path string, status int, body string) {
	d.t.Helper()
	req := httptest.NewRequest(method, path, nil)
	header := http.Header{"Content-Type": []string{"application/json"}}
	if err := d.spec.Validate(req, status, header, []byte(body)); err != nil {
		d.t.Fatalf("canned response for %s %s is not allowed by the provider's description: %v", method, path, err)
	}
	d.mu.Lock()
	d.canned[method+" "+path] = canned{status: status, body: body}
	d.mu.Unlock()
}

func (d *Double) serve(w http.ResponseWriter, req *http.Request) {
	d.mu.Lock()
	answer, ok := d.canned[req.Method+" "+req.URL.Path]
	d.mu.Unlock()
	if !ok {
		d.t.Errorf("the consumer made a request the test did not prepare: %s %s", req.Method, req.URL.Path)
		w.WriteHeader(http.StatusNotImplemented)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(answer.status)
	_, _ = w.Write([]byte(answer.body))
}
```

## Provider conformance test: adapt

One file per provider package, named `<implementation>_contract_test.go`. It drives the **real router** with its real middleware and handlers. The data behind the port can be a fake store, as here, or the real database from `go-integration-test`'s harness; which behaviour is proved against the database is that skill's subject. Give every documented status a case: `TestMain` fails the package when one was never exercised.

### `internal/classes/router_contract_test.go`

```go
package classes_test

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"example.com/studio/internal/classes"
	"example.com/studio/internal/test/contract"
)

var spec *contract.Spec

func TestMain(m *testing.M) {
	var err error
	if spec, err = contract.LoadSpec("../../api/openapi.yaml"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	code := m.Run()
	// The completeness check needs every test to have run, so it is skipped
	// when -run selects some of them.
	wholePackage := flag.Lookup("test.run").Value.String() == ""
	if missing := spec.Unexercised(); code == 0 && wholePackage && len(missing) > 0 {
		fmt.Fprintln(os.Stderr, "FAIL: documented responses that no contract test exercised:")
		for _, line := range missing {
			fmt.Fprintln(os.Stderr, "  "+line)
		}
		code = 1
	}
	os.Exit(code)
}

const salsa = "7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11"

type fakeStore struct {
	classes map[string]classes.Class
	err     error
}

func (s fakeStore) Find(_ context.Context, id string) (classes.Class, bool, error) {
	class, found := s.classes[id]
	return class, found, s.err
}

func TestGetClassMatchesTheContract(t *testing.T) {
	store := fakeStore{classes: map[string]classes.Class{
		salsa: {ID: salsa, Title: "Salsa for beginners", Status: "open", SeatsLeft: 4},
	}}
	cases := []struct {
		name   string
		store  classes.Store
		id     string
		status int
		code   string
	}{
		{"found", store, salsa, http.StatusOK, ""},
		{"id is not a UUID", store, "salsa", http.StatusBadRequest, "INVALID_CLASS_ID"},
		{"unknown id", store, "00000000-0000-4000-8000-000000000000", http.StatusNotFound, "CLASS_NOT_FOUND"},
		{"store fails", fakeStore{err: errors.New("connection lost")}, salsa, http.StatusInternalServerError, "INTERNAL"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/v1/classes/"+tc.id, nil)
			rec := spec.Check(t, classes.NewRouter(tc.store), req)
			if rec.Code != tc.status {
				t.Fatalf("status = %d, want %d", rec.Code, tc.status)
			}
			var body struct {
				SeatsLeft int `json:"seatsLeft"`
				Error     struct {
					Code string `json:"code"`
				} `json:"error"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("decode: %v", err)
			}
			if body.Error.Code != tc.code {
				t.Errorf("error code = %q, want %q", body.Error.Code, tc.code)
			}
			if tc.status == http.StatusOK && body.SeatsLeft != 4 {
				t.Errorf("seatsLeft = %d, want 4", body.SeatsLeft)
			}
		})
	}
}
```

## Consumer test: adapt

One file beside the consumer's client. The **real client** runs against the double; each canned response is checked against the provider's description first, so the test cannot drift from what the provider promises. When the provider is in another repository, read a copy of its description fetched at the provider's deployed commit instead of a relative path.

### `internal/signup/classesclient/client_contract_test.go`

```go
package classesclient_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"example.com/studio/internal/signup/classesclient"
	"example.com/studio/internal/test/contract"
)

var providerSpec *contract.Spec

func TestMain(m *testing.M) {
	var err error
	// The provider's description, read from the provider's own file: the same
	// file its conformance test and the breaking-change check use.
	if providerSpec, err = contract.LoadSpec("../../../api/openapi.yaml"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	os.Exit(m.Run())
}

const salsa = "7b0e3a52-6c1d-4f6e-9a57-2f1c5f0d9b11"

func TestClientReadsAnOpenClass(t *testing.T) {
	provider := contract.NewDouble(t, providerSpec)
	// An extra field the client does not know proves it tolerates additions.
	provider.Respond(http.MethodGet, "/v1/classes/"+salsa, http.StatusOK,
		`{"id":"`+salsa+`","title":"Salsa for beginners","status":"open","seatsLeft":4,"note":"bring water"}`)
	client := classesclient.Client{BaseURL: provider.URL(), HTTP: http.DefaultClient}

	class, err := client.Class(context.Background(), salsa)
	if err != nil {
		t.Fatalf("Class: %v", err)
	}
	// Values, not just "no error": a field the provider stopped sending
	// decodes to zero without any error.
	want := classesclient.Class{ID: salsa, Title: "Salsa for beginners", Status: "open", SeatsLeft: 4}
	if class != want {
		t.Errorf("class = %+v, want %+v", class, want)
	}
	if !class.Bookable() {
		t.Error("an open class with seats must be bookable")
	}
}

func TestClientReportsAMissingClass(t *testing.T) {
	provider := contract.NewDouble(t, providerSpec)
	provider.Respond(http.MethodGet, "/v1/classes/"+salsa, http.StatusNotFound,
		`{"error":{"code":"CLASS_NOT_FOUND","message":"no class has this id"}}`)
	client := classesclient.Client{BaseURL: provider.URL(), HTTP: http.DefaultClient}

	if _, err := client.Class(context.Background(), salsa); !errors.Is(err, classesclient.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

// A status the description does not list yet. The double would refuse it, so
// this one test uses a plain server on purpose: it proves the client survives
// a value added later.
func TestClientTreatsAnUnknownStatusAsNotBookable(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"id":"`+salsa+`","title":"Salsa","status":"waitlist","seatsLeft":2}`)
	}))
	defer server.Close()
	client := classesclient.Client{BaseURL: server.URL, HTTP: http.DefaultClient}

	class, err := client.Class(context.Background(), salsa)
	if err != nil {
		t.Fatalf("Class: %v", err)
	}
	if class.Bookable() {
		t.Error("a class with an unknown status must not be bookable")
	}
}
```

## What was seen to fail

Each line is a change made once to the lean example, with the test that went red.

| Change | Result |
|---|---|
| Provider renames `seatsLeft` | Conformance: `missing property 'seatsLeft'` |
| Provider answers `410` where `404` is documented | Conformance: `status 410 is not documented for this operation` |
| Provider returns a status value outside the enum | Conformance: `value must be one of 'open', 'full', 'cancelled'` |
| The `500` case is removed from the test | Package fails: `documented responses that no contract test exercised: GET /v1/classes/{id} 500` |
| Consumer's canned response lacks a required field | Consumer test fails at `Respond`: not allowed by the provider's description |
| Consumer reads `seats_left` instead of `seatsLeft` | Value assertion: `SeatsLeft:0`, want `4`. Decoding itself reported no error |

## Limits to state

- The library skips validation for statuses 301, 304, 307 and 308 and for every `HEAD` request (read in kin-openapi v0.153.0's source, not run). The harness still requires the status to be documented.
- A field the provider adds without documenting it passes: response schemas stay open so that additions do not break readers.
- Only the `uuid` format is asserted beyond the library's defaults (`date-time` is checked by default). Add a validator for any other format the description relies on.
- `libopenapi-validator` is another library that can do this job; it was not run for this skill.
