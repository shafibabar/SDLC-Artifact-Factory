---
name: system-context-diagram
description: >
  Draw a product's C4 System Context diagram (Level 1), the first
  architecture view: the system being built as one box, the people (roles,
  never a generic "User") who use it, and the external software systems it
  depends on or that depend on it, with one-directional labelled arrows.
  Decides the system boundary by ownership ("do we build and run it?": a
  service another team owns is external; our own frontend, mobile app,
  database or message broker is a container inside the box, shown at Level
  2). Covers the title and key (what an arrow means), type stated in text
  not colour, ASCII as the primary notation with Mermaid C4Context optional
  (never at lean), the element catalog, rationale and boundary notes with
  what is out of scope, keeping names identical on the container diagram,
  and when to redraw. Use when drawing, reviewing or updating a system
  context diagram, deciding what is inside or outside the system, or
  listing its users and integrations. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, system-context, documentation, external-actors, system-boundary]
produces: system-context-diagram
domain: architecture
status: stable
related: [container-diagram, component-diagram, user-persona, event-storming-facilitation, bounded-context-mapping, nfr-specification, integration-design, glossary-management]
sources:
  - research/software-architecture/c4-model-brown.md
  - research/software-architecture/documenting-software-architectures-clements.md
  - research/software-architecture/just-enough-software-architecture-fairbanks.md
---

# System Context Diagram

## Purpose

The System Context diagram is C4's Level 1 (Brown, `c4-model-brown.md`). It answers one question for every reader, the product owner included: **what is this system, who uses it, and what other systems does it work with?** It is the first architecture view, drawn before the container diagram, because a wrong scope makes every view beneath it wrong, and this is the cheapest place to catch one.

**Name its readers and its question first** (Clements: a view serves named stakeholders and their concern; Fairbanks: a model earns its cost by answering a named question). The readers are the product owner and the people the product owner shows it to: executives, partners, regulators, new team members. None of them needs the internal split, technology or deployment to answer the question, so those stay off this view; say so when declining a request to add them.

One artifact per product: `design/architecture/system-context.md`, required at every profile (`./templates/system-context.md`).
- **Lean:** one ASCII diagram, its key and the element catalog; rationale and boundary notes in a sentence or two each. No Mermaid, no supplementary diagrams.
- **Standard:** the same, in full. Mermaid only if the user wants a rendered copy.
- **Enterprise:** the same, plus boundary notes that name what is out of scope and the other organisations' systems, and every external system's owner.

What this skill does **not** hold: containers, technology and the deployment view (`container-diagram`, D047-13); how each integration works (`integration-design`); the personas themselves (`user-persona`).

## 1. Three Element Types, and Only Three

- **The system:** exactly one box, the software system being built, named as the product names it in its Ubiquitous Language, with one sentence on what it does for its users, never how.
- **Person:** a role, not a named individual and never a generic "User". Ten coordinators are one `Coordinator`. Each persona that uses the system, and each actor in the Event Storming timeline, is one person; two personas that are the same role collapse; one "Admin" that covers two roles splits.
- **External software system:** a whole system someone else owns and runs, that the system calls or is called by, named as its owner names it (`Stripe`, `the council's planning portal`).

Every element states its **type in text** (`[Person]`, `[Software System]`, `[External System]`), its name and a short description (Brown). Colour is a house choice and never the only way type is shown. Anything that is none of these three types is inside the box and invisible here.

## 2. The Boundary: Do We Build and Run It?

Ownership decides, not network location (`./references/boundary-identification.md`):
- **We build and run it** → a container inside the box, drawn at Level 2: the web app, the mobile app, the API, the database we provision, the broker we run, the scheduler, the background worker. "Is our frontend a separate system?" No: it is a container of this one.
- **Another team or organisation owns and runs it, and we integrate** → an external system, even inside the same company (Brown's ownership rule: another team's service is its own software system). A shared platform our own team runs stays inside.
- **A human uses it** → a person.
- **Still unsure:** whose pager fires when it fails at 3 a.m.? Ours: inside. Theirs: external.

