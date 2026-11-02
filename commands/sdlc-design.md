---
description: Run the Design phase — domain model, architecture, UX, data, security design
disable-model-invocation: true
---

Drive the Design phase of the SDLC Artifact Factory. This phase invokes five agents in a strict dependency order — do not reorder or parallelize steps 3 to 5.

Invoke every agent named below via the Agent tool with `subagent_type: "sdlc-artifact-factory:<agent-name>"`; each agent's definition is `${CLAUDE_PLUGIN_ROOT}/agents/<agent-name>.md` — never search the filesystem for it.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If no product exists, tell the user to run `/sdlc-start` first and stop. Confirm `phases.ideate.status` is `approved`; if not, tell the user in plain language what the Ideate phase still needs (the output lists it) and that `/sdlc-ideate` finishes it, and stop.
2. Check which Design artifacts already exist per agent. Do not re-produce approved artifacts unless the user explicitly asks for a revision.
3. **Invoke `domain-modeler` first.** It runs Event Storming and classifies the subdomains, then produces the Ubiquitous Language, Context Map, Aggregate designs, Domain Event catalog and Command catalog (lean: one domain-model document). Everything downstream depends on this. Wait for it to complete and be approved, up to the point where it hands over for the read-side decision.
4. **Invoke `enterprise-architect` for the read-side decision**, giving it the domain-modeler's output. It decides the read side for each Bounded Context with `cqrs-pattern` and writes `design/architecture/cqrs-decisions.md` (skipped at lean). Then **invoke `domain-modeler` again** to design the Read Models that decision calls for.
5. **Invoke `enterprise-architect` for the architecture**, giving it the domain model plus the NFR specification. It produces the System Context Diagram, the Container Diagram (service decomposition, gateway placement and the deployment view), the Multi-Tenancy Design, Integration Design, any orchestration, broker and gRPC decisions, Component Diagrams for services that differ from the default, ADRs, API contracts, the Architecture Evaluation and the Architecture Summary. Wait for it to complete and be approved.
6. **Invoke `ux-architect`, `data-architect`, and `security-architect`**, each given the domain model and container diagram they depend on. These three can be run in either order relative to each other — each declares its own inputs and will surface a blocker if something it needs is missing.
7. When all five agents report completion, ask the user to approve the Design phase and record it (see **Approvals** below), and tell the user the next step is `/sdlc-implement`. Remind them `/sdlc-event-storm` can be re-run standalone later if a new subdomain needs modelling.

## What to produce

Before invoking any agent, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" plan design`. It lists, for this product's scale profile, the artifacts that are **required** (with their canonical paths), the **optional** ones (produce one only when its note applies or the user asks), the ones **skipped** at this profile, and any **guidance** for the phase. Pass that list to every agent you invoke and tell it to produce exactly the required artifacts, the applicable optional ones, and nothing that is skipped. The five methodologies (DDD, Event Storming, TDD, BDD, SOLID) still apply in full; a smaller profile means fewer and shorter artifacts, never a skipped methodology.

## Approvals

Follow the plan's `approval_mode`, unless the user asks for another (they can switch at any time):
- **batch** (lean): let the agents produce the phase's artifacts together, then show the user one summary table and ask for a single review;
- **key-decisions** (standard): stop for approval only at artifacts that change direction (such as the vision, the Context Map, the Container Diagram), and batch the rest into one review;
- **per-artifact** (enterprise): stop for approval after every artifact.

Agents hand back to you at each approval point; relay it to the user. Record only what the user explicitly approves, never on their behalf:

- When the user approves one or more artifacts, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <path> [<path> …]` (paths under `artifacts/<product>/`).
- When this phase's work is done, ask the user to approve the Design phase, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete design`. If it refuses, show the user, in plain language, what is missing or unapproved. Only if the user explicitly says to proceed anyway, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" complete design --override "<their reason>"` and record that as a decision in project memory (`${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`).
