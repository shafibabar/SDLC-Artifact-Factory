# Example 1 — A simple lookup skill: no folders at all

Self-contained. Shows the **simplest** correct outcome of the folder decision: everything stays in `SKILL.md`.

## Input — the content inventory

A skill teaching MoSCoW prioritisation for a story backlog:

- the four categories and what each one means (≈15 lines);
- one rule: Must Haves capped at about 60% of the release's effort (≈5 lines);
- a short "how to run the session" procedure (≈20 lines);
- quality criteria and anti-patterns (≈25 lines);
- one 6-row illustration of a prioritised backlog (≈10 lines).

## Decision, content by content

| Content | Folder test | Result |
|---|---|---|
| Categories, 60% rule, procedure | Decision-shaping; needed on almost every invocation | Body |
| Quality criteria, anti-patterns | Decision-shaping and short | Body |
| 6-row illustration | An example, but only 10 lines and needed to understand the categories | Body: too small to earn a file |

## Output — the layout

```
skills/moscow-prioritization/
└── SKILL.md        ~80 lines below the frontmatter
```

No `references/`, `templates/` or `examples/`. Creating any of them here would be a **speculative folder**: structure the content doesn't have.

**What would change this:** if the skill grew to cover prioritising across three product tiers of a SaaS platform, each with its own capacity rule, those cases would earn an `examples/` folder (see Example 2).