Sources to inventory, so none is forgotten: the personas, the Event Storming timeline's actors and external systems, the Context Map's upstream and downstream systems (an Anti-Corruption Layer always faces an external system), the stories, and the NFR specification's integrations and constraints (identity, payments, notifications, regulators, data residency).

## 3. Relationships

- **One-directional, labelled with what flows**, as a phrase that reads from the arrow's start to its end ("Books a class in", "Sends payment requests to", "Sends hourly readings to"), the same on the diagram and in the relationships table. A bare noun ("Payment requests") doesn't say which way it goes. Never "uses", "integrates with" or "interacts with", and never a two-headed arrow: draw two arrows, each with its own label.
- **A request and its reply are one exchange:** one arrow from the side that asks, labelled with the request ("Signs users in through"), never "…and gets X back from". A second arrow only when the other side starts an exchange of its own (a webhook, a pushed file).
- **What an arrow means is stated in the key**, once for the diagram. The plugin's default: the arrow points from the party that starts the exchange.
- **Every arrow touches the system box.** Arrows between two external systems, or between a person and an external system, are not this view's concern.
- **Protocol is optional and plain** ("HTTPS", "OIDC", "SFTP file drop", "webhook"), never a library or framework.
- Every person and external system has at least one arrow; an element with none doesn't belong.

## 4. Title, Key and Notation (D047-13)

