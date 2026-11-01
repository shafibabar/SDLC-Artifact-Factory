# JTBD Analysis — Hand-off Checklist

Self-contained. Validate the artifact against every row before hand-off. Rows marked **(script)** are also checked by `../scripts/check-jtbd-analysis.py`.

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase: ideate`, `owner`, `created`, `summary`, `profile`, `evidence` **(script)** | Any missing; `phase: strategy`; `profile: lean` (no artifact at lean: JTBD folds into the persona) |
| 2 | Every core job has one **job statement** labelled as such, `[verb] [object] [clarifier]`, solution-free, passing the fifty-years test **(script: present, not in job-story form)** | A job story under the "job statement" label; a product named; task altitude |
| 3 | Job stories are labelled as job stories, sit under one job statement, one per situation, in `When…, I want to…, so I can…` form **(script)** | Stories with no parent job; several motivations fused in one story |
| 4 | No motivation clause names a product output ("see a list", "get a report", "use the dashboard") | Solution leakage |
| 5 | Every job story cites at least one snapshot that is listed under Evidence, or is tagged `[assumption]` with a validation question **(script)** | Uncited stories; a citation to a snapshot that does not exist; `evidence: none` with snapshot citations |
| 6 | Job spec complete per job: three dimensions, obstacles, purchase and use experiences | Functional only; no experiences |
| 7 | What gets fired is listed per job, including non-consumption where it exists **(script: section present)** | Only named competitors |
| 8 | Big Hire and Little Hire, one line each, per job **(script)** | Missing Little Hire |
| 9 | A forces table per job with push, pull, anxiety and habit, each a specific event **(script: four rows)** | Pull only; generic cells ("they want efficiency") |
| 10 | Opportunity is ranked on **desired-outcome statements**, never on jobs **(script: no score on a J- row)** | "J-1: 9 + (9 − 3) = 15" |
| 11 | Outcome statements follow `[direction] [metric] [object] [clarifier]` and are solution-free | "Faster reminders"; "a dashboard" |
| 12 | Ranking method matches the sample: compare-and-contrast with a target outcome at a handful of participants; numeric scores only from a survey, per segment; small-n ratings labelled directional **(script: arithmetic; "directional" label)** | Survey maths on four ratings; one blended average over two segments |
| 13 | Onboarding requirements derived from consumption jobs, obstacles, experiences, the Little Hire, anxiety and habit **(script: section present)** | No onboarding requirements |
| 14 | Executor, beneficiary and buyer named per job; the buyer's financial job written when buyer ≠ executor | Buyer and user blended |
| 15 | Enterprise only: job map with outcomes per step; outcomes ranked per segment / tenant type | One ranking across segments |
| 16 | Interviews attributed to the user or a design-partner session; snapshots marked as synthesised from notes the agent did not witness | "The agent interviewed…" |
| 17 | Persona job statements match this artifact's (or the persona is flagged for update); job stories are not duplicated in the persona | Two different job statements for one job |
| 18 | Canonical glossary terms | "Job statement" used for the story format, "pain score" for opportunity score |
