# Example 1 — Lean: A Table in the Domain Model, No Document

Self-contained. **Plotline** runs the waiting list and plot inspections for one allotment society: 120 plots, one deployable, contexts **Plots** and **Inspections**. **Lean** profile: no CQRS decisions record and no `read-models.md`; every context uses a Simple Read Model, and Read Models are a table in `design/domain-model.md`.

## Input

> **User:** "Give each Aggregate a matching view (PlotView, ApplicantView, InspectionView) built by a projector, so screens never touch the real tables."

## Working it

- **Rung:** lean has no projections unless a trigger is named, and none is: a few hundred rows, a committee of five reading them. Projectors would add lag (a secretary records an inspection and the list still shows it as due) and things to keep running, for nothing.
- **"A view per Aggregate"** is declined on its own grounds too: the screens ask questions, not Aggregates. "Who is next for a plot?" needs the applicant and the date they joined; "which plots are due an inspection?" needs plot, tenant name and last inspection, across both contexts' tables in the one database.
- **What the user wants to protect is kept:** screens read through their own query types and never load the Plot or Inspection models; changes go through the models.

## Output: the Read Models section of `design/domain-model.md`

| Context | Read Model | Answers | Built from | Staleness accepted |
|---|---|---|---|---|
| Plots | WaitingListOrder | the secretary: who is next for a plot, in joining order | applicant table, ordered by joined date (query type, not the Applicant model) | immediate |
| Plots | VacantPlots | the committee: plots free to offer, with size | plot table where no current tenancy | immediate |
| Inspections | PlotsDueInspection | the inspector: plots not inspected this season, with the tenant's name | plot and tenancy tables joined to the latest inspection | immediate |

## Why this is right

- Lean needs no document: three rows in the domain model say what each screen reads.
- Each Read Model answers one question and joins whatever it needs; none mirrors an Aggregate.
- Nothing is projected, because nothing named a trigger; the reason was given in full.
