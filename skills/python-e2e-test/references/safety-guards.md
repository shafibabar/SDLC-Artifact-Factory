# Safety Guards

Self-contained. Read before writing or reviewing anything that decides where the Python end-to-end tests send requests: the guard, a client, a seed helper, a smoke test, a workflow. Each guard below is enforced by code, and each was proven on 2026-11-28 by a case that must be refused (Python 3.15.2, pytest 9.2.0, httpx 0.29.0, kind v0.33.0, kubectl v1.36.1). The code is in `../templates/python-suite.md`.

## The danger

Journeys create and delete data. Pointed at the wrong address they do that to a real environment. A request ("please don't run this against staging") does not stop a wrong variable in a pipeline, so each rule here is something the code refuses.

## 1. Journeys start only against the cluster their own run created

Every test in `tests/e2e/journeys/` passes `require_throwaway_cluster` before its first request, through a session fixture that the autouse `journey` fixture asks for (so a journey cannot avoid it by not naming `env`). It reads two values the script sets, `E2E_RUN_ID` and `E2E_KUBECONFIG`, and nothing else: **no address is read from the environment or an option**. On refusal every journey ends as an error that begins `REFUSED:`, the check runs once per session, and the runner reports the run as broken without retrying.

| It refuses when | Seen |
|---|---|
| `pytest` is started by hand, with or without `E2E_BASE_URL=https://staging...` | `E2E_RUN_ID is not set: start the suite with tests/e2e/run-e2e-environment.sh (make e2e)` |
| The kubeconfig is the caller's own (the default file, or one `KUBECONFIG` names) | `E2E_KUBECONFIG is the caller's own kubeconfig` |
| The kubeconfig has no context `kind-e2e-<run id>` (another cluster's file) | `no context kind-e2e-pe2e-lab-other` |
| That context's API server is not a loopback address | `'10.20.30.40:6443' is not on this machine (loopback only)` |
| The cluster carries no run marker (another kind cluster on this machine) | `this cluster carries no run marker, so this run did not create it` |
| The marker belongs to another run | `run marker says run 'someone-else', this run is 'pe2e-lab-foreign'` |
| An endpoint in the marker is not loopback, or is a host name | `'10.20.30.40:443' is not on this machine`; `'api.staging.example:443' is not a literal IP address and port` |

Addresses then come only from the marker. The link that matters is "this address belongs to the cluster this run created": a loopback address alone is not proof, because a developer's port-forward to staging is also on `127.0.0.1`.

The marker is read with `kubectl --kubeconfig <the run's file> --context kind-e2e-<run id>`, as the Go guard does. `kubernetes.config.load_kube_config()` with no arguments would read the caller's kubeconfig and current context, and by default it writes configuration changes back to that file (its documentation; not run here). A suite that uses the client library anyway names the run's file and context and passes `persist_config=False`; the validator fails on a loader call without `config_file=`.

## 2. A client reaches one address and nothing else

`env.client("<endpoint>")` and `env.async_client("<endpoint>")` return an `httpx` client whose transport is bound to that endpoint's scheme, host and port. What running showed, with a second local server counting what it received:

| Attempt | Plain `httpx.Client(base_url=...)` | The bound client |
|---|---|---|
| A relative path | Goes to the base address | Goes to the base address |
| An **absolute URL** to another address | **Sent**: `base_url` is ignored for an absolute URL; the other server received the request | `Refused`; the other server received nothing |
| The same host on another port, another scheme, `localhost` for `127.0.0.1` | Sent | `Refused` |
| A redirect to another address, with `follow_redirects=True` | Followed | `Refused` at the hop; the other server received nothing. Redirects are off unless a request asks for them |
| `HTTP_PROXY` set in the environment | Sent through the proxy | The proxy received nothing (`transport=` and `trust_env=False`) |

