---
description: Tell the user exactly what to run next
allowed-tools: Read, Glob
---

Read `sdlc-context.json` and tell the user the single next action — one clear recommendation, not a menu.

1. **If `build_checklist` has an incomplete chunk**: name it (chunk number and title), summarize its deliverables in one or two sentences, and state plainly that per `CLAUDE.md`'s chunk gate, work does not start until the user says "go." Do not start building.
2. **If `build_checklist` is fully complete and no product has started**: recommend `/sdlc-start`.
3. **If a product is in progress**: recommend the next phase-driver command in sequence (`/sdlc-strategy` → `/sdlc-ideate` → `/sdlc-design` → `/sdlc-implement` → `/sdlc-data` → `/sdlc-quality` → `/sdlc-deploy` → `/sdlc-validate`), based on which phase artifacts exist and are approved. If phase-position tracking for the product is ambiguous in `sdlc-context.json`, say so rather than guessing.
4. Do not invoke any agent. This command only reads and recommends.
