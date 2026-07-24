# Access Control Model Output Format Template

Self-contained — loadable without reading `SKILL.md` first.

This is the **annotated** version. For a literal, fill-in-and-go copy, use `assets/access-control-model-template.md` directly, or run `scripts/scaffold-access-control-model.sh <product>` to generate a new design doc from it.

---

```markdown
---
name: access-control-model
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Access Control Model

## Attribute Schema
[Subject, Resource, Action, Environment attributes with sources]

## Domain Primitives
| Type | Constructor | Invariant enforced |
|---|---|---|

## Policies
| Policy ID | Rule (natural language) | Attributes evaluated | Decision |
|---|---|---|---|

## Role → Permission Mapping
| Role | Permissions |
|---|---|

## Permission Registry
| Permission | Resource type | Action | Description |
|---|---|---|---|

## Per-Aggregate Trust-Boundary Decisions
| Aggregate | Multi-tenant reachable? | Authorization required? | Expressed as domain concept? |
|---|---|---|---|

## Go Policy Interface
[Policy interface and Subject/Resource/Action types, using Domain Primitives]

## Enforcement Locations
| Layer | What is checked | Who calls the policy |
|---|---|---|
```
