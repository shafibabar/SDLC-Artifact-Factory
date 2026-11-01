# NFR Specification — Hand-off Checklist

Self-contained rule set for the `nfr-specification` skill. Check every row before presenting the artifact. Then run the skill's `../scripts/check-nfr.py <artifact>` with `python3` for the mechanical rows marked **(script)**.

| # | Check | Fails when |
|---|---|---|
| 1 | Frontmatter has name, version, phase (`ideate`), owner, created, one-sentence summary, profile **(script)** | Any is missing; phase is not ideate |
| 2 | Every QA-n in the FRD's hand-off (lean: the backlog header's quality concerns) appears in Inputs Consumed, with what it became or why it was declined | A hand-off item is silently dropped |
| 3 | Rules are cited, not restated: each obligation row cites a BR-n **(script)**; no residency, retention or control rule is written here that is not in the FRD | A rule with two homes; an obligation with no BR-n |
| 4 | Every characteristic (ISO/IEC 25010's nine plus deployability) is kept or declined with a reason | A characteristic left unexamined |
| 5 | Every scenario has stimulus, environment, response measure, traces and verification **(script)**; at standard and enterprise the table also has source, affected part and response | A target with no environment; no verification |
| 6 | Targets match the profile: Must at lean; Must and Plan at standard; Must, Plan and Stretch at enterprise **(script)** | Missing Plan at standard; no Stretch at enterprise |
| 7 | Latency as percentiles with load; no averages for latency **(script warns)** | "Average response time" |
| 8 | Each Plan value names its business driver | A nine with no reason |
| 9 | Availability written as failure scenarios (detect, recover, RTO, RPO), not only an uptime figure | "99.9% uptime" alone |
| 10 | At least one deployability scenario **(script)** | Deployability missing |
| 11 | No DORA rate (deployment frequency, lead time for changes, change failure rate) among the scenarios; any such target sits under Process Targets with a user-chosen value and `dora-metrics` as calibration **(script)** | A DORA cluster copied as an NFR |
| 12 | Scale: lean holds 3–8 scenarios **(script warns)**; enterprise has a utility tree **(script)** | 20 scenarios at lean; no tree at enterprise |
| 13 | Ranking present; every scenario rated H on architectural impact is in the Architecture Handoff and the frontmatter list **(script)** | An ASR missing from the handoff |
| 14 | Conflict check run: candidate trade-off points recorded, or "None found" | Two clashing H scenarios with no trade-off point |
| 15 | No tactic chosen as a requirement ("use a service mesh", "add a cache") | A design decision written as an NFR |
| 16 | Derived requirements sent back to the FRD and listed | An implied behaviour left only here |
| 17 | Canonical terms: quality-attribute scenario (never a bare "scenario"), Planguage Must kept apart from MoSCoW | Term drift |
