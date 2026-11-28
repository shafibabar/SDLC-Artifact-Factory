---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the exit trap deletes the cluster when the provisioning script ends, which is before `go test` runs in the next step (finding W3B-1). Its fix is one script that provisions, runs the tests and then tears down, with the teardown also running when a test fails or the run is interrupted (finding W3-D14).
2. It creates a kubeconfig file for the run and uses that file for the `kind`, `helm` and `kubectl` commands, instead of the caller's current context (research notes on kind, Helm and kubectl: `kind create cluster` without `--kubeconfig` changes the caller's current context). Passing the file by flag or by an exported `KUBECONFIG` set to the run's own file both pass.
3. It removes both sleeps. `sleep 60` is replaced by a wait for real readiness of the installed workloads with a time limit (for example Helm's wait, `kubectl rollout status` or `kubectl wait`), and the journey's `time.Sleep` is replaced by polling for the confirmation until a deadline (research notes on kubectl and on testing web APIs).
4. It says a Go build tag only adds files, so `-tags smoke` also runs the untagged booking and cancellation journeys against staging (finding W3B-2). It gives a smoke selection that cannot include a journey that creates or deletes data (finding W3-D10); any workable mechanism passes, for example a constraint that excludes those files, a separate directory, or a name pattern.
5. It makes the script install every chart of the product, with the web shell included, and the dependencies the journeys need, PostgreSQL and Redpanda (findings W3-D14 and W3B-3). An answer that keeps installing only the three service charts fails.
Fail if any of the 5 is missing.
