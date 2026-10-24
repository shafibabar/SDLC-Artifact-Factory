# Opportunity Solution Tree — Hand-off Checklist

Self-contained. Validate the artifact against every row before hand-off. Rows marked **(script)** are also checked by `../scripts/check-opportunity-solution-tree.py`.

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase: ideate`, `owner`, `created`, `summary`, `profile`, `desired-outcome`, `outcome-type`, `evidence`, `target-opportunity` **(script)** | Any missing; `phase: strategy` |
| 2 | The root is a **product outcome** (or a product outcome stated as a learning goal) **(script: `outcome-type`)** | `outcome-type` is a business outcome or traction metric; revenue, churn or a feature's usage at the root |
| 3 | A business-outcome KR is linked to the root by a stated belief, listed as a viability assumption; a traction-metric KR's feature appears as a candidate solution | The KR silently replaced, or copied to the root unchanged |
| 4 | Root fields (metric, meter, baseline, target, deadline) come from the linked KR; missing ones say "not set in KR" | Invented numbers |
| 5 | Desired outcome (root metric) and desired-outcome statement (`jtbd-analysis`) kept apart | A "Minimize the time it takes to …" line at the root |
| 6 | Every opportunity is in the customer's voice and passes "more than one solution could address it" **(script: warns on solution words)** | "Add a dashboard", "Slack integration", "export button" as opportunities |
| 7 | Top level = experience steps; every child has exactly one existing parent **(script: parents exist)** | Orphan rows; a flat list called a tree (standard, enterprise) |
| 8 | Every opportunity cites snapshots or feedback items that are listed under Evidence, or is tagged `[assumption]` **(script)** | Uncited rows; a citation not listed; `evidence: none` with citations |
| 9 | Story counts count independent conversations or feedback items | Two mentions in one conversation counted twice |
| 10 | Prioritisation compares siblings under one parent, level by level, on sizing, market, company and customer factors; small-n ratings labelled directional | One flat ranked list of every node; numeric scores presented as a survey result |
| 11 | One **target opportunity**, existing in the tree, chosen by the user, with its reason **(script: target exists)** | No target; several targets; the agent decided alone |
| 12 | Standard / enterprise: about three solutions carried forward for the target, at least one non-software where one exists **(script: ≥ 2 carried forward)** | One solution; solutions under non-target opportunities |
| 13 | Assumptions typed desirability / viability / feasibility / usability / ethical, with at least one ethical per carried-forward solution **(script: valid types; an ethical row exists)** | Untyped; no ethical assumption |
| 14 | Assumptions ranked by importance × evidence; tests aimed at important, low-evidence ones | Testing what is already well evidenced |
| 15 | Every test has a numeric success criterion set before it runs **(script: a number in each criterion)** | "See if they like it"; a criterion written after the result |
| 16 | Tests compare across the solution set where possible; the user runs anything involving a customer | Whether-or-not test of one favourite; "the agent will interview" |
| 17 | Results are recorded in dated `ideate/assumption-tests/` files, each with `criterion-set-on` on or before `run-on` | Results appended to the approved tree between cycles |
| 18 | Lean: one outcome, three to seven ranked opportunities, a target and one or two ideas **(script: Rank column; row count warning)** | A full tree at lean; an unranked list |
| 19 | Enterprise: one tree per product outcome; a segment / tenant-role column; story counts never pooled across segments; a test-tracking table **(script: segment column warning)** | One tree mixing outcomes; one segment's need averaged into another's |
| 20 | Hand-off names what goes to `impact-mapping` (WHY, the opportunity behind the HOW, WHAT candidates), and a re-plan trigger is written | No hand-off; no way to know when to revisit |
| 21 | Canonical glossary terms | "Pain point score", "feature opportunity", "goal" for the root |
