# Chunk 23: Fix skills/agents smoke-test loading gap + tiered Contract/Acceptance testing model

**Status:** complete

**Completed:** 

**Deliverables:**
- tests/skills/*.contract.sh, tests/agents/backend-engineer.contract.sh — the 6 previously-silent *.fixture.sh files (two bare shell variables, never sourcing tests/lib/harness.sh; run-smoke-tests.sh's glob picked them up and silently reported 0 passed/0 failed) rewritten to the same self-contained smoke_test_skill/smoke_test_agent pattern every other category already uses
- tests/lib/assertions.sh (new) + tests/lib/harness.sh's new smoke_test_acceptance — reusable acceptance-tier primitives: live agent dispatch, structural assertions (frontmatter field/word-count/contains), and real gofmt+go vet / tsc --noEmit validation when the toolchain is present, visibly skipped otherwise
- tests/skills/vision-statement.acceptance.sh, tests/agents/backend-engineer.acceptance.sh, tests/agents/frontend-engineer.acceptance.sh — 3 new acceptance-tier exemplars, each proving an agent actually invokes a skill and produces the real work product (a vision statement / a Go chi handler / a React component) rather than just answering a question about it
- tests/run-smoke-tests.sh — --skill/--agent/--changed selector flags, deriving skill-to-agent ownership from agents' existing frontmatter skills: list (grepped) instead of a second, hand-maintained tag system
- hooks/hooks.json — new PostToolUse Write|Edit hook (matcher form live-verified — every prior entry only ever matched a single tool name), scoped in-prompt to skills/*/SKILL.md and agents/*.md, automatically running the mapped acceptance test on every touch and responding PASS with a note when none exists yet for that component; live-verified both paths (a real dispatch-and-validate PASS on skills/vision-statement/SKILL.md, and a cheap no-op PASS on an uncovered agent)
- tests/hooks/hooks-wiring.test.sh — fixed alongside (same root cause as D019): its PostToolUse case was failing for the wrong reason before this chunk
