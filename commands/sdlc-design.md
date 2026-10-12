---
description: Run the Design phase — domain model, architecture, UX, data, security design
disable-model-invocation: true
---

Drive the Design phase of the SDLC Artifact Factory. This phase invokes five agents in a strict dependency order — do not reorder or parallelize the first two steps.

Invoke every agent named below via the Agent tool with `subagent_type: "sdlc-artifact-factory:<agent-name>"`; each agent's definition is `${CLAUDE_PLUGIN_ROOT}/agents/<agent-name>.md` — never search the filesystem for it.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.ideate.status` is `approved`; if not, tell the user in plain language what the Ideate phase still needs (the output lists it) and that `/sdlc-ideate` finishes it, and stop.
2. Check which Design artifacts already exist per agent. Do not re-produce approved artifacts unless the user explicitly asks for a revision.
3. **Invoke `domain-modeler` first.** It Event Storms the domain(s) and produces the Ubiquitous Language, Context Map, Aggregate designs, Domain Event catalog, Command catalog, and Read Model designs. Everything downstream depends on this. Wait for it to complete and be approved.
4. **Invoke `enterprise-architect` second**, giving it domain-modeler's output plus the NFR specification. It produces the System Context Diagram, Container Diagram, Component Diagrams, ADRs, API contracts, Integration Design, and Multi-Tenancy Design. Wait for it to complete and be approved.
5. **Invoke `ux-architect`, `data-architect`, and `security-architect`**, each given the domain model and container diagram they depend on. These three can be run in either order relative to each other — each declares its own inputs and will surface a blocker if something it needs is missing.
6. When all five agents report completion, ask the user to approve the Design phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-implement`. Remind them `/sdlc-event-storm` can be re-run standalone later if a new subdomain needs modelling.

## Approvals

Agents stop at approval gates and hand back to you; relay each gate to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Design phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete design`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete design --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
