---
description: Record an Architecture Decision Record
argument-hint: [decision-title]
disable-model-invocation: true
---

Record an Architecture Decision Record (ADR) for a decision that has already been made or is being made now — this command does not decide, it documents.

1. The decision title is `$ARGUMENTS`; if empty, ask the user for it.
2. Check whether this decision (or one closely related) is already recorded: look through the existing ADRs in `artifacts/<product>/design/decisions/` and run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" decisions --limit 20`. If so, tell the user and ask whether this should supersede the existing ADR (per `adr-authoring`'s Superseding Chains) rather than duplicate it.
3. Invoke the `enterprise-architect` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:enterprise-architect"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/enterprise-architect.md` — never search the filesystem for it) (or the agent whose domain the decision belongs to, if it's not an architecture decision — e.g. a security decision goes to `security-architect`), directing it to the `adr-authoring` skill. Give it the decision title, the context prompting it, and the options considered if the user has already stated them.
4. The agent produces the ADR (context, decision, consequences, alternatives rejected) at `artifacts/<product>/design/decisions/ADR-<NNN>-<slug>.md`. The write hook registers it in the product manifest; when the user approves it, run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" approve <that path>`.
