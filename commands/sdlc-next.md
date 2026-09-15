---
description: Tell the user exactly what to run next
allowed-tools: Read, Glob, Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh:*)
---

Query the SDLC memory engine (`skills/memory-recall`) and `sdlc-context.json`'s static sections, and tell the user the single next action — one clear recommendation, not a menu.

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/memory/run.sh" "${CLAUDE_PLUGIN_ROOT}/scripts/memory/self_status.py" build-checklist`. **If `all_complete` is false**: name the `first_incomplete` chunk (number and title), summarize its deliverables in one or two sentences (drill in with `retrieve.py --mode thinking "chunk N deliverables" --full` if the summary line isn't enough), and state plainly that per `CLAUDE.md`'s chunk gate, work does not start until the user says "go." Do not start building.
2. **If `all_complete` is true and no product has started**: recommend `/sdlc-start`.
3. **If a product is in progress**: recommend the next phase-driver command in sequence (`/sdlc-strategy` → `/sdlc-ideate` → `/sdlc-design` → `/sdlc-implement` → `/sdlc-data` → `/sdlc-quality` → `/sdlc-deploy` → `/sdlc-validate`), based on which phase artifacts exist and are approved. If phase-position tracking for the product is ambiguous, say so rather than guessing.
4. Do not invoke any agent. This command only reads and recommends.
