# Enterprise: Ferry Ticketing with a Partner Travel Agency

`sailings` is a public REST API. A travel agency, Harbour Travel, calls it from its own systems and its own repository. Inside the product, `ticketing` calls `sailings` over gRPC, and `sailing.cancelled` is published to many consumers with no fixed deployment order (`FULL_TRANSITIVE`). Two environments: `staging` and `production`.

Run on 2026-11-28: Go 1.27.4 (darwin/arm64), oasdiff 1.39.0, buf 1.75.0, pact-go v2.9.1, Pact Broker 2.124.0, `pactfoundation/pact-cli:1.5.0.5`, Redpanda v26.2.7 schema registry. The Go code is the lean example's with the names changed (`classes` → `sailings`, `signup` → `harbour-travel`), compiled and run under those names. Not run: the workflow files on GitHub Actions; the gRPC status-code tests.

## Plan

| Boundary | Every pull request | Daily | Records |
|---|---|---|---|
| `sailings` REST description | Gate against the deployed description | | Exceptions, retirements |
| `sailings` as provider | Conformance through the real router | Verifies Harbour Travel's pact: main branch, matching branch, whatever is deployed; pending and work-in-progress pacts on | |
| Harbour Travel as consumer | Its own tests, in its repository | Publishes its pact from its own pipeline | Written agreement to run Pact |
| `ticketing` → `sailings` gRPC | `buf breaking`, category `FILE`, against the deployed commit | The Pact rule applies to this call too; pact-go needs a plugin for gRPC, which was not run for this skill, so the test strategy lists this call's consumer expectations as unverified | |
| `sailing.cancelled` | Declared mode `FULL_TRANSITIVE`, then the add-only pass | | |

A consumer outside the product is covered by Pact under the same rule as an internal one, and the other party must agree to run it. Harbour Travel publishes to the product's self-hosted broker with its own credentials. Had it declined, the boundary would have the description gate and conformance only, and the test strategy would say that the partner's real usage is unverified.

## Pact with two environments

```text
$ pact-broker create-environment --name staging --display-name Staging --no-production
Created staging environment in the Pact Broker

# first daily run, commit a81c3d0 on both sides; nothing deployed yet
$ make pact-provider
ok      example.com/ferry/internal/sailings
harbour-travel: not deployable to staging, see the report
harbour-travel: not deployable to production, see the report
$ ./scripts/write-pact-impact-report.sh ...                                    # exit 1
| harbour-travel | production | NOT VERIFIED | There is no verified pact between version a81c3d0 of harbour-travel and a version of sailings currently in production (no version is currently recorded as deployed/released in this environment) |

# provider first, then the consumer
$ pact-broker can-i-deploy --pacticipant sailings --version a81c3d0 --to-environment staging        # exit 0
$ pact-broker record-deployment --pacticipant sailings --version a81c3d0 --environment staging
$ pact-broker can-i-deploy --pacticipant sailings --version a81c3d0 --to-environment production     # exit 0
$ pact-broker record-deployment --pacticipant sailings --version a81c3d0 --environment production
$ pact-broker can-i-deploy --pacticipant harbour-travel --version a81c3d0 --to-environment production
All required verification results are published and successful                                      # exit 0
```

## The partner asks for a new field

Harbour Travel starts reading `vessel`, which `sailings` does not return, and publishes from its branch `feat/vessel-name`.

```text
$ pact-broker publish /pacts --consumer-app-version b77e210 --branch feat/vessel-name
Pact successfully published for harbour-travel version b77e210 and provider sailings.

$ make pact-provider                                   # sailings, commit c90d4e1 on main
ok      example.com/ferry/internal/sailings            # exit 0: the new pact is work in progress
$ pact-broker can-i-deploy --pacticipant sailings --version c90d4e1 --to-environment production      # exit 0
$ pact-broker can-i-deploy --pacticipant harbour-travel --version b77e210 --to-environment production
There is no verified pact between version b77e210 of harbour-travel and the version of sailings currently in production (a81c3d0)   # exit 1
```

The provider's run stays green and `sailings` can still deploy; the partner's new version cannot until `sailings` returns the field and a run verifies it. This is why the report is written from the broker's answers: the provider's test output alone would show nothing wrong.

## A new status value, approved as an exception

`sailings` wants to add `delayed` to the `status` enum of `/v1/sailings/{id}`.

