# Changelog

All notable changes to the SDLC Artifact Factory are documented here.

Format: [Semantic Version] — Date — Description

---

## [Unreleased]

### Added
- 2026-07-20 — `platform/` skills (12), `observability/` stack skills (3 — completes the 7-skill domain), and `platform-engineer` agent (Chunk 15)
- 2026-07-20 — `data-analytics/` skills (7) and `data-engineer` agent (Chunk 16) — completes the 13-agent roster defined in `.claude-plugin/plugin.json`
- 2026-07-20 — `validation/` skills (5) (Chunk 17); `requirements-analyst` extended with Customer Validation phase ownership (UAT, beta programs, feedback triage, acceptance sign-off) — the SDLC's final phase, run post-Deploy
- 2026-07-20 — remaining `governance/` skills (4): `artifact-manifest`, `risk-register`, `value-stream-map`, `sdlc-config-management` (Chunk 18) — completes the governance domain (6 skills) and all 15 skill domains
- 2026-07-20 — all 15 real slash commands (`commands/*.md`) — phase drivers, navigation, cross-cutting (Chunk 19). Live-verified via `claude --plugin-dir` + one real command invocation, not just read for coherence.
- 2026-07-20 — `hooks/hooks.json` with 7 real hooks and 6 backing `scripts/*.sh` (Chunk 20). The 9 originally planned hooks became 7: `pre-phase-advance`, `pre-code-generation`, and `pre-implement` consolidated into one `pre-phase-advance` hook (`PreToolUse`/`Agent`) once bound to a real event — they were the same check under three names. `methodology-compliance-check` is an agent-type handler (judgment, not scriptable); the other 6 are deterministic command-type scripts. Every hook and script individually triggered with real or synthetic input and its outcome verified.

### Changed
- Content improvement campaign across all skills, agents, and repo metadata: unified component frontmatter schemas, restored always-on rule wiring in the five newest agents, fixed dead references, terminology drift, stale metadata, and code currency issues. Delivered as five batch PRs (PR #29–#33).
- CLAUDE.md, README.md, `.claude-plugin/plugin.json`, `settings.json` corrected from an untested conceptual spec (fictional lifecycle events, invalid manifest fields, "Tools" as a component type) to real, verified Claude Code mechanics (Chunk 19).
- `agents/<role>/AGENT.md` restructured to flat `agents/<role>.md` — the nested form is not discovered by Claude Code's real agent-discovery mechanism (confirmed empirically; folded into Chunk 19).
- All 136 skills restructured from `skills/<domain>/<name>/SKILL.md` (domain-grouped, confirmed not discovered by Claude Code) to flat `skills/<name>/SKILL.md` (verified discoverable) — the same class of bug as the agents fix above, closing `sdlc-context.json`'s open question Q001. Domain grouping survives only as a logical tag in `sdlc-context.json`'s `skill_domains`, not as a filesystem path. Zero name collisions across the 15 former domains, so no skill was renamed. ~17 literal cross-references to the 4 governance skills (`glossary-management`, `methodology-review`, `artifact-manifest`, `sdlc-config-management`) updated to their new flat paths; `naming-convention-enforcer.sh`'s path regex updated to match.

## [0.1.0] — 2026-06-24 → 2026-06-26

Foundational build, delivered as one chunk per PR (Chunks 1–14 of the build checklist).

### Added
- 2026-06-24 — Skeleton folder structure: all plugin directories established (Chunk 1, PR #1)
- 2026-06-24 — `sdlc-context.json` factory memory and session state (Chunk 2, PR #1)
- 2026-06-24 — Plugin manifest, `CLAUDE.md` always-on standards, `settings.json` (Chunk 3, PR #1)
- 2026-06-24 — Canonical Ubiquitous Language glossary (~120 terms) and methodology review standards: `governance/` skills `glossary-management`, `methodology-review` (Chunk 4)
- 2026-06-24 — `strategy/` skills (8) and `product-strategist` agent (Chunk 5, PR #2)
- 2026-06-24 — `discovery/` skills (11) and `requirements-analyst` agent (Chunk 6, PR #20)
- 2026-06-25 — `domain-modeling/` skills (9) and `domain-modeler` agent (Chunk 7, PR #21)
- 2026-06-25 — `architecture/` skills (9) and `enterprise-architect` agent (Chunk 8, PR #22)
- 2026-06-25 — `security/` skills (9), `security-architect` and `security-engineer` agents (Chunk 9, PR #23)
- 2026-06-25 — `ux/` skills (4) and `ux-architect` agent (Chunk 10, PR #24)
- 2026-06-25 — `data-architecture/` skills (7) and `data-architect` agent (Chunk 11, PR #25)
- 2026-06-25 — `backend-engineering/` skills (16), `observability/` instrumentation skills (4), and `backend-engineer` agent (Chunk 12, PR #26)
- 2026-06-26 — `frontend-engineering/` skills (14) and `frontend-engineer` agent (Chunk 13, PR #27)
- 2026-06-26 — `test-engineering/` skills (12) and `test-strategist` agent (Chunk 14, PR #28)
- 2026-06-29 — MIT LICENSE file
