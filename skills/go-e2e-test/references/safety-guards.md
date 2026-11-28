# Safety Guards

Self-contained. Read before writing or reviewing anything that decides where the end-to-end tests send requests: the guard, a seed helper, a smoke test, a workflow. Each guard below is enforced by code, and each was proven on 2026-11-28 by a case that must be refused (Go 1.27.4, kind v0.33.0, kubectl v1.36.1).

## The danger

Journeys create and delete data. Pointed at the wrong address they do that to a real environment. A request ("please don't run this against staging") does not stop a wrong variable in a pipeline, so each rule here is something the code refuses.

## 1. Journeys start only against the cluster their own run created

`TestMain` of the journey build calls `requireThrowawayCluster` before any test and exits with `REFUSED:` when it fails. It reads two values the script sets, `E2E_RUN_ID` and `E2E_KUBECONFIG`, and nothing else: **no address is read from the environment or a flag**.

| It refuses when | Seen |
|---|---|
| The suite is started by hand, with nothing set | `E2E_RUN_ID is not set: start the suite with ... (make e2e)` |
| The kubeconfig is the caller's own (the default file, or one `KUBECONFIG` names) | `E2E_KUBECONFIG is the caller's own kubeconfig` |
| The kubeconfig has no context `kind-e2e-<run id>` | `no context kind-e2e-nope` |
| That context's API server is not a loopback address | `"10.20.30.40:6443" is not on this machine` |
| The cluster carries no run marker (another kind cluster) | `this cluster carries no run marker, so this run did not create it` |
| The marker belongs to another run | `run marker says run "someone-else", this run is "lab-q1"` |
| An endpoint in the marker is a host name or not loopback | `"api.staging.example:443" is not a literal IP address and port` |

Addresses then come only from the marker. The link that matters is "this address belongs to the cluster this run created": a loopback address alone is not proof, because a developer's port-forward to staging is also on `127.0.0.1`.

## 2. A client reaches one address and nothing else

`env.Client("<endpoint>")` is bound to that endpoint. A request to any other host is refused before anything is sent (run: a second local server received zero requests). Redirects pass through the same check.

## 3. Seeding and deleting refuse any other address

- Test data is created through the product's public API with the bound client.
- A direct database connection takes its address from the marker and passes `env.RequireThrowaway`. Run: `db.staging.example:5432`, `10.0.0.7:5432`, `127.0.0.1:5432` and `localhost:5432` were refused; the run's own endpoint was accepted.
- A direct write is a plain `INSERT`, never an upsert. The earlier `INSERT ... ON CONFLICT DO UPDATE` silently overwrote whatever row was already there. Run: a second `INSERT` of the same row failed.
- Removal is of exactly the rows the test created, registered when they are created, with its own errors reported (`test-fixture-design`, rules F1, F4, F5 and F7).

## 4. The smoke build cannot write

Smoke tests are the only selection that may be pointed at a deployed environment (`cd-pipeline`, `blue-green-deployment`, `disaster-recovery-plan` run them there). So the smoke build is made unable to change anything:

| Mechanism | Seen |
|---|---|
| Files that create or delete data are tagged `e2e && !smoke` | `go test -tags smoke -list .` and `-tags e2e,smoke -list .` print only `TestSmoke_...` |
| A smoke file that calls a seed helper | Does not compile: `undefined: createBooking` |
| Every client in the smoke build refuses any method but GET and HEAD, before sending | `TestSmoke_WritesAreRefused`: POST, PUT, PATCH and DELETE each refused |
| A selection that runs no test | `go test` itself exits 0 with `[no tests to run]`; `run-go-e2e-suite.sh` exits 3 |

Go build tags only add files. `-tags smoke` compiles every file with no tag as well, which is why **every** file in `tests/e2e/` carries a tag, and why journeys say `!smoke` and not just `e2e`.

What stays true for a smoke test against a real environment: it reads as an ordinary user or tenant would, with a short-lived credential the pipeline supplies; it must never need data it created itself. A check that needs a write (a "create then delete" probe) is not smoke: it runs in the throwaway cluster. A copy of real customer data as test data is a question for the product owner (`test-fixture-design`).

## 5. Nothing outside the local container runtime

The script creates one kind cluster and deletes that same cluster by name. It runs no cloud command, creates no cloud resource and deletes nothing by name prefix; a leftover cluster from another run is reported, not removed. The workflow stores no credential and declares `permissions: contents: read`.

## 6. The guards check themselves on every run

`guard_selfcheck_test.go` and `TestSmoke_WritesAreRefused` are part of the suite: a change that weakens a guard turns the run red. `../scripts/validate-go-e2e-tests.sh` finds the same mistakes in the text before anything runs: a file with no tag, a write in a file the smoke build compiles, an upsert, an address read from the environment, a `kind`, `helm` or `kubectl` command with no kubeconfig, a cloud command, a missing `permissions:` block, a stored secret.

## What the guards do not cover

- A person who deliberately plants a run marker in another cluster and points the kubeconfig at it. The guards stop mistakes, not intent.
- What a smoke test reads. Reading can still be wrong (another tenant's data): scope the credential.
- The product's own side effects in the throwaway cluster (an email it really sends, a call to a real third party). Point those at a stand-in in the end-to-end values file.
