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

Read `CLAUDE.md`'s Tech Stack Defaults table and `sdlc-context.json`'s `tech_stack.confirmed` block. Summarize the defaults to the user in plain language and ask: accept all defaults, or override specific ones? Any override is recorded per the `sdlc-config-management` skill (`skills/sdlc-config-management/`) — never silently apply a default the user has overridden, and never repeat an unchanged default into the override record.

## 4. Record the product and hand off to Strategy

Update `sdlc-context.json`: set `first_product` (or the equivalent product entry) with the problem statement and confirmed/overridden config, and append a decision entry if any default was overridden.

Then proceed exactly as `/sdlc-strategy` does: invoke the `product-strategist` agent via the Agent tool, giving it the problem statement and confirmed tech/business context. Report back to the user what was produced and what phase gate comes next.