```text
$ ./scripts/check-openapi-breaking.sh --base deployed.yaml --revision api/openapi.yaml --exceptions api/contract-exceptions.txt --retirements api/endpoint-retirements.txt
exceptions in force: 0
error   [response-property-enum-value-added] in API GET /v1/sailings/{id}
        added the new `delayed` enum value to the `status` response property for the response status `200`
FAIL: breaking change. ...
RESULT: FAIL                                                                    # exit 1
```

The product owner approves this one case after the partner confirms how it treats unknown statuses. The line goes into `api/contract-exceptions.txt` (format: `../templates/approval-records.md`), and every later run prints it:

```text
exceptions in force: 1
  EXCEPTION line 2: GET /v1/sailings/{id} added the new `delayed` enum value to the `status` response property for the response status `200` | reason: harbour-travel confirmed in writing on 2026-11-24 that it shows unknown statuses as "check with the operator" | approved-by: R. Okafor (product owner) | approved-on: 2026-11-26
RESULT: PASS (shape only: a change of meaning, unit or behaviour is not detected)       # exit 0
```

Pact reacts to such a value according to how the consumer matched it (run in the lean example): a pact that matches `status` with a regular expression over the old values fails verification when the provider returns a new one; a pact with a type-only matcher passes.

## A breaking change: version 2 beside version 1

Renaming `carSlotsLeft` is breaking. `/v2/sailings/{id}` is added with the new name while `/v1/` stays as it is: the gate passes (`removed endpoints: 0`, exit 0), because adding a path is additive. Changing `/v1/` in place fails it. Raising `info.version` and running oasdiff with `--fail-on MISSING-VERSION-BUMP` would have let the in-place change through; that mode is never used.

## Retiring an endpoint

`GET /v1/timetable` was marked `deprecated: true` with `x-sunset: "2026-09-30"`. On 2026-11-28 it is removed.

```text
$ ./scripts/check-openapi-breaking.sh --base deployed.yaml --revision api/openapi.yaml ...
No breaking changes to report, but the specs are different.                     # oasdiff: the sunset has passed
FAIL: /v1/timetable was removed and has no retirement record. Removal needs the product owner's recorded sign-off with the evidence that no caller remains, even after the sunset date.
RESULT: FAIL                                                                    # exit 1

# after the product owner's line is added to api/endpoint-retirements.txt
RETIRED with sign-off: GET /v1/timetable | sunset: 2026-09-30 | no-caller-evidence: gateway access logs 2026-10-01 to 2026-11-20 show 0 requests; consumer registry lists no caller | approved-by: R. Okafor (product owner) | approved-on: 2026-11-21
removed endpoints: 1
RESULT: PASS ...                                                                # exit 0
```

oasdiff alone exits 0 here. It knows the date; it cannot know whether anyone still calls the endpoint.

## Events with no deployment order

```text
$ ./scripts/check-event-compatibility.sh --schemas schemas/events --baseline deployed/schemas/events --registry http://127.0.0.1:18081
# version 2 adds "strike" to the enum of `reason`
ok sailings/sailing-cancelled [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
FAIL sailings/sailing-cancelled/2.json [declared, FULL_TRANSITIVE]: not compatible with the earlier versions: {errorType:"ENUM_ARRAY_CHANGED", ...}
RESULT: FAIL                                                                    # exit 1

# version 2 adds the optional field `vessel` instead
ok sailings/sailing-cancelled [declared, FULL_TRANSITIVE]: 2 version(s)
ok sailings/sailing-cancelled [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
RESULT: PASS ...                                                                # exit 0
```

Here the declared mode is the stricter pass for the enum, and the add-only pass is the stricter one for a removal (`./02-standard-pet-kennel.md`). That is why both run.

## The internal gRPC API

`buf breaking --against <deployed>` on `ferry/v1/sailings.proto`, one change each (exit 100 means breaking):

| Change | `FILE` | `WIRE_JSON` | `WIRE` |
|---|---|---|---|
| Rename a field | 100 | 100 | **0** |
| Renumber, retype or remove a field | 100 | 100 | 100 |
| Remove an RPC | 100 | **0** | **0** |
| Add a field | 0 | 0 | 0 |

`FILE` is used. A missing or empty baseline made buf exit 1 with `Failure:`, not 0.

## For the product owner

- Approve or refuse each exception line and each retirement line; both files are printed or checked on every run.
- Approve each daily impact report. With two environments and a partner, "NOT VERIFIED" for a partner branch is normal while a feature is in progress; "BROKEN" never is.
- The partner's agreement to run Pact, and what happens if it lapses, is recorded in the integration design.
