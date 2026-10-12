---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

While writing ADR-012 (choosing asynchronous events between the Billing and Usage Bounded Contexts), our architect's Rationale section grew a long passage arguing that "across Bounded Contexts we should always prefer asynchronous communication." Following this plugin's ADR guidance, where should that general argument live, what is it called, and how does ADR-012 relate to it?
