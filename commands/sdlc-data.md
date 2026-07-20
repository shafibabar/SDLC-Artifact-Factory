---
description: Run the Data phase — pipeline implementation, data quality, product analytics
disable-model-invocation: true
---

Drive the Data phase of the SDLC Artifact Factory.

1. Read `sdlc-context.json`. Confirm the data-architect's pipeline architecture (Design phase) and the backend-engineer's data schemas (Implement phase) exist and are approved. If not, tell the user what's missing and stop.
2. Check which pipeline stages and analytics artifacts already exist. Do not rebuild approved work unless the user explicitly asks for a revision.
3. Invoke the `data-engineer` agent via the Agent tool, giving it the data-architect's pipeline blueprint, lineage design, event schemas, and classification rules, plus the product's OKRs and North Star Metric. The agent implements the pipeline stage workers (test-first, idempotent, DLQ-wired) and produces the data quality rules, metrics instrumentation plan, and dashboard/report content specs.
4. Confirm the dashboard/report content specs have been handed to `ux-architect` for UI specification — data-engineer defines content, it does not design layout.
5. When the agent reports completion, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-quality`.
