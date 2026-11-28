---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quillmark**, a contract-signing platform on the **enterprise** profile. Eleven Go services behind an API gateway, deployed with Helm. The end-to-end journeys already run nightly in a throwaway kind cluster. I want to tighten the release process and stop the noise from flaky tests. My plan:

1. Add a pre-release gate: a workflow triggered by `on: release: types: [published]` that runs the full end-to-end suite, so a bad release is blocked.
2. Retry any failed journey up to three times, and report green if any attempt passes.
3. Move tests that still flake to a quarantine list. Quarantined tests are skipped, and the run counts them as passed so the nightly stays green. We will get back to them when there is time.
4. When a journey fails, print a trace id so we can find it in Tempo. In the test I'll write `ctx, span := otel.Tracer("e2e").Start(ctx, "sign-contract")` and print `span.SpanContext().TraceID()`. The test binary needs no other OpenTelemetry code, and it calls the gateway with `http.DefaultClient`.
5. Post the test report to the team's chat channel after each run. Nobody needs to sign it off.

Please tell me what to change. Use this plugin's go-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 350 words plus a few lines of code for item 4.
