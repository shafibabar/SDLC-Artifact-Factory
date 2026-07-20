---
description: Report current position in the factory build or in a product's SDLC journey
allowed-tools: Read, Glob
---

Read `sdlc-context.json` and report status in plain language — no jargon, this is read by a PM.

1. **If `build_checklist` has any incomplete chunk**: report factory build status. State the last completed chunk, the first incomplete chunk (its title and deliverables), and how many chunks remain. This is the plugin's own construction — read `CLAUDE.md`'s Session Startup rule for what this means.
2. **If `build_checklist` is fully complete**: state that the factory is fully built. Then check whether a product has been started (`first_product.status`, or equivalent). If no product has started, tell the user to run `/sdlc-start`. If a product is in progress, report what phase-position tracking exists for it in `sdlc-context.json` today — note plainly if no dedicated per-product phase field exists yet (this is a known gap; a future chunk should add one rather than this command inventing an undocumented convention).
3. Always report: any unresolved `open_questions`, and the most recent 2-3 entries in `decisions` for context.
4. Do not invoke any agent. This command only reads and reports.
