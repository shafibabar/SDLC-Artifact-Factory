# Lean: a Dance Studio's Class Sign-Up

Two Go services in one repository: `classes` serves the timetable, `signup` calls `GET /v1/classes/{id}` before taking a booking. No events, so no event checks. Lean means two services and one call; it still gets every check, **including Pact on a self-hosted broker**, because `signup` calls `classes` directly.

Run on 2026-11-28: Go 1.27.4 (darwin/arm64), oasdiff 1.39.0, kin-openapi v0.153.0, pact-go v2.9.1 with `pact_ffi` 0.5.12, `pactfoundation/pact-broker:3.2.0-pactbroker2.124.0` on `postgres:17-alpine`, `pactfoundation/pact-cli:1.5.0.5`. Not run: the GitHub Actions workflow files (their commands were run by hand in the same order).

## Plan

| Boundary | Every pull request | Daily |
|---|---|---|
| `classes` API description | `check-openapi-breaking.sh` against the deployed description | |
| `classes` as provider | Conformance test through the real router, every documented status | Pact verification of `signup`'s pact |
| `signup` as consumer | Real client against a double checked against the description | Pact consumer test, pact published |
| Deployment of either | | `can-i-deploy` before, `record-deployment` after |

Size of the broker at lean: one `pact-broker` container and one small PostgreSQL database, self-hosted. Nothing paid.

## Files

`internal/test/contract/spec.go` and `double.go`, the two contract tests, the two Pact tests, both workflows and the make targets are the files in `../templates/http-contract-tests.md`, `../templates/pact-tests.md` and `../templates/workflows.md`, unchanged: those templates were cut from this example.

### `api/openapi.yaml`

```yaml
openapi: 3.1.0
info:
  title: Classes API
  version: 1.0.0
paths:
  /v1/classes/{id}:
    get:
      operationId: getClass
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string, format: uuid }
      responses:
        "200":
          description: The class.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Class" }
        "400":
          description: The id is not a UUID.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
        "404":
          description: No class has this id.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
        "500":
          description: Unexpected failure.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
components:
  schemas:
    Class:
      type: object
      required: [id, title, status, seatsLeft]
      properties:
        id: { type: string, format: uuid }
        title: { type: string }
        status: { type: string, enum: [open, full, cancelled] }
        seatsLeft: { type: integer, minimum: 0 }
        note: { type: string }
    Error:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string }
            message: { type: string }
```

### `internal/classes/router.go`

```go
// Package classes serves the dance classes a studio offers.
package classes

import (
	"context"
	"encoding/json"
	"net/http"
	"regexp"

	"github.com/go-chi/chi/v5"
)

// Class is one scheduled dance class.
type Class struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	SeatsLeft int    `json:"seatsLeft"`
	Note      string `json:"note,omitempty"`
}

// Store is the port the handler reads classes through.
type Store interface {
	Find(ctx context.Context, id string) (Class, bool, error)
}

var uuidShape = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// NewRouter returns the service's real router.
func NewRouter(store Store) http.Handler {
	r := chi.NewRouter()
	r.Get("/v1/classes/{id}", func(w http.ResponseWriter, req *http.Request) {
		id := chi.URLParam(req, "id")
		if !uuidShape.MatchString(id) {
			writeError(w, http.StatusBadRequest, "INVALID_CLASS_ID", "the class id is not a UUID")
			return
		}
		class, found, err := store.Find(req.Context(), id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "INTERNAL", "unexpected failure")
			return
		}
		if !found {
			writeError(w, http.StatusNotFound, "CLASS_NOT_FOUND", "no class has this id")
			return
		}
		writeJSON(w, http.StatusOK, class)
	})
	return r
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": message}})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
```

### `internal/signup/classesclient/client.go`

```go
// Package classesclient is the sign-up service's client for the classes service.
package classesclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
)

// ErrNotFound reports that the classes service has no such class.
var ErrNotFound = errors.New("class not found")

// Class holds only the fields the sign-up service reads.
type Class struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Status    string `json:"status"`
	SeatsLeft int    `json:"seatsLeft"`
}

// Bookable is true only for a status this service knows to be open.
// A status added later is treated as not bookable.
func (c Class) Bookable() bool { return c.Status == "open" && c.SeatsLeft > 0 }

// Client calls the classes service.
type Client struct {
	BaseURL string
	HTTP    *http.Client
}

// Class fetches one class.
func (c Client) Class(ctx context.Context, id string) (Class, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.BaseURL+"/v1/classes/"+id, nil)
	if err != nil {
		return Class{}, err
	}
	req.Header.Set("Accept", "application/json")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return Class{}, err
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusOK:
		var class Class
		if err := json.NewDecoder(resp.Body).Decode(&class); err != nil {
			return Class{}, fmt.Errorf("decode class: %w", err)
		}
		return class, nil
	case http.StatusNotFound:
		return Class{}, ErrNotFound
	default:
		return Class{}, fmt.Errorf("classes service answered %d", resp.StatusCode)
	}
}
```

