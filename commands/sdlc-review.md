---
description: Run a methodology-compliance review against an artifact or a whole phase
argument-hint: [artifact-path-or-phase-name]
allowed-tools: Read, Glob, Agent
disable-model-invocation: true
---

Run a methodology review on demand: the same criteria the methodology-review hook applies as artifacts are written, for one artifact or a whole phase.

1. The target is `$ARGUMENTS` — either a specific artifact path or a phase name (review every artifact in that phase). If empty, ask exactly: "Which artifact path or phase name should I review?" and stop until they answer.
2. Invoke a general-purpose subagent via the Agent tool, instructing it to:
   - Read `${CLAUDE_PLUGIN_ROOT}/skills/methodology-review/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/glossary-management/SKILL.md` for the review criteria
   - Read the target artifact(s)
   - Apply every applicable methodology check (DDD, Event Storming, TDD, BDD, SOLID — per each check's "Applies to" scope) and the Ubiquitous Language check
   - Produce a report following `${CLAUDE_PLUGIN_ROOT}/skills/methodology-review/references/review-report-template.md`
3. Present the report to the user. If `result: fail`, name which agent owns the remediation and do not mark the artifact as passing regardless of how minor the defects look.
