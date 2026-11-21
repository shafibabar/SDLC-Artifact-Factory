# Context Map Notation

The detail behind `SKILL.md` § 5: how to draw the map in plain text, what each line carries, and how the current and target maps sit side by side. Plain-text boxes and arrows are the primary notation (D047-13); Mermaid is optional. The relationship patterns themselves, and how to choose one, are `context-map-patterns`.

## 1. What the map shows

1. Every Bounded Context as a named box, plus every external system it touches.
2. Every point of contact as a line.
3. On each line: which side is **upstream** (its changes flow down) and the **one** relationship pattern, with its reason (from `context-map-patterns`).

It is not a deployment diagram or a sequence diagram. It shows how models relate and who adapts to whom.

## 2. Boxes

```
┌──────────────────────────────┐
│ Enrolment            (Core)  │
│ owns: Cohort, Seat           │
└──────────────────────────────┘
```

Name (a domain noun), the subdomain type in brackets, and the Aggregates it owns (candidates until `aggregate-design`). An external system is a box with `[external]` instead of a type. A legacy region with no coherent model is one box around the whole region, marked `[legacy, no coherent model]`; don't draw contexts inside it that don't exist.

## 3. Lines

```
Catalogue ──U──[ pattern ]──D──▶ Enrolment
```

- `U` marks the upstream end, `D` the downstream end; the arrow points downstream.
- The pattern label comes from `context-map-patterns`. Leave it as `[ ? ]` until that skill has filled it; the validator flags any line still unlabelled.
- A translation layer the downstream builds (an Anti-Corruption Layer) lives inside the downstream context; annotate the downstream box rather than drawing a separate box.

## 4. Current and target maps

| Product | Maps |
|---|---|
| Nothing does this work today | Target only |
| Anything does it today (a system, a spreadsheet, a bought tool, paper), at every profile | **Current** (as it is, including spreadsheets, shared databases and the legacy mess), then **target** beside it, with the differences listed |

Evans and Vernon both insist on mapping what is. A target map drawn over an existing system, without the current one, hides the work the transition needs.

## 5. Keeping it current

The map is a living artifact. Update it when a context is found or retired, a boundary moves (`SKILL.md` § 6), or a pattern changes. A stale map is worse than none: people build on the wrong picture.
