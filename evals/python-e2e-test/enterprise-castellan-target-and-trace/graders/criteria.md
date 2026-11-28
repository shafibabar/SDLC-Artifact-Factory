---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects letting one environment variable decide the target and rejects the staging default: the suite must refuse to run unless its target is the cluster created for its own run (end-to-end decision of 2026-11-28 and W3-D14). How the suite proves this is not prescribed.
2. It says `base_url` alone does not bind the client to one address, because an absolute URL passed to a request bypasses `base_url`, and it adds a guard that makes the client refuse any other address (`research/testing/httpx-guards-and-polling-official-docs.md`, base_url and absolute URLs). Any refusal point is acceptable, for example a transport, a request hook or a wrapper.
3. It says every `kind`, `helm` and `kubectl` command must use a kubeconfig file created for the run, never the caller's current context (W3-D14; `research/testing/kind-official-docs.md`, `helm-official-docs.md`, `kubectl-official-docs.md`).
4. It says the printed trace id is not real as proposed, because the test process has no OpenTelemetry SDK tracer provider, so the tracer is a no-op and the id is invalid or all zeros; and it says the requests must be sent inside the span with the trace context carried on them, through an instrumented HTTP client or by injecting the trace headers (gap W3C-28; `research/testing/opentelemetry-python-official-docs.md`: an API-only tracer is a no-op, and the span ends when the `with` block exits).
5. It says `release: published` fires after the release is already published, so it cannot gate the release, and that the end-to-end run must finish before publication (`research/testing/github-actions-e2e-official-docs.md`, release events). Any arrangement that achieves this is acceptable, for example running the suite as a required job in the workflow that creates the release.
Fail if any of the 5 is missing.
