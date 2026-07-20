---
description: Run the Ideate phase — requirements, personas, backlog, acceptance criteria
disable-model-invocation: true
---

Drive the Ideate phase of the SDLC Artifact Factory.

1. Read `sdlc-context.json`. Confirm the Strategy phase is complete (vision, mission, OKRs, stakeholder map, GTM strategy, competitive analysis all exist and are approved). If not, tell the user to complete `/sdlc-strategy` first and stop.
2. Check which Ideate artifacts already exist. Do not re-produce artifacts already approved unless the user explicitly asks for a revision.
3. Invoke the `requirements-analyst` agent via the Agent tool, giving it the Strategy phase artifacts. The agent owns the full artifact set (functional requirements, NFR specification, personas, JTBD analysis, impact map, epics, user story backlog, acceptance criteria, example maps, story map, MoSCoW prioritisation) and follows its own strict execution sequence and approval gates — do not skip them.
4. When the agent reports the Ideate phase complete, confirm its two handoffs are explicit (NFR architecture handoff to enterprise-architect; BDD handoff to test-strategist), confirm `sdlc-context.json`'s checklist reflects completion, and tell the user the next step is `/sdlc-design`.
