# Pass 00 — Baseline health (2026-10-11, `main` @ 2e34268)

What actually runs and passes today, measured without any LLM calls. Later passes build on these facts and do not need to re-measure them.

## Measured

| Check | Result |
|---|---|
| `scripts/lint-all.sh` (governance gate) | **PASS**, 8.5s. 0 broken refs, 0 orphans, catalog current |
| `tests/run-smoke-tests.sh scripts schemas` | **254 pass / 1 FAIL**, 4.7s. Failing file: `tests/scripts/validate-artifact-structure.test.sh` |
| Skills | 187. All 187 have `status: stable`. 181 have `references/`, 16 `assets/`, 10 `scripts/` |
| SKILL.md length | min 70 / median 179 / max 237 lines. None has a body over 200 lines (the split rule is being met) |
| Skill contract tests | 186 / 187. Missing: `memory-recall` |
| Agents | 13, from 163 to 418 lines (3,460 total). Acceptance tests exist for 4 (backend, frontend, platform, product-strategist) |
| Commands | 15, **11–25 lines each** (197 total) |
| Hook events used | 4 of ~11 (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`) |
| LLM-backed test files | 208 (skills, agents, commands, hooks), each a real model call with a 90s timeout |
| Size | skills 9.2M · research 2.4M (133 files, 16 clusters) · tests 1.2M · `.git` 48M |
| Empty placeholder dirs | `mcp/ lsp/ monitors/ output-styles/ themes/ bin/` |
| `plugin.json` version | `0.1.0` |

## Findings

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| P00-1 | maintainability | `scripts/validate-artifact-structure.sh:48`, `tests/scripts/validate-artifact-structure.test.sh` | **`main` is red.** The memory-engine merge (c9c7b12) made `summary` a required artifact field, but neither the test fixture nor CLAUDE.md § Artifact Standards (still 5 fields) was updated. The governance gate does not run `tests/scripts`, so CI could not catch it. | Fix the fixture and the standard together. Have the gate (or CI) also run the `scripts` category. | bug | H | S | High |
| P00-2 | maintainability | `skills/memory-recall/` (no `tests/skills/memory-recall.contract.sh`) | The newest skill came in without the contract test that CLAUDE.md requires, and nothing enforces that requirement. | Have the gate fail when a skill has no contract test. | new-test | M | S | High |
| P00-3 | depth | `grep '^status:' skills/*/SKILL.md` → 187× `stable` | `status` has the same value on every skill, so it tells the catalog nothing. | Define real criteria for experimental/stable/complete, or drop the field. | process | M | S | High |
| P00-4 | usage | `commands/sdlc-strategy.md:8`, `commands/sdlc-start.md:13` | Commands read `sdlc-context.json` and its `first_product`. That file is **the plugin's own build memory**, which is not present in a user's product repo. Plugin-development state and product state seem to be mixed. Pass 01 must confirm what happens in a fresh repo. | Separate per-product state (e.g. `.sdlc/product.json` in the user's repo) from the plugin's own development memory. | bug | H | M | Medium (pending pass 01) |
| P00-5 | depth | `wc -l commands/*.md` | Commands are 11–25-line prompts that hand everything to a single agent. There is no phase gate, no check that artifacts exist, and no handoff contract in the command itself. | Pass 09 checks this together with the P7 "workflow-as-data" idea. | command/hook-change | M | M | Medium |
| P00-6 | maintainability | `sdlc-context.json` `_meta.updated_by` (≈1.3k chars) | The context file's "metadata" holds long campaign narratives. CLAUDE.md, the charter, CHANGELOG and README also hold them. | Pass 10: name one home for campaign state. | process | M | M | Medium |
