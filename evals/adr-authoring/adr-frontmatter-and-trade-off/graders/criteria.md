---
type: llm
weight: 1
---

Both parts follow this plugin's ADR format:
1. The frontmatter contains the plugin's standard artifact fields `name` (e.g. adr-007-use-redis-for-session-cache), `version`, `phase` (design), `owner`, `created` and `summary`, AND the ADR fields `adr-id` (ADR-007), `title`, `status` and `deciders`.
2. The Rationale section contains an explicit line labelled "Trade-off:" (e.g. `**Trade-off:**`) that names the specific architecture characteristics being traded against each other (for example latency/performance over durability or operational simplicity).
Fail if the frontmatter lacks any of name, version, phase, owner, created, summary, adr-id, title, status, deciders, or if there is no explicit Trade-off line.
