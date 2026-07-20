---
description: Run the Deploy phase — CI/CD, infrastructure, observability stack, progressive delivery
disable-model-invocation: true
---

Drive the Deploy phase of the SDLC Artifact Factory.

1. Read `sdlc-context.json`. Confirm the Quality phase gates have passed (all automated tests, security, and compliance checks green). If not, tell the user to complete `/sdlc-quality` first and stop — Deploy never proceeds on a service that hasn't cleared Quality.
2. Check which platform artifacts already exist. Do not rebuild approved infrastructure unless the user explicitly asks for a revision.
3. Invoke the `platform-engineer` agent via the Agent tool, giving it the built images, the Container Diagram and Multi-Tenancy Design, the test suite split, SLO targets, and the security/data-retention contracts it needs to operate. The agent builds the CI/CD pipeline, infrastructure, Kubernetes delivery, observability stack, SLOs/alerting, and disaster recovery — following its own GitOps, one-path-to-production discipline.
4. Confirm a rollback has been demonstrated and a DR restore has been executed with measured RTO/RPO before considering this phase closed.
5. When the agent reports completion, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-validate` — run against the deployed canary/staging environment, not before it.
