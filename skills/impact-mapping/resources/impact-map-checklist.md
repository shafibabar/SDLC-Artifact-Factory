# Impact Map — Hand-off Checklist

Self-contained. Validate the artifact against every row before hand-off. Rows marked **(script)** are also checked by `../scripts/check-impact-map.py`.

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase: ideate`, `owner`, `created`, `summary`, `profile`, `goal`, `linked-kr`, `linked-tree`, `selected-path` **(script)** | Any missing; `phase: strategy`; `profile: lean` (lean skips the map) |
| 2 | The map was written after the opportunity solution tree and before the functional requirements | Drawn from requirements or a backlog that already existed (backwards mapping) |
| 3 | Goal in fields: metric, meter, baseline, target, deadline, optional constraint, copied from the tree's root and the KR **(script: rows exist)** | A prose goal; invented numbers; "not set in KR" missing where the KR lacks a field |
| 4 | The goal is the tree's product outcome | Revenue, retention or a feature's usage as the goal |
| 5 | Actors found by the four questions (produce, obstruct, use, affected); each specific enough to observe | "The customer", "IT", "the market" |
| 6 | At least one Blocker, or a "No blocker:" line with the reason **(script)** | Only supporters |
| 7 | Every impact is an actor's behaviour change, phrased against the current behaviour **(script: warns on "uses the")** | "Uses the dashboard"; the system's behaviour; a team activity |
| 8 | Every impact on the selected path has a signal **(script)** | "It shipped"; no way to observe the change |
| 9 | Opportunity column between HOW and WHAT; the selected path cites the tree's target opportunity; others cite an OPP-ID or "— not on tree" **(script: target cited)** | No opportunity column; the path's impact unexplained by any opportunity |
| 10 | Under the target opportunity's impact, the tree's carried-forward solutions are the candidates | Solutions re-generated or a favourite added that the tree never compared |
| 11 | Elsewhere: two passes, the second under a constraint; at least one non-software option per impact near the path | Features only; one candidate per impact |
| 12 | Path / Assumption / Signal columns; Path is `selected` or `option`; no priority **(script)** | A Priority or MoSCoW column; "Must" / "Could" in a cell |
| 13 | One selected path (actor → impact → opportunity → deliverables), confirmed by the user **(script: a selected row exists)** | Every branch committed; no path; the agent decided alone |
| 14 | Selected Path assumptions cover deliverable → impact and impact → goal links, typed desirability / viability / feasibility / usability / ethical **(script: valid types)** | Untyped; only one kind of link |
| 15 | At least one ethical assumption considered on the path **(script: warning)** | Nobody asked who is affected or what could harm them |
| 16 | Assumptions ordered by importance × evidence; tests cite the tree's T-n or carry a numeric criterion set before running | "See if it works"; a criterion written after the result |
| 17 | A re-plan trigger with signals and dates for both failure kinds **(script: section exists)** | No trigger; a one-time scope document |
| 18 | The path is not called an MVP; the walking skeleton is left to the story map **(script: warns on an MVP heading)** | "MVP scope" section |
| 19 | Small: one goal, a handful of actors, detail only where the next choice is | Hundreds of nodes |
| 20 | Standard: one map; other KRs under "Not mapped this cycle". Enterprise: one map per product outcome in scope, shared actor names and persona IDs | A map per KR in the OKR set; one actor described two ways |
| 21 | Hand-off names requirements, epics, story map and MoSCoW consumers | No hand-off |
| 22 | Canonical glossary terms; product-specific actors only in this product's map | "MVP scope", "feature goal"; a compliance actor added because an example had one |
