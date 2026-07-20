---
description: Run an Event Storming session for a domain or subdomain, standalone from the full Design phase
argument-hint: [domain-or-subdomain-name]
disable-model-invocation: true
---

Facilitate an Event Storming session, independent of a full `/sdlc-design` run — use this when a new subdomain needs modelling later, or to re-run storming on an existing domain.

1. Read `sdlc-context.json` for product context. The domain or subdomain to storm is `$ARGUMENTS`; if empty, ask the user which one.
2. Invoke the `domain-modeler` agent via the Agent tool, directing it specifically to the `event-storming-facilitation` skill for this domain. Give it any existing Ideate-phase requirements relevant to this domain.
3. The agent produces the Domain Story (if needed), the Event Storm session output (Domain Events, Commands, Aggregates, Bounded Context boundaries, hotspots), and updates the Ubiquitous Language and Context Map for this domain.
4. Confirm any downstream artifacts that already exist (Container Diagram, API contracts) are flagged for review if this session changed Bounded Context boundaries — those artifacts do not update themselves.
