# Chunk 24: ddd-agent-handoff skill — cross-agent DDD boundary matrix and handoff protocol

**Status:** complete

**Completed:** 

**Deliverables:**
- skills/ddd-agent-handoff/SKILL.md (cross-cutting, owner: factory-governance) — an Agent Boundary Matrix mapping DDD concerns to the 11 real agents that touch DDD work, pointing each to the existing pattern skill(s) it should load rather than duplicating them, plus a short Handoff Protocol
- ddd-agent-handoff added to the skills: list of all 11 agents named in the matrix (domain-modeler, enterprise-architect, data-architect, data-engineer, backend-engineer, security-architect, security-engineer, platform-engineer, ux-architect, frontend-engineer, test-strategist)
- tests/skills/ddd-agent-handoff.contract.sh — live-verified via smoke_test_skill
- Originated from Shafi's meta-prompt/draft proposing a 14-role 'DDD orchestrator' with its own references/assets/guidelines subtree and an embedded pytest test suite; adapted to this repo's conventions after finding the 14 roles map onto the existing 13 agents with no gaps, and ~7 of the proposed reference files already existed as standalone skills (see decision D020; full analysis on GitHub issue #48)
