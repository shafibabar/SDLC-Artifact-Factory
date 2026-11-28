---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Castellan**, a property-access platform on the **enterprise** profile: several Python services (FastAPI, pytest) on Kubernetes, with OpenTelemetry tracing in the services. An engineer proposed this for the end-to-end suite and I'd like your review before I accept it:

1. The suite reads its target from one environment variable, `E2E_BASE_URL`, defaulting to our staging URL so it "just works" on a laptop.
2. All calls go through `httpx.Client(base_url=E2E_BASE_URL)`, "so the tests cannot reach any other address".
3. The setup script creates a kind cluster, then runs plain `helm install` and `kubectl apply` using whatever context is current.
4. When a journey fails, it prints a trace id so we can find the request in Tempo. The test process installs only `opentelemetry-api`; it does `with tracer.start_as_current_span("journey"): pass`, reads the span's trace id, and then sends the requests with a plain httpx client.
5. To gate releases, the suite runs in a GitHub Actions workflow triggered by `on: release: types: [published]`.

Tell me which of these are sound and what must change. Use this plugin's python-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 300 words, with a brief snippet only where it helps.
