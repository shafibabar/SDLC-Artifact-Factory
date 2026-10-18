# Pass 01b — Dogfood run v3 (after #1255, #1254, #1288)

Re-run of [pass 01](01-dogfood.md) to check the fixes merged since: product state + approvals (#1284), scale profiles (#1285), plugin paths (#1282), the methodology hook (#1286), agent tools + memory-recall (#1287), checks on Edit + re-approval (#1289).

- Plugin loaded from: a detached worktree of `main` @ `c9bdf96` (`--plugin-dir`), so note-taking can't change the plugin mid-run.
- Product repo: `scratchpad/dogfood-v3/lunch` (fresh `git init`, empty). Logs: `scratchpad/dogfood-v3/logs/NN-*.json`.
- Driver: `claude -p --permission-mode auto --output-format json`, one call per step, `--resume` within a session.
- Claude Code 2.1.302.
- Sample product (same as v2): "A lunch-order tracker for a 20-person office: people pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
- Status: IN PROGRESS (updated after every step).

## Narrative

### Step 1 — `/sdlc-artifact-factory:sdlc-start <problem>` — 12 s, 2 turns, $0.22
- No filesystem search, no reading the plugin's own `sdlc-context.json` (v2 went hunting in sibling dirs). "No product exists in this repo yet" — read from `product-state.py status`.
- Showed the tech-stack defaults as a table and suggested which rows a 20-person tool doesn't need, without deciding for the user.
- **Recommended the `lean` scale profile unprompted**, with the reason (one office, one service, no regulated data) and the note that all five methodologies still apply.
- Proposed a product name and slug. Three clear questions; nothing written yet (correct).
- v2 comparison: 25 s / $0.33 and a cross-repo hunt.

### Step 2 — answers (drop broker/graph DB/mesh, Compose instead of K8s+Helm; lean; name OK; "start Strategy") — 201 s, 9 turns, $1.19 (session total $1.41)
- Wrote `sdlc-config.json` (lean + only the 5 changed rows, schema-valid), the manifest via `product-state.py init`, and decision D001 under `.sdlc-memory/tree/self/decisions/` — **indexed** this time (v2: "0 file(s) indexed").
- `.gitignore` gets the two `.sdlc-memory` entries before the 223 MB `.venv` install (v2: index created before any `.gitignore`).
- Flagged its own interpretation for confirmation ("I dropped Helm but kept OpenTofu … tell me if you meant to drop OpenTofu as well") — good.
- **Lean scale profile honoured:** Strategy = vision (38 lines), roadmap (46), OKRs (61) + one optional competitive analysis (48; `phase-requirements.json` marks it optional for lean). **4 documents / 193 lines**, and it named the four lean skips. v2: 11 documents / ~1,590 lines / $6.40.
- **Approval state correct:** every entry `draft`, phase `in-progress`, "I haven't approved anything for you"; one batch review asked for. Manifest validates against `sdlc-manifest.schema.json` (v2: 39 errors).
- The product-strategist subagent ran `memory/run.sh` (memory-recall) — it has Bash now (#1254).
- No "Shafi" anywhere in the product's artifacts or memory (v2: the owner's name leaked into stakeholder-map and Q001–Q004).
- **REGRESSION — methodology review dead for agent-written artifacts.** All 4 writes: `Methodology review could not run: No such tool available: Skill`. The hook failed closed as designed (nothing silently passed) and the main session reported it plainly to the user. Cause, confirmed by probe on a throwaway copy of the plugin: an agent-type hook spawned by a **subagent's** tool call gets that subagent's tool set; #1254's standard set has no `Skill`, so the hook can't load `methodology-review`. With `Skill` added to an agent's tools the same hook loads the skill and passes. #1255's live test only wrote from the main session, which has `Skill`. → fix in its own issue before continuing.
- Minor: the six open questions live only inside the artifacts' text; nothing was written to `.sdlc-memory/tree/self/open_questions/`, so `/sdlc-status` (which reads project memory) won't list them. Check at Step 4.