- **Title** states type and scope: `System Context diagram for <System>`.
- **Key:** the element type tags, line styles, and what an arrow means (Brown's review checklist: a diagram that doesn't explain itself fails).
- **ASCII is the primary presentation**, in a fenced block, with the element catalog tables beside it, so the product owner can review it as plain Markdown. Each element's name sits on one line of its box.
- **Mermaid is optional** (standard and enterprise only, never at lean) and secondary: use its `C4Context` type, still marked experimental in Mermaid, rather than `flowchart`. Structurizr DSL is a free option for teams that want one model behind every level; never required.
- System Landscape (all of an organisation's systems) and Dynamic (a numbered flow) diagrams are optional C4 extras, drawn only when a named reader needs them; neither replaces this view.

Notation detail, the review checklist and a Mermaid C4Context skeleton: `./references/c4-context-notation.md`.

## 5. A View, Not Just a Picture (Clements)

The diagram is the primary presentation of a view; the documentation package around it makes it a specification the container diagram can build on:
- **Element catalog:** the system, the persons and the external systems (owner; third-party, partner or customer-owned; what it provides or receives) and every relationship (from, to, what flows, protocol).
- **Rationale:** why this boundary and these external systems: the view's shape, not a cross-cutting decision (that is an ADR).
- **Boundary notes:** the constraints that force the boundary (data residency, a regulator, a contract), and **what is out of scope**: things a reader might expect the system to do that another system does.

## 6. Keeping It True

- **Names carry down unchanged.** Every person and external system on the container diagram appears here with the same name; "Stripe" doesn't become "Payments API" at Level 2. If a container diagram already exists, use its names, or rename on both diagrams together; never a friendlier name on one only. With hand-drawn diagrams no model enforces this (Brown), so the container diagram's checklist compares the two catalogs.
- **Redraw** when a role or an integration is added or removed, and re-present it: a changed approved artifact returns to draft for re-approval (#1288). A stale context diagram silently contradicts the views beneath it.

## Procedure

1. **Read** the problem statement and the product manifest, `ideate/user-personas.md`, `design/event-storming/big-picture.md` (actors and external systems), `design/context-map.md`, the stories, and `ideate/nfr-specification.md`. If one is missing, carry on: mark each element you inferred *assumed* and list it under *Open questions*.
2. **Inventory** every candidate person and system from those sources, with where each came from.
3. **Classify** each candidate with the ownership test (§ 2). Containers drop out of this view; note the notable ones in the rationale ("the mobile app and the API are containers of this system").
4. **Name the readers and the question** (§ Purpose) at the top of the artifact. **Draw** the ASCII diagram with its title and key (§ 4), one box for the system, then each person and external system, then the arrows (§ 3).
5. **Write** the element catalog, rationale and boundary notes (§ 5). At standard or enterprise, add a Mermaid `C4Context` copy only if the user asks.
6. **Validate, then loop.** Run `./scripts/validate-system-context.sh design/architecture/system-context.md`, fix every FAIL and re-run until it exits clean; then go through `./resources/checklist.md`.
7. **Present** it to the user for approval before the container diagram: the readers and the question, the diagram, and the reason for every request declined (§ Gotchas), tied to what those readers need. Hand on to the container diagram with the names as they stand.

Examples: `./examples/01-lean-internal-tool.md` (one person, two external systems, a database and a nightly job kept off the diagram), `./examples/02-standard-b2b-saas.md` (identity provider, payment provider, an outbound webhook consumer, a billing service another team owns, the mobile app as a container, a Mermaid C4Context copy), `./examples/03-enterprise-partner-and-regulator.md` (partner organisations' systems, a regulator feed, a legacy system being replaced, and what is out of scope).

## Gotchas

Each trap comes with the reason to give in full.

- **"Put the database and the message broker on it, so people see the whole picture."** *Reason:* they are containers we run, inside the system; its readers (the product owner, executives, partners) need who uses it and what it works with, not its parts, and mixing levels makes the one diagram everyone can read unreadable (Brown). *Instead:* they go on the container diagram; say so in the rationale.
- **"Draw the frontend and the backend as two systems,"** or "the mobile app is its own system." *Reason:* both are containers of the one system we build; two boxes fragment the boundary and show users talking to halves of an implementation. *Instead:* one box; the split is Level 2.
- **"The billing service is ours, it's the same company, so leave it inside."** *Reason:* another team owns and runs it; we depend on its contract and its outages (Brown's ownership rule). *Instead:* an external system, its owning team named in the catalog.
- **"Just one 'User' box."** *Reason:* it hides different roles with different needs, permissions and arrows. *Instead:* one person per role, named in the product's language.
- **"Blue for us, grey for external; the colours say it all."** *Reason:* colour isn't part of C4, is lost in plain Markdown, and fails readers who can't tell colours apart. *Instead:* the type in text on every box, and a key.
- **"Label the arrows 'uses'," or "one arrow with heads on both ends."** *Reason:* it hides who starts the exchange and what flows. *Instead:* one direction per arrow, a label naming what flows, the arrow meaning in the key.
- **"Mermaid only, it renders nicer,"** or Mermaid at lean. *Reason:* the plugin's one rule for C4 is ASCII primary with the catalog tables, Mermaid optional (D047-13); lean keeps one diagram. *Instead:* ASCII first; a Mermaid `C4Context` copy at standard or enterprise if asked.
- **"Add the cloud provider, Kubernetes, the CDN and our Docker images."** *Reason:* they are where and how our containers run, not systems anyone exchanges data with; and a C4 container is a runnable unit (an app, an API, a database), not a Docker container (Brown). *Instead:* images, clusters and nodes go to the container diagram's deployment section; a vendor service we exchange data with (email, payments) is external.
- **"Show each of our microservices as its own system so people see how it splits."** *Reason:* one team builds them, so they are containers of one system; decomposition is decided and drawn on the container diagram (D047-6). *Instead:* one box; the rationale points to the container diagram.
- **"Use friendlier names for the executives."** *Reason:* names that differ between levels make a reader think there are two systems, and nothing keeps hand-drawn diagrams in step. *Instead:* the names the container diagram uses; a friendlier description inside the box if needed.
- **"A picture is enough; skip the tables."** *Reason:* without the catalog and rationale it is "just a picture" (Clements): reviewable by eye, not something the container diagram can be built from. *Instead:* catalog, rationale and boundary notes every time, a sentence each at lean.

## References

| Question | File |
|---|---|
| Element types, arrows, title and key, review checklist, Mermaid C4Context, where C4 sits beside Clements' views | `./references/c4-context-notation.md` |
| Inside or outside: the ownership test, the hard cases, finding every person and system | `./references/boundary-identification.md` |
| The artifact skeleton | `./templates/system-context.md` |
| Checking before hand-off | `./resources/checklist.md` |