`httpx.URL.port` is `None` for a scheme's default port, so the guard compares the filled-in port (run: `http://127.0.0.1:80` and `http://127.0.0.1/` are the same address to it). A request hook can do the same job: run, a hook that raises aborts the request before it is sent, and hooks run again on each redirect hop. The transport is used here because the instrumented transport sits inside it and one object then carries both the refusal and the trace header.

## 3. Seeding and deleting refuse any other address

- Test data is created through the product's public API with the bound client.
- A direct database connection takes its address from the marker and passes `env.require_throwaway`. Run: `db.staging.example:5432`, `10.0.0.7:5432`, `127.0.0.1:5432` and `localhost:5432` were refused; the run's own endpoint was accepted.
- A direct write is a plain `INSERT`, never an upsert. The earlier `INSERT ... ON CONFLICT (id) DO UPDATE` silently overwrote whatever row was already there. Run: a second `INSERT` of the same row raised `UniqueViolationError`.
- Removal is of exactly the rows the test created, in the fixture that created them, after its `yield`, with its own failures reported (`test-fixture-design`, rules F1, F4, F5 and F7).

## 4. The smoke selection cannot write

Smoke tests are the only selection that may be pointed at a deployed environment (`cd-pipeline`, `blue-green-deployment`, `disaster-recovery-plan` run them there). So the smoke selection is made unable to change anything:

| Mechanism | Seen |
|---|---|
| The smoke selection collects `tests/e2e/smoke/` only; journeys are in another folder | A journey file copied into the smoke folder: `fixture 'api' not found`, and a test that asks for `env` is `REFUSED`; the server received no write |
| A journey marked `smoke`, or a test outside the two folders | pytest stops with a usage error (exit 4) before any test runs |
| The `smoke` client refuses any method but GET and HEAD, and any other address, before sending | A smoke test that POSTs: `Refused: refusing POST /loans: smoke tests are read-only`; the server received no write |
| A selection that runs no test | pytest itself exits 5 for an empty or fully deselected selection and **0 when every test was skipped**; `run-python-e2e-suite.sh` exits 3 in all three cases |

Python has no build that leaves files out, so two things do the work that Go's build tags do: the folder (what is collected) and the client (what can be sent). `-m smoke` alone is not the guard: markers select tests, they do not stop an import or a request.

What stays true for a smoke test against a real environment: it reads as an ordinary user or tenant would, with a short-lived credential the pipeline supplies; it must never need data it created itself. A check that needs a write (a "create then delete" probe) is not smoke: it runs in the throwaway cluster. A copy of real customer data as test data is a question for the product owner (`test-fixture-design`).

## 5. Nothing outside the local container runtime

The script creates one kind cluster and deletes that same cluster by name. It runs no cloud command, creates no cloud resource and deletes nothing by name prefix; a leftover cluster from another run is reported, not removed, and there is no scheduled clean-up job. The workflow stores no credential and declares `permissions: contents: read`.

## 6. The guards check themselves on every run

`journeys/test_guard_selfcheck.py` and `smoke/test_smoke_guard.py` are part of the suite: a change that weakens a guard turns the run red. `../scripts/validate-python-e2e-tests.sh` finds the same mistakes in the text before anything runs: a test outside the two folders, a write or journey code in a smoke file, an upsert, an address read from the environment, an HTTP client that is not the bound one, a Kubernetes client loaded without the run's file, a `kind`, `helm` or `kubectl` command with no kubeconfig, clusters deleted by pattern, a cloud command, a missing `permissions:` block, a stored secret.

## What the guards do not cover

- A person who deliberately plants a run marker in another cluster and points the kubeconfig at it, or who imports `httpx` directly in a test. The guards stop mistakes, not intent; the validator fails on the second.
- What a smoke test reads. Reading can still be wrong (another tenant's data): scope the credential.
- The product's own side effects in the throwaway cluster (an email it really sends, a call to a real third party). Point those at a stand-in in the end-to-end values file.
