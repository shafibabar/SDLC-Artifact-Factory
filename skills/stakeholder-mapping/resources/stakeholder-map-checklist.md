# Stakeholder Map — Hand-off Checklist

Validate the artifact against every row before hand-off. Rows marked **(script)** are also checked by `../scripts/check-stakeholder-map.py`.

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase`, `owner`, `created`, `summary`, `profile` | Any missing; `summary` is generic |
| 2 | Profile matches `phase-requirements.json`: none at lean unless the user asked; full shape at standard / enterprise | A lean product given a grid and committee; an enterprise map with one committee for all tenant types |
| 3 | Delivery stakeholders and the buying committee are separate sections **(script)** | One table or one grid holds both |
| 4 | Delivery entries are real roles the team engages; no personal name for the product owner | Archetypes ("CFOs at mid-size firms") in the delivery register |
| 5 | Scale stated: High/Low with a reason, or 1–5 with "3 and above is High" | 1–3 scores; a midpoint with no rule |
| 6 | Each quadrant matches its power and interest under the stated scale **(script)** | High power, low interest placed in Monitor |
| 7 | Every Keep Satisfied stakeholder has a mitigation delivered before their request | "Keep satisfied" with no action |
| 8 | Engagement plan: need, channel, cadence, a person as owner, a re-score trigger | "As needed"; an agent as owner |
| 9 | Pre-wiring order for the next gate review (standard and enterprise) | Group review with nobody seen first |
| 10 | Exactly one Accountable per decision **(script)** | Two As, or none |
| 11 | No AI agent or hook is Accountable **(script)** | "backend-engineer agent" in the A column |
| 12 | A sign-off that can block a release is an Agree, not a Consulted | Security reviewer as C on the release gate |
| 13 | Committee: every role has belief, objection, proof, likely profile, loss by staying put, how confirmed | Titles only |
| 14 | One Mobilizer hypothesis and one Blocker per segment, labelled likely; cost of no decision stated | "CISO = Blocker" as fact; no Mobilizer |
| 15 | No cadence, channel or newsletter in the committee section **(script)** | "Monthly update" to a role |
| 16 | Blocker Risk Register covers both halves, with the kind of trust and a lever that fits it | Only factual briefs, even for a doubt about automated outputs |
| 17 | Enterprise: a committee per segment or tenant type, collective-learning plan, consensus kit, regulator / auditor salience, influence links | Any missing |
| 18 | Canonical glossary terms only | "Champion" used for the Mobilizer; "decider" for Accountable |
