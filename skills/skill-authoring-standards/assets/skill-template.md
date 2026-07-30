---
name: <skill-name>
description: >
  <Draft as the trigger surface, not a summary. Name the nouns and verbs a real
  prompt would contain, the owning agent, and the phase or command that invokes
  it. A usage condition ("Used by <agent> when...") is stronger than a topic
  label ("This skill covers...").>
version: 1.0.0
phase: <implement|design|strategy|quality|deploy|customer-validation|cross-cutting>
owner: <agent-name>
created: <YYYY-MM-DD>
tags: [<tag1>, <tag2>]
---

# <Skill Title>

## Purpose

<One paragraph: what this skill governs, why it exists as a separate skill
(single-responsibility), and which agent loads it. Do not restate the
description field — add the "why this skill rather than a body section in
an agent" reasoning that the description field cannot hold.>

---

## <Core Section — Decision-Shaping Guidance>

<Decision-shaping guidance belongs here: when to use X vs Y, what "good"
looks like, the core procedure. Keep this resident. If a section is a full
template, a worked example, or an exhaustive checklist that most invocations
won't need, move it to references/ instead.>

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| <row> | <pass condition> | <fail condition> |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| <pattern> | <reason> | <fix> |
