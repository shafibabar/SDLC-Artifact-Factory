# Chunk 59: Medium fixes — contract tests for 7 skills + 2 further splits (GitHub issue #625, sub-issues #626–#632)

**Status:** complete

**Completed:** 2026-07-31

**Deliverables:**
- 5 test-only fixes (skill file untouched, no version bump — a contract test is a test artifact, not a skill-content change): methodology-review, requirements-analysis, roadmap-authoring, stakeholder-mapping, competitive-analysis. Each added tests/skills/<name>.contract.sh probing a fact that lives only in the skill's existing references/ template file (grep-verified absent from the body).
- 2 split+test fixes: gtm-strategy (body 236→199, v1.1.0→2.0.0 — description rewritten as a trigger surface, positioning/segment/messaging reference material moved to references/ grounded in Dunford/Moore/Lauchengco, contract test added); ui-component-spec (body 221→200, v2.0.0→2.1.0 MINOR — reference-grade content moved into its 3 existing references/ files, description unchanged, contract test added).
- 138 of 148 skills now have contract tests (up from 131). All sub-issues #626–#632 closed, parent #625 closed.
- AUDIT STATUS: the skill-authoring-standards audit's named clusters (domain-modeling, architecture, security, data, discovery/strategy, UX) and its MEDIUM-priority has-references-no-test list are now fully complete. 10 skills remain WITHOUT a contract test — all also lack references/, so each needs a full split+refs+test (not just a test), and all fell outside the 6 named cluster campaigns: distributed-tracing-design (167 body), event-storming-facilitation (256), feedback-template (213), mission-statement (125), prometheus-metrics-design (236), risk-register (165), sdlc-config-management (162), typescript-types (219), uat-scenario (208), ubiquitous-language (184). These are the next backlog if the campaign continues — 5 have bodies >200 (full split warranted); the rest need references/ extraction + a test. (Done in Chunk 60.)