The client here is written by hand to keep the example short; a product generates it from the same description (`go-openapi-codegen`).

## Every pull request

```text
$ go test -race -shuffle=on -count=1 ./...
ok      example.com/studio/internal/classes
ok      example.com/studio/internal/signup/classesclient

$ ./scripts/check-openapi-breaking.sh --base deployed-openapi.yaml --revision api/openapi.yaml   # after removing the optional field `note`
exceptions in force: 0
error   [response-optional-property-removed] in API GET /v1/classes/{id}
        removed the optional property `note` from the response with the `200` status
FAIL: breaking change. Keep the change additive, or publish it as a new major version beside the old one.
RESULT: FAIL                                                                                       # exit 1
```

The same removal with plain `oasdiff breaking --fail-on WARN` exits 0: oasdiff rates it as information. The shipped severity file is what turns it into a failure. Failing test runs for a broken provider and a broken consumer are listed in `../templates/http-contract-tests.md`.

## The daily Pact run

```text
$ make pact-consumer
ok      example.com/studio/internal/signup/classesclient
$ pact-broker publish /pacts --consumer-app-version 4e1f9ab --branch main
Created signup version 4e1f9ab with branch main
Pact successfully published for signup version 4e1f9ab and provider classes.
$ make pact-provider
ok      example.com/studio/internal/classes
$ ./scripts/write-pact-impact-report.sh --product step-studio --date 2026-11-28 --results pact-results   # exit 0
```

The report it wrote (frontmatter and fixed text omitted):

```markdown
**Every check is verified.**

| Service | Environment | Result | What the broker said |
|---|---|---|---|
| classes | production | verified | All required verification results are published and successful |
| signup | production | verified | All required verification results are published and successful |

| Environment | Calling service | Called service | Verification |
|---|---|---|---|
| production | signup c1 | classes 4e1f9ab | passed |
| production | signup 4e1f9ab | classes p1 | passed |
```

(`c1` and `p1` are the versions recorded as deployed earlier in the session.)

## A breaking change, as it surfaced

For this run `classes` was changed to send `seats` in place of `seatsLeft`, and the daily run was started directly. (In a real pull request this particular change is caught sooner, by the conformance test. What reaches the daily run is a break the description cannot express: the specific values and combinations a consumer relies on, in Cruz and Prescott's words.)

```text
$ make pact-provider                                   # next daily run, commit p2
    +  "seats": 4,
There were 1 pact failures
--- FAIL: TestPactClassesHonoursItsConsumers
$ pact-broker can-i-deploy --pacticipant classes --version p2 --to-environment production
Computer says no
signup   | c1        | classes  | p2        | false    | 1
The verification for the pact between the version of signup currently in production (c1) and version p2 of classes failed
                                                       # exit 1: the deployment is refused
```

The pull request that made the change was **not** blocked by Pact. The break appeared in the next day's run and report, and the deployment check refused the commit.

## First deployment and unknown commits

```text
$ pact-broker can-i-deploy --pacticipant signup --version c1 --to-environment production
There is no verified pact between version c1 of signup and a version of classes currently in production
(no version is currently recorded as deployed/released in this environment)               # exit 1
$ pact-broker can-i-deploy --pacticipant classes --version p1 --to-environment production   # exit 0
$ pact-broker record-deployment --pacticipant classes --version p1 --environment production
$ pact-broker can-i-deploy --pacticipant signup --version c1 --to-environment production    # exit 0
$ pact-broker can-i-deploy --pacticipant classes --version p-unknown --to-environment production
No pacts or verifications have been published for version p-unknown of classes              # exit 1
```

So the provider deploys first, and a commit no Pact run has seen cannot deploy until `pact-daily` is started by hand for it.

## For the product owner

- The daily report is approved by the product owner (`artifacts/step-studio/quality/test-reports/pact-impact-2026-11-28.md`).
- No exception or retirement record exists yet; both files hold only their comment lines.
