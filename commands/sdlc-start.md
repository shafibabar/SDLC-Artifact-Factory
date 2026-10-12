---
description: Initialize a new product in the SDLC Artifact Factory and begin the Strategy phase
argument-hint: [problem-statement]
disable-model-invocation: true
---

You are starting a new product through the SDLC Artifact Factory. Follow these steps exactly.

## 1. Check for an existing product

Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" status`. If it reports a product, STOP and tell the user: a product is already in progress in this repo; run `/sdlc-status` to see where it stands. (This repo's product state lives in `artifacts/<product>/_manifest.json`; do not look for or read any `sdlc-context.json`.)

## 2. Capture the problem statement

The problem statement is `$ARGUMENTS`. If empty, ask the user for it directly — do not proceed without one. A problem statement names the target market, the core problem, and (if known) the compliance/regulatory context.

## 3. Confirm or override the tech stack

Read the plugin's tech-stack defaults at `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-config-management/resources/tech-stack-defaults.json` (do not look for a `CLAUDE.md` table — it is not part of the installed plugin). Summarize the defaults to the user in plain language and ask: accept all defaults, or override specific ones? Any override is recorded per the `sdlc-config-management` skill (`${CLAUDE_PLUGIN_ROOT}/skills/sdlc-config-management/SKILL.md`) — never silently apply a default the user has overridden, and never repeat an unchanged default into the override record.

## 3b. Choose the product's scale profile

How much each phase produces depends on the product's size. Recommend one profile from the problem statement, say why in one sentence, and ask the user to confirm or pick another:

| Profile | Fits | What it means |
|---|---|---|
| **lean** | An internal or single-team tool: one service, no regulated data, no multi-tenancy | The fewest, shortest artifacts (e.g. Strategy: vision, one-page roadmap, one OKR); one review per phase |
| **standard** | A B2B SaaS product: a few services, one region, ordinary personal data | The core set; approval stops only at decisions that change direction |
| **enterprise** | Multi-tenant, regulated (SOC 2 / GDPR / HIPAA), high availability, multi-region | Everything; approval after every artifact |

Tell the user the five methodologies (DDD, Event Storming, TDD, BDD, SOLID) apply at every profile; lean makes artifacts fewer and shorter, never skips a methodology. The profile can be changed later; that change is recorded as a decision.

## 4. Record the product and hand off to Strategy

Pick a short product slug (lowercase words joined by hyphens, e.g. `lunch-tracker`) and confirm it with the user along with the product name. Then:

- Run `"${CLAUDE_PLUGIN_ROOT}/scripts/product-state.py" init <slug> --name "<product name>" --problem "<the problem statement>"`. This creates `artifacts/<slug>/_manifest.json`, the one place the product's phase and approvals are kept.
- Write `sdlc-config.json` per the `sdlc-config-management` skill: always `scale_profile` (the confirmed profile), plus **only** the tech-stack overrides the user chose.
- If any default was overridden, record it as a decision in project memory: write `.sdlc-memory/tree/self/decisions/D0<next>.md` with the decision and rationale (see `${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`). Writing it indexes it automatically.

Then proceed exactly as `/sdlc-strategy` does: invoke the `product-strategist` agent via the Agent tool (`subagent_type: "sdlc-artifact-factory:product-strategist"`; its definition is `${CLAUDE_PLUGIN_ROOT}/agents/product-strategist.md` — never search the filesystem for it), giving it the problem statement and confirmed tech/business context. Report back to the user what was produced and what phase gate comes next.
