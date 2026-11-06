# System Context Checklist

Run after `./scripts/validate-system-context.sh` exits clean. The script checks structure; these items need judgement.

## Inventory
- [ ] Every persona that uses the system, and every actor in the Event Storming timeline, is a person, or the rationale says why not.
- [ ] Every external system on the Event Storming timeline and the Context Map is on the diagram.
- [ ] The stories and the NFR specification were checked for the usual forgotten systems: identity provider, email or SMS, payments, a regulator or auditor, a downstream consumer of our webhooks or files.
- [ ] Every inferred element is marked *assumed* and listed under Open Questions.

## Boundary
- [ ] One box for the system we build; our apps, APIs, databases, brokers, jobs and workers are inside it and named in the rationale as containers.
- [ ] A service another team or organisation runs is external, its owner named; a shared platform our own team runs is inside.
- [ ] No infrastructure (cloud, cluster, CDN, DNS) appears as an external system.
- [ ] Persons are roles in the product's language; no "User", no named individuals; duplicates collapsed, lumped roles split.

## Relationships
- [ ] Every arrow is one-directional, touches the system box, starts at the party that starts the exchange, and names what flows.
- [ ] Two-way exchanges are two arrows.
- [ ] Protocols, where shown, are plain words, not libraries or frameworks.

## The package
- [ ] Title and key; the key states what an arrow means; types are in text, not colour alone.
- [ ] System description says what it does for its users, never how it is built; no technology anywhere on the diagram.
- [ ] Rationale explains the shape; Boundary Notes give the constraints and what is out of scope.
- [ ] Lean: no Mermaid. Standard or enterprise: Mermaid only if asked, as a `C4Context` copy with the same names and arrows.
- [ ] Names are the ones the container diagram will use; if a container diagram already exists, its persons and external systems match these exactly.
