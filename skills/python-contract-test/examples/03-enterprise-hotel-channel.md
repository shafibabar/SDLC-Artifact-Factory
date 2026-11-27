# Enterprise: Hotel Availability with a Partner Booking Site

`availability` is a public REST API of a hotel group. A booking site, Lakeside Booking, calls it from its own systems and its own repository. Inside the product, `reservations` calls `availability` over gRPC, and `rate.changed` is published to many consumers with no fixed deployment order (`FULL_TRANSITIVE`). Two environments: `staging` and `production`.

Run on 2026-11-28: Python 3.15.2 (macOS arm64), oasdiff 1.39.0, buf 1.75.0, pact-python 4.2.0, `pact-python-cli` 1!1.0.0, Pact Broker 2.124.0, Redpanda v26.2.7 schema registry. The Python code is the lean example's with the names changed (`plots` → `availability`, `rentals` → `lakeside-booking`, plot → room type), run under those names. Not run: the workflow files on GitHub Actions; the gRPC status-code tests; generating Python gRPC stubs. File paths in the transcripts are shortened.

## Plan

| Boundary | Every pull request | Daily | Records |
|---|---|---|---|
| `availability` REST description | Gate against the deployed description | | Exceptions, retirements |
| `availability` as provider | Conformance through the real app | Verifies Lakeside Booking's pact: main branch, matching branch, whatever is deployed; pending and work-in-progress pacts on | |
| Lakeside Booking as consumer | Its own tests, in its repository | Publishes its pact from its own pipeline | Written agreement to run Pact |
| `reservations` → `availability` gRPC | `buf breaking`, category `FILE`, against the deployed commit | The Pact rule applies to this call too; pact-python needs a plugin for gRPC, which was not run for this skill, so the test strategy lists this call's consumer expectations as unverified | |
| `rate.changed` | Declared mode `FULL_TRANSITIVE`, then the add-only pass | | |

A consumer outside the product is covered by Pact under the same rule as an internal one, and the other party must agree to run it. Lakeside Booking publishes to the product's self-hosted broker with its own credentials. Had it declined, the boundary would have the description gate and conformance only, and the test strategy would say that the partner's real usage is unverified.

## Pact with two environments

```text
$ pact broker create-environment --name staging --display-name Staging
Created staging environment in the Pact Broker

# first daily run, commit a81c3d0 on both sides; nothing deployed yet
$ pytest pact_tests/provider -m pact                   # what make pact-provider runs
1 passed
$ ./scripts/write-pact-impact-report.sh --product lakeside-hotels --date 2026-11-28 --results results   # exit 1
| availability | production | verified | There are no missing dependencies |
| availability | staging | verified | There are no missing dependencies |
| lakeside-booking | production | NOT VERIFIED | There is no verified pact between version a81c3d0 of lakeside-booking and a version of availability currently in production (no version is currently recorded as deployed/released in this environment) |
| lakeside-booking | staging | NOT VERIFIED | (the same, for staging) |

# provider first, then the consumer
$ pact broker can-i-deploy --pacticipant availability --version a81c3d0 --to-environment staging          # exit 0
$ pact broker record-deployment --pacticipant availability --version a81c3d0 --environment staging
$ pact broker can-i-deploy --pacticipant availability --version a81c3d0 --to-environment production       # exit 0
$ pact broker record-deployment --pacticipant availability --version a81c3d0 --environment production
$ pact broker can-i-deploy --pacticipant lakeside-booking --version a81c3d0 --to-environment production
All required verification results are published and successful                                             # exit 0
```

## The partner asks for a new field

Lakeside Booking starts reading `breakfastIncluded`, which `availability` does not return, and publishes from its branch `feat/breakfast`.

```text
$ pact broker publish pacts --consumer-app-version b77e210 --branch feat/breakfast
Pact successfully published for lakeside-booking version b77e210 and provider availability.

$ pytest pact_tests/provider -m pact -rP               # availability, commit c90d4e1 on main
... is being verified because it is a 'work in progress' pact ...
Pending Failures:
    $ -> Actual map is missing the following keys: breakfastIncluded
There were 1 non-fatal pact failures on pending pacts or interactions
1 passed                                               # exit 0
$ pact broker can-i-deploy --pacticipant availability --version c90d4e1 --to-environment production       # exit 0
$ pact broker can-i-deploy --pacticipant lakeside-booking --version b77e210 --to-environment production
There is no verified pact between version b77e210 of lakeside-booking and the version of availability currently in production (a81c3d0)   # exit 1
```

The provider's run stays green and `availability` can still deploy; the partner's new version cannot until `availability` returns the field and a run verifies it. This is why the report is written from the broker's answers: the provider's exit status alone would show nothing wrong.

## A new status value, approved as an exception

