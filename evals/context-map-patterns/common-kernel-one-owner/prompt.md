---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Matchday Ledger**, a platform that amateur sports leagues use to run a season: player registration, fixture scheduling, referee assignment, and match results with disciplinary points. We're on the **standard** profile. This plugin's agents design and build every part of it, and I'm the only person who owns it; there are no separate development teams.

The Bounded Contexts are already agreed: **Registration**, **Fixture Scheduling** (Core), **Referee Assignment** (Core), and **Results & Discipline**.

The design agent's draft Context Map has two lines I'm unsure about:

1. **Fixture Scheduling ↔ Referee Assignment: Partnership.** Its reasoning: "these two are tightly coupled, because a fixture can't be confirmed until a referee is assigned and a referee's availability moves fixtures, so the two teams should plan their changes together."
2. **A Shared Kernel used by all four contexts**, held in a package called `league-common`. Right now it contains: Player, Team, Club, Venue, Season, Fixture, Referee, RefereeGrade, MatchResult, Card, Suspension, RegistrationFee, Address and DateRange, about 60 fields in total. Every context imports it, and whoever needs a new field adds it.

For each of the two, tell me whether the pattern is right, and if not, what you'd draw instead and why. Use this plugin's context-map-patterns skill, and give me the answer in your reply, not in a file.
