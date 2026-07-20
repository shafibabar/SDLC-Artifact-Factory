---
description: Run the Strategy phase — vision, mission, roadmap, GTM, OKRs
disable-model-invocation: true
---

Drive the Strategy phase of the SDLC Artifact Factory.

1. Read `sdlc-context.json`. Confirm a product context exists (`first_product` or equivalent) — if not, tell the user to run `/sdlc-start` first and stop.
2. Check which strategy artifacts already exist under the product's artifact directory. Do not re-produce artifacts already approved unless the user explicitly asks for a revision.
3. Invoke the `product-strategist` agent via the Agent tool. Give it the problem statement, target market, and any prior decisions from `sdlc-context.json`. The agent owns the full artifact set (vision, mission, stakeholder map, competitive analysis, business model canvas, GTM strategy, roadmap, OKRs) and will present each for approval per its own execution sequence — do not skip its approval gates.
4. When the agent reports the Strategy phase complete, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-ideate`.