`availability` wants to add `on-request` to the `status` enum of `/v1/room-types/{id}`.

```text
$ ./scripts/check-openapi-breaking.sh --base deployed.yaml --revision api/openapi.yaml --exceptions api/contract-exceptions.txt --retirements api/endpoint-retirements.txt
exceptions in force: 0
error   [response-property-enum-value-added] at api/openapi.yaml
        in API GET /v1/room-types/{id}
                added the new `on-request` enum value to the `status` response property for the response status `200`
FAIL: breaking change. Keep the change additive, or publish it as a new major version beside the old one.
RESULT: FAIL                                                                    # exit 1
```

The product owner approves this one case after the partner confirms how it treats unknown statuses. The line goes into `api/contract-exceptions.txt` (format: `../templates/approval-records.md`), and every later run prints it:

```text
exceptions in force: 1
  EXCEPTION line 2: GET /v1/room-types/{id} added the new `on-request` enum value to the `status` response property for the response status `200` | reason: Lakeside Booking confirmed in writing on 2026-11-24 that it shows a status it does not know as "ask the hotel" | approved-by: T. Abara (product owner) | approved-on: 2026-11-26
RESULT: PASS (shape only: a change of meaning, unit or behaviour is not detected)       # exit 0
```

Pact reacts to such a value according to how the consumer matched it (run in the lean example's code): a pact that matches `status` with a regular expression over the old values fails verification when the provider returns a new one; a pact with a type-only matcher passes.

## A breaking change: version 2 beside version 1

Renaming `sizeSquareMetres` is breaking. `/v2/room-types/{id}` is added with the new name while `/v1/` stays as it is: the gate passes (`removed endpoints: 0`, exit 0), because adding a path is additive. Renaming the field in `/v1/` in place fails it (exit 1). Raising `info.version` and running oasdiff with `--fail-on MISSING-VERSION-BUMP` let the in-place rename through (exit 0); that mode is never used.

## Retiring an endpoint

`GET /v1/rate-calendar` was marked `deprecated: true` with `x-sunset: "2026-09-30"`. On 2026-11-28 it is removed.

```text
$ ./scripts/check-openapi-breaking.sh --base deployed.yaml --revision api/openapi.yaml ...
No breaking changes to report, but the specs are different.                     # oasdiff: the sunset has passed
FAIL: /v1/rate-calendar was removed and has no retirement record. Removal needs the product owner's recorded sign-off with the evidence that no caller remains, even after the sunset date.
RESULT: FAIL                                                                    # exit 1

# after the product owner's line is added to api/endpoint-retirements.txt
RETIRED with sign-off: GET /v1/rate-calendar | sunset: 2026-09-30 | no-caller-evidence: gateway access logs 2026-10-01 to 2026-11-20 show 0 requests; the partner register lists no caller | approved-by: T. Abara (product owner) | approved-on: 2026-11-21
removed endpoints: 1
RESULT: PASS ...                                                                # exit 0
```

oasdiff alone exits 0 here. It knows the date; it cannot know whether anyone still calls the endpoint.

## Events with no deployment order

```text
$ ./scripts/check-event-compatibility.sh --schemas schemas/events --baseline deployed/schemas/events --registry http://127.0.0.1:18081
# version 2 adds "promotion" to the enum of `reason`
ok rates/rate-changed [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
FAIL rates/rate-changed/2.json [declared, FULL_TRANSITIVE]: not compatible with the earlier versions: {errorType:"ENUM_ARRAY_CHANGED", ...}
RESULT: FAIL                                                                    # exit 1

# version 2 adds the optional field `currency` instead
ok rates/rate-changed [declared, FULL_TRANSITIVE]: 2 version(s)
ok rates/rate-changed [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
RESULT: PASS ...                                                                # exit 0
```

Here the declared mode is the stricter pass for the enum, and the add-only pass is the stricter one for a removal (`./02-standard-car-share.md`). That is why both run.

## The internal gRPC API

`buf breaking --against <deployed>` on `hotel/v1/availability.proto`, one change each (exit 100 means breaking):

| Change | `FILE` | `WIRE_JSON` | `WIRE` |
|---|---|---|---|
| Rename a field | 100 | 100 | **0** |
| Renumber, retype or remove a field | 100 | 100 | 100 |
| Remove an RPC | 100 | **0** | **0** |
| Add a field; change only a comment | 0 | 0 | 0 |

`FILE` is used. A missing or empty baseline made buf exit 1 with `Failure:`, not 0.

## For the product owner

- Approve or refuse each exception line and each retirement line; both files are printed or checked on every run.
- Approve each daily impact report. With two environments and a partner, "NOT VERIFIED" for a partner branch is normal while a feature is in progress; "BROKEN" never is.
- The partner's agreement to run Pact, and what happens if it lapses, is recorded in the integration design.
