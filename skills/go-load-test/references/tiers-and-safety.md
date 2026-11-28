# Two Tiers, and Where Load May Go

Self-contained. Read before deciding where a load test runs, when someone proposes staging, production or a shared cluster, when setting up the designated environment, or when asked what a result proves. Product-owner decisions of 2026-11-28 fix this page (the rule on other systems as amended the same day: no load on any other system without a signed impact statement); each guard is enforced by `../scripts/run-load-test.sh` and was proven by a case that must be refused (run on 2026-11-28; the lab service received no request of the test in any refusal).

## Contents
The danger; the two tiers; the indicative tier's guard; the verdict tier's guard; load on any other system: the signed impact statement; credentials; what each tier does not prove; data and third parties; tools and cost.

## The danger

A load test is a deliberate attempt to slow a system down, and its overload and bulk-write scenarios are a deliberate attempt to break one. Aimed at a shared environment it takes that environment away from everyone using it, fills it with data nobody cleans up, and can reach real third parties. The earlier version of this skill ran against shared `staging`, overloaded it on purpose, wrote thousands of documents with no cleanup, kept a long-lived token in a secret and pushed metrics into staging's monitoring. A request not to do that does not stop a wrong variable in a pipeline, so each rule here is something the code refuses.

## The two tiers

| | Indicative tier | Verdict tier |
|---|---|---|
| Where | The throwaway kind cluster that `go-e2e-test`'s script creates for the run and deletes after it | The product's **designated performance environment**, approved by the product owner per product, sized and loaded with data as the requirements state |
| When | Nightly, inside the end-to-end environment run; by hand with `make load-indicative` | Before a release, finishing before publication; by hand |
| What it can say | "This build is not slower than the last one on this runner, the gate works, the product sheds correctly" | "At the stated demand the stated targets held", for that sizing and data |
| What it cannot say | **Anything about capacity or about a stated target.** Every report and every reply says so | Anything about the rolling SLO window or a larger system |
| Test types | Smoke, average load at a small rate, overload check | All, as the designation record lists |
| Credentials | None stored | Short-lived tokens the product owner approved |

Every product size has the indicative tier. A **lean** product may have only that tier until a performance environment is approved; it then states in its reports and release notes that no target was verified. Lean never means no load test, and never means a shared environment instead.

**Refused by default:** shared staging, production, a tenant's environment, a colleague's cluster, anything reachable by an address someone typed. Load goes to such a system only for verification and only with the product owner's signed impact statement (below); without one the test refuses, whatever the request.

## The indicative tier's guard

The runner takes no address from the caller. It needs `E2E_RUN_ID` and `E2E_KUBECONFIG`, which `run-e2e-environment.sh` sets for each suite, and reads the cluster's run marker through them.

| It refuses when | Message |
|---|---|
| Started by hand, outside the environment run | `E2E_RUN_ID and E2E_KUBECONFIG are not set` |
| The kubeconfig is the caller's own (`~/.kube/config` or one `KUBECONFIG` names) | `E2E_KUBECONFIG is the caller's own kubeconfig` |
| The kubeconfig has no context `kind-e2e-<run id>` | `the kubeconfig has no context ...` |
| That context's API server is not on loopback | `... is not on this machine` |
| The cluster has no run marker, or another run's | `the cluster's run marker says run "someone-else", this run is "run-1"` |
| The marker's endpoint is not `127.0.0.1:<port>` | `the run marker has no loopback address for endpoint ...` |
| The test type is stress, soak, spike or breakpoint | `a stress test is not allowed in the indicative tier` |

A loopback address alone proves nothing (a port-forward to staging is also on `127.0.0.1`); the link that matters is "this address is in the marker of the cluster this run created". The first and the last refusal were run with the real tools; the others with a stand-in `kubectl` in `tests/scripts/run-load-test.test.sh`. The accepting path was run against real clusters created by the unmodified end-to-end script.

## The verdict tier's guard

Three things must agree before any load is sent: a **record** in the repository naming the exact address, with the product owner's dated sign-off and an expiry; a **marker** the environment itself serves, with the same id; and **tokens** that expire within the limit the record sets. The files and every refusal message are in `../templates/designation-record.md`.

Why three: the record is the approval; the marker ties the approval to the thing at the address, so a record copied elsewhere or an address that moved fails; the expiry makes an approval lapse instead of living on after the environment changed. The runner also refuses a host whose name contains a `staging`, `stage`, `stg`, `prod`, `production` or `live` label unless the run carries a signed impact statement for it. That name check catches an honest mistake only.

The k6 scripts add a last layer: started with `k6 run` instead of the runner they throw `REFUSED` before a request (run: exit 107, with a staging address supplied by hand).

