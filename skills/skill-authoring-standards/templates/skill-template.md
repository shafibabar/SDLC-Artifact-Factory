---
name: <skill-name>
description: >
  <Draft as the trigger surface, not a summary. Name the nouns and verbs a real
  prompt would contain, the owning agent, and the phase or command that invokes
  it. A usage condition ("Used by <agent> when...") is stronger than a topic
  label ("This skill covers...").>
version: 1.0.0
phase: <strategy|ideate|design|implement|data|quality|deploy|customer-validation|cross-cutting>
owner: <agent-name>
created: <YYYY-MM-DD>
tags: [<tag1>, <tag2>]
produces: <artifact-name — the artifact applying this skill yields>
domain: <architecture|backend|data|discovery|domain-modeling|frontend|governance|observability|platform|security|strategy|testing|ux|validation>
status: <experimental|stable|complete>
# Optional — delete if unused:
# related: [<other-skill>, <other-skill>]
# sources: [research/<cluster>/<file>.md]
---

# <Skill Title>

## Purpose

<One paragraph: what this skill governs, why it exists as a separate skill
(single-responsibility), and which agent loads it. Do not restate the
description field — add the "why this skill rather than a body section in
an agent" reasoning that the description field cannot hold. Where the
content draws on a research/ book, say which and list it in sources:.>

---

## <Core Section — Decision-Shaping Guidance>

<Decision-shaping guidance belongs here: when to use X vs Y, what "good"
looks like, the core procedure. Keep this resident. Anything most
invocations won't need moves to a folder, with a pointer that says WHEN to
read it, for example:
  "To produce the artifact, copy ./templates/<file>.md and fill every field."
  "For a multi-tenant or high-availability case, read ./examples/<file>.md."
  "Before handing off, cross-check the output against ./resources/<file>.md."
Create only the folders the content needs — never an empty one.>

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
