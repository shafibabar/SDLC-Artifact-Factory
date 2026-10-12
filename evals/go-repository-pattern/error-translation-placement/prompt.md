---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

For this plugin's Go repositories over pgx, a teammate wants one shared file, internal/infrastructure/errors.go, that every repository uses to translate pgx errors. They also want a server-side Postgres statement_timeout and a client-side context deadline to become two different domain errors, so callers can tell them apart. Following this plugin's Go repository standard, respond to both proposals.