What the guards do not cover: a person who deliberately serves the marker from another environment and signs the record. The guards stop mistakes, not intent.

## Load on any other system: the signed impact statement

By default load goes only to the run's own throwaway cluster or the designated environment. Another system, staging or production included, may take load **for verification only**, and only when the product owner signs an **impact statement**: a separate record, `tests/load/statements/<id>.json`, which the runner takes with `--statement` (template and refusals in `../templates/designation-record.md`). It is separate from the designation because it answers a different question: a designation approves an environment for repeated verdicts; a statement accepts one bounded impact on someone else's system, and a product owner reads and signs it on its own.

The statement says, and the runner requires, each of: the exact address (scheme, host, port; nothing else; k6 follows no redirect in any run, so a redirect cannot carry load to another host); the purpose; the test type and the profile limit (rate, peak, length), which the run's profile may not exceed; data written or touched, and how it is removed; who and what is affected (other users, other teams, dependent systems, third parties, cost); how to stop the run and who watches it; the time window the whole run must fit in; the product owner's name and date of sign-off; and an expiry or a single-use run id. A statement that lacks a field, is unsigned, expired, for another address or another test type, or that the run's profile exceeds is refused before any request.

**The marker stays** wherever the system can serve one: `/.well-known/load-test-designation` answers with the statement's id as `statement_id`. Where it cannot (a third party's system or a production system nobody here can change), the statement must say so in its `marker` field (`cannot be served: <why>`); the runner then skips that one check, the report prints the reason, and every other check still applies.

**What such a run is:** it runs with `--tier verdict` and judges the same thresholds, but its result is a **verification**: a result about that system at that time, under whatever else it was carrying, **not a capacity verdict**, unless the same address is also the designated environment (both `--designation` and `--statement`, which must name one address). The report says so and records the statement verbatim.

Run on 2026-11-28 with k6 v2.4.0 against a lab stand-in on loopback named `api.staging.localhost` (names under `.localhost` are reserved for loopback, so the runner treats one that resolves only to loopback like `127.0.0.1`): the same address on a designation alone was refused (exit 3, no request reached the stand-in); a statement whose peak was below the profile's was refused (exit 3, no request); the signed statement ran, PASS (exit 0).

## Credentials

- **Indicative tier:** none stored anywhere. Test identities are accepted only by the throwaway cluster's values file and vanish with the cluster. The workflow has no `secrets.` reference.
- **Verdict tier, and a system under an impact statement:** one short-lived token per test subject, issued for the run through a mechanism the product owner approved, never a standing secret. The runner checks each token's stated expiry against the `token_max_minutes` of the record and of the statement and deletes the subjects file when k6 ends. The validator fails a workflow that reads `secrets.` and a subjects file committed to the repository.

## What each tier does not prove

**Indicative.** A GitHub-hosted Linux runner has 4 CPUs and 16 GB in a public repository and 2 CPUs and 8 GB in a private one; the kind node (one node, control plane included), the product, its database and the load generator all share them, with small data. kind is built for testing Kubernetes and for local development and CI; its documentation says nothing about performance testing. So the tier catches a regression between two comparable runs and proves **nothing about capacity**. A larger hosted runner is billed and needs the product owner's approval; it would not change what the tier can claim.

**Verdict.** The result holds for the recorded sizing, data and generator. "Unless you test in a realistic environment, it's very hard to predict exactly which resource will be exhausted" (SRE): a designated environment smaller than production gives a verdict about that environment, and the report says by how much it differs. Give the product explicit CPU and memory requests and limits and record them: a container at its CPU limit is throttled, not killed, and a result is meaningful only for that allocation.

## Data and third parties

- Test data exists only in the environment under test: created through the public API or that environment's seed job, in the volume the NFR states. Nothing is written to a shared system (`test-fixture-design`, rule F7).
- The throwaway cluster is deleted with its data. In the designated environment, the designation record's `data` field says how data is reset between runs; a soak that fills tables is followed by that reset.
- On a system under an impact statement, the statement's `data_written`, `data_removal` and `impact.third_parties` say what the run writes, how it is removed and which real third parties it reaches; the run writes nothing the statement does not name.
- Every third party is a stand-in in both tiers. Where load must not leave the environment, an egress NetworkPolicy enforces it only if the cluster's network plugin enforces policies (Kubernetes documentation); whether kind's default plugin does was not checked.

## Tools and cost

k6 is the one load tool (v2.4.0, AGPL-3.0, run as a separate program and never linked into the product). It is written in Go and scripted in JavaScript; the scripts drive the product from outside and are the same for a Go and a Python service. vegeta, locust and other tools are not used. k6's cloud service, any other paid load service and larger paid runners are refused until the product owner approves the cost (`test-strategist` escalates; the default is open source and self-run).
