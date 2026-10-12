---
type: llm
weight: 1
---

The response says the general, durable argument should be recorded as an Architecture **Principle**, not inside the ADR's Rationale, because reasoning that applies unchanged to many future decisions would disappear if that one ADR were ever superseded. It says ADR-012's Rationale should cite the Principle instead of restating it. It mentions at least one plugin-specific detail of how Principles are kept: a Principle record with its own ID (e.g. PRINCIPLE-NNN), stored in a single evolving catalog (PRINCIPLES.md) alongside the ADRs, or a "Cited By" list linking back to ADRs. Fail if it recommends keeping the argument in the ADR or only says "write another ADR".
