---
name: acceptance-criteria
product: <product>
story-id: US-<n>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: which story, how many criteria, what they settle>
profile: <lean | standard | enterprise>
run: <agent-run | workshop>
traces_to: ideate/user-stories.md (US-<n>); ideate/example-maps/US-<n>.md; <other artifacts and IDs>
---

<!-- Copy to ideate/acceptance-criteria/US-n.md, only when ideate/example-maps/US-n.md is ready.
     Fill every field and delete these comments. Every criterion:
       "### AC-US-n.m: title" (m = 1, 2, 3 ...), then "- From: Rn (Rn.Em, ...)", then EITHER
       a Gherkin block (one When) OR three lines: **Rule:** / **Verify:** / **Example:**.
     Both formats may appear under any of the three angle headings. Add as many as needed. -->

# Acceptance Criteria: US-<n> <Story title>

## Story Reference

As a <persona>, I want to <action>, so that <outcome>.

## Derived From

- Example map: ideate/example-maps/US-<n>.md (Ready, 0 open questions)
- Fit criteria and business rules covered: <FR-n.m, BR-n | none>
- Quality targets cited, not restated: <NFR IDs | none>

## How These Were Made

<!-- agent-run: keep the sentence. workshop: replace it with "Participants: names and roles". -->
Agent-run: one agent (requirements-analyst) drafted these from the example map; no workshop was held.

## Happy Path

### AC-US-<n>.1: <short title>
- From: R<n> (R<n>.E<m>)

```gherkin
Given <state that already holds, with real names and values>,
When <one action>,
Then <outcome the persona can observe>.
```

## Error / Negative Scenarios

### AC-US-<n>.2: <short title>
- From: R<n> (R<n>.E<m>)

```gherkin
Given <state in which the rule is about to be broken>,
When <one action>,
Then <what the persona sees>
But <what must not happen>.
```

## Boundary / Edge Cases

### AC-US-<n>.3: <short title>
- From: R<n> (R<n>.E<m>)

```gherkin
Given <state exactly on a limit>,
When <one action>,
Then <expected behaviour on the limit>.
```

## Explicitly Out of Scope

- <case not covered by this story, and where it belongs or why it is left out>
