---
name: miro-board-notation
description: >
  Shared notation for any skill or agent that produces a visual, board-style
  artifact — Wardley Maps, Context Maps, Event Storming boards, Domain
  Storytelling, Bounded Context canvases — expressed as a structured Miro
  board spec instead of freeform prose. Uses Miro's actual element vocabulary
  (sticky note, shape, frame, connector, text) so the spec is buildable by
  hand in Miro today and automatable via a real Miro API/MCP connection
  later with no format changes. No live Miro connection exists yet in this
  environment — this skill defines the spec format only.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-22
tags: [cross-cutting, miro, notation, diagramming, visualization, governance]
---

# Miro Board Notation

**Status: MVP.** Covers the element vocabulary and spec format — enough for
any skill to describe a board precisely and consistently. Deeper treatment
(exact Miro REST API field mapping, a template gallery per diagram type) is
deferred to a future refactor session.

## Purpose

This plugin is standardizing on Miro for diagrams across skills and agents.
Writing a diagram as a **board spec** — a structured table using Miro's own
element types — means the same content works two ways with zero rework:
a human builds it by hand in Miro today; an agent creates it via a real
Miro connection once one exists. Never describe a board as free-floating
prose ("draw boxes for each Bounded Context with arrows between them") —
always use the spec format below.

## The Five Miro Elements

| Type | Use for | Key properties |
|---|---|---|
| **Sticky note** | One discrete unit of meaning — a Domain Event, an Aggregate, a subdomain, a single classification | `content` (text), `color` (see Color Legend below), which `frame` it sits in |
| **Shape** | A container or category marker that isn't itself a unit — rarely the primary element; usually a frame does this job instead | `shape` (rectangle, circle, rhombus, etc.), `content` (optional), `color` |
| **Frame** | A named, boundable region — a Bounded Context, a swimlane, a phase, a quadrant. Groups other items; Miro supports one level of frame nesting, not arbitrary depth | `title`, and which items belong to it (each item declares its frame, not the other way around) |
| **Connector** | An arrow or line between two items, with an optional label — relationships, causality, data flow, dependency | `from`, `to` (both item IDs), `label`, `style` (e.g. arrow, none, dashed) |
| **Text** | A freestanding label or title not attached to any item — a board title, a section heading | `content`, position (only needed when it isn't implied by a frame) |

## Board Spec Format

Two tables — items and connectors — mirroring Miro's own data model, where
items and connectors are separate primitives.

**Items:**

| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| `<short id>` | sticky_note / shape / frame / text | `<the actual text>` | `<frame ID, or "—" if this row is a frame>` | `<see Color Legend>` |

**Connectors:**

| From | To | Label | Style |
|---|---|---|---|
| `<item ID>` | `<item ID>` | `<relationship, or "—">` | arrow / dashed / none |

Every skill producing a board spec includes both tables, even if the
connectors table has zero rows (some boards, like a plain classification
grid, need no connectors at all).

## Color Legend Convention

Miro's sticky note colors are a fixed set: `gray`, `light_yellow`, `yellow`,
`orange`, `light_green`, `green`, `dark_green`, `cyan`, `light_pink`, `pink`,
`violet`, `red`, `light_blue`, `blue`, `dark_blue`, `black`. This skill does
not assign meaning to them — that's domain-specific (a Core Domain sticky
note means something different in a classification canvas than a "blocked"
card means in an Event Storming board). **Every skill using this notation
declares its own Color Legend** (a short "this color means this category"
table) immediately above its board spec, so the spec is self-contained
without cross-referencing this file.

## Worked Example

A 3-item board with one connector, showing the format in practice:

Color Legend: `green` = Core Domain, `gray` = Generic Subdomain.

**Items:**

| ID | Type | Content | Frame | Color |
|---|---|---|---|---|
| F1 | frame | Entity Extraction Bounded Context | — | — |
| S1 | sticky_note | Entity Extraction Aggregate | F1 | green |
| S2 | sticky_note | Authentication (external library) | — | gray |

**Connectors:**

| From | To | Label | Style |
|---|---|---|---|
| S1 | S2 | consumes identity from | arrow |

## Applying This Notation

No live Miro connection exists in this environment yet. A board spec
written this way is immediately useful two ways regardless: Shafi (or
anyone) can build it by hand in Miro directly from the tables, and once a
real Miro API/MCP connection exists, the same tables map directly onto
Miro's item/connector creation calls — no reformatting needed at that point.
