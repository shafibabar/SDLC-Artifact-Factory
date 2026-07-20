---
description: Run a methodology-compliance review against an artifact or a whole phase
argument-hint: [artifact-path-or-phase-name]
allowed-tools: Read, Glob, Agent
disable-model-invocation: true
---

Run a methodology review — this is the same check `pre-phase-advance` will run automatically once hooks exist, available on demand before then.

1. The target is `$ARGUMENTS` — either a specific artifact path or a phase name (review every artifact in that phase). If empty, ask the user which.
2. Invoke a general-purpose subagent via the Agent tool, instructing it to:
   - Read `skills/methodology-review/SKILL.md` and `skills/glossary-management/SKILL.md` for the review criteria
   - Read the target artifact(s)
   - Apply every applicable methodology check (DDD, Event Storming, TDD, BDD, SOLID — per each check's "Applies to" scope) and the Ubiquitous Language check
   - Produce a report following `skills/methodology-review/references/review-report-template.md`
3. Present the report to the user. If `result: fail`, name which agent owns the remediation and do not mark the artifact as passing regardless of how minor the defects look.
