# Chunk 58: UX cluster refactor — 3 skills rebuilt under skill-authoring-standards (GitHub issue #618, sub-issues #619–#621)

**Status:** complete

**Completed:** 2026-07-31

**Deliverables:**
- All 3 UX skills (owner ux-architect) rebuilt to v2.0.0: ux-flow-design (235→179 body, 2 refs), information-architecture (223→148, 2 refs), user-journey-mapping (221→191, 2 refs). 6 new references/ files, 3 contract tests.
- Research: this-is-service-design-doing-stickdorn (primary — journey maps + service blueprint), agile-ux-storytelling-baker, lean-product-playbook-olsen, supplemented by stable public UX/IA practice (Rosenfeld/Morville IA systems, card sorting, tree testing, wireflow notation). No research phase — the domain is stable public design practice with low fabrication risk (unlike the security cluster gap).
- Notable grounded content: Stickdorn service-blueprint extension (front-stage vs back-stage separated by the line of visibility, revealing back-stage classification/lineage services a plain journey map hides) (user-journey-mapping); task-flow/user-flow/wireflow distinction + mandatory error/empty/edge state design (ux-flow-design); the four IA systems (organization/labeling/navigation/search) + card sorting open-vs-closed + tree testing (information-architecture). All three account for the repo's microfrontend architecture — flows and IA cross fragment boundaries, the shell owns global navigation, each fragment owns its local IA. 131 of 148 skills now have contract tests (up from 128). 12 files changed, 1,725 insertions. All sub-issues #619–#621 closed, parent #618 closed.
- MILESTONE: this completes ALL HIGH-priority clusters from the skill-authoring-standards audit (domain-modeling, architecture, security, data, discovery/strategy, UX — 43 skills across Chunks 53-58, plus the 28 from the DevOps campaign Chunk 52). Remaining audit backlog: 7 MEDIUM-priority skills that already have references/ but lack a contract test (methodology-review, requirements-analysis, gtm-strategy, ui-component-spec, roadmap-authoring, stakeholder-mapping, competitive-analysis) — done in Chunk 59.
