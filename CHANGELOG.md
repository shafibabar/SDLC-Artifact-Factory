# Changelog

All notable changes to the SDLC Artifact Factory are documented here.

Format: [Semantic Version] — Date — Description

---

## [Unreleased]

### Added
- 2026-07-20 — `platform/` skills (12), `observability/` stack skills (3 — completes the 7-skill domain), and `platform-engineer` agent (Chunk 15)
- 2026-07-20 — `data-analytics/` skills (7) and `data-engineer` agent (Chunk 16) — completes the 13-agent roster defined in `.claude-plugin/plugin.json`

### Changed
- Content improvement campaign across all skills, agents, and repo metadata: unified component frontmatter schemas, restored always-on rule wiring in the five newest agents, fixed dead references, terminology drift, stale metadata, and code currency issues. Delivered as five batch PRs (PR #29–#33).

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
