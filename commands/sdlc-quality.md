---
description: Run the Quality phase — e2e, performance, load, chaos, mutation testing, compliance verification
disable-model-invocation: true
---

Drive the Quality phase of the SDLC Artifact Factory. This is shift-right validation against the running system — it does not gate whether code was written test-first (that was already enforced in Implement); it proves the system holds up under real conditions.

1. Read `sdlc-context.json`. Confirm the Implement phase is complete (all services pass `make ci`/`npm run ci`, tests written test-first). If not, tell the user to complete `/sdlc-implement` first and stop.
2. Check which Quality-phase suites already exist. Do not rebuild approved work unless the user explicitly asks for a revision.
3. Invoke `test-strategist` for the shift-right suites: end-to-end journeys, performance baselines, load/SLO verification, chaos testing, and periodic mutation testing on critical packages.
4. Invoke `security-engineer` for the compliance test suite, vulnerability scanning, and the compliance verification report.
5. When both agents report completion, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-deploy`.
