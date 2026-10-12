---
description: Initialize a new product in the SDLC Artifact Factory and begin the Strategy phase
argument-hint: [problem-statement]
disable-model-invocation: true
---

You are starting a new product through the SDLC Artifact Factory. Follow these steps exactly.

## 1. Check for an existing product

Read `sdlc-context.json`. If `first_product.status` is anything other than "Not yet started" (or a product context otherwise already exists), STOP and tell the user: a product is already in progress; run `/sdlc-status` to see where it stands, or confirm explicitly that they want to start a second product before proceeding.

## 2. Capture the problem statement

The problem statement is `$ARGUMENTS`. If empty, ask the user for it directly — do not proceed without one. A problem statement names the target market, the core problem, and (if known) the compliance/regulatory context.

## 3. Confirm or override the tech stack

Read the plugin's tech-stack defaults at `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-config-management/resources/tech-stack-defaults.json` (do not look for a `CLAUDE.md` table — it is not part of the installed plugin). Summarize the defaults to the user in plain language and ask: accept all defaults, or override specific ones? Any override is recorded per the `sdlc-config-management` skill (`${CLAUDE_PLUGIN_ROOT}/skills/sdlc-config-management/SKILL.md`) — never silently apply a default the user has overridden, and never repeat an unchanged default into the override record.

## 4. Record the product and hand off to Strategy

Update `sdlc-context.json`: set `first_product` (or the equivalent product entry) with the problem statement and confirmed/overridden config — this section is still tracked there directly (it's static, not a growing log). If any default was overridden, record it as a decision the memory-engine way instead of appending to `sdlc-context.json` (see `${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`): write `.sdlc-memory/tree/self/decisions/D0<next>.md` with the decision and rationale, then run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/ingest.py" .sdlc-memory/tree/self/decisions/D0<next>.md` to index it.

Then proceed exactly as `/sdlc-strategy` does: invoke the `product-strategist` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:product-strategist"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/product-strategist.md` — never search the filesystem for it), giving it the problem statement and confirmed tech/business context. Report back to the user what was produced and what phase gate comes next.
