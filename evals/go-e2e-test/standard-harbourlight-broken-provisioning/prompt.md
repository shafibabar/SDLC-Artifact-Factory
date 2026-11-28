---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourlight**, a berth-booking product for marinas, on the **standard** profile. Three Go services (`booking`, `billing`, `notifier`), PostgreSQL, Redpanda, and a React web shell, each with a Helm chart. Our nightly end-to-end job never gets a green run and I'd like it fixed with as few changes as possible. This is what it does today:

```bash
# step 1: scripts/provision.sh
trap 'kind delete cluster --name hl-e2e' EXIT
kind create cluster --name hl-e2e
for c in booking billing notifier; do helm install "$c" "charts/$c"; done
sleep 60   # let the pods start
```

```bash
# step 2 (a separate workflow step)
go test ./tests/e2e/...
```

Other details:

- To save time the job installs only the three service charts. The web shell, PostgreSQL and Redpanda are left out.
- A journey books a berth and then calls `time.Sleep(10 * time.Second)` before checking that the notifier sent the confirmation.
- After each staging deploy we run `go test -tags smoke ./tests/e2e/...` against staging. Only `smoke_test.go` has `//go:build smoke`; the booking and cancellation journeys have no build tag, and they create and delete bookings.

Please tell me what is wrong and give me the corrected script outline and commands. Use this plugin's go-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 350 words plus the script outline.
