---
description: Run the Implement phase — test standards, backend, frontend, security controls, all test-first
disable-model-invocation: true
---

Drive the Implement phase of the SDLC Artifact Factory.

1. Read `sdlc-context.json`. Confirm the Design phase is complete (domain model, architecture, API contracts, security design all exist and are approved). If not, tell the user to complete `/sdlc-design` first and stop.
2. Check which services and test standards already exist. Do not regenerate approved work unless the user explicitly asks for a revision.
3. **Invoke `test-strategist` first**, to establish the test strategy, the Test Pyramid targets, and the BDD feature files from the Ideate phase's Gherkin acceptance criteria. This must exist before test-first implementation can begin.
4. **Invoke `backend-engineer`, `frontend-engineer`, and `security-engineer`**, each given the relevant Design phase artifacts and the test standards from step 3. Every one of these agents writes the failing test before the implementation, without exception — this is enforced by the `tdd-gate` hook once built, and is non-negotiable regardless.
5. Confirm the shared OpenAPI contract has not drifted between backend-engineer and frontend-engineer (both generate from the same `enterprise-architect`-owned contract).
6. When all agents report completion, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-data`.
