---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're implementing a Go repository in this SDLC Artifact Factory plugin, using pgx v5.7. One UPDATE statement takes six parameters (sensitivity, classified_by, classified_at, id, tenant_id, expected version). Following this plugin's Go repository standard, how should the parameters be written in that statement, and why that way rather than the alternatives?
