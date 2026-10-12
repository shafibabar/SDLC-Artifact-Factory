# Insights capabilities — SKILL GEN Project (discovery #1267)

Sources: GitHub Docs pages *About insights for Projects*, *Creating charts*, *Configuring charts* and *Filtering projects* (read 2026-10-12), plus a read-only GraphQL scan of project #1 (1,264 items).

## Confirmed from the docs
| Capability | Finding | Effect on the plan |
|---|---|---|
| Chart API | None. Charts are created and configured only in the web UI (Insights → New chart). | Charts are a UI step (Wave 2e). |
| Layouts | Chosen from the Layout dropdown. The docs don't name them; in the UI they are Bar, Column, Line, Stacked area, Stacked bar, Stacked column. | Use the stacked variants wherever there is a Group by. |
| X-axis | Any field from the dropdown. Setting it to **Time** makes the chart historical. | Single-select and iteration fields work as categories. |
| Group by | Documented **only for current charts**. | Historical charts (burn-up) show status over time. They can't stack by Work Type. |
| Y-axis | Count by default. Sum, Average, Min and Max are offered **only if the project has number fields**. | Effort Points, Cycle Days and Blocked-By Count must be **number** fields. |
| Chart filter | Uses the project filter syntax, saved per chart with "Save changes". | Each chart carries its own scope filter. |
| Filter syntax | `field:value`; quote values with spaces (`status:"In progress"`); `-` negates; `has:`/`no:`; `is:issue`/`is:pr`/`is:open`/`is:closed`; number comparisons such as `points:>=5` and `1..3`; `parent-issue:OWNER/REPO#N`. | Field names avoid spaces where practical. Option values are quoted. |

## Not documented (verify in the UI when charts are built)
- Whether historical charts are available on a **user-owned** project on this plan. Fallback: burn-up becomes a stacked column with X = Sprint, Group by = Status.
- Whether **Parent issue** or **Labels** can be used as an X-axis. Fallback: the Hierarchy and Work Type single-select fields carry that information as categories anyway.
- How to filter a custom field whose name contains a space. Mitigation: use single-word or hyphenated field names (`Work-Type`, `Branch-Type`, `Merge-Target`, `Duration`, `Dependency`, `Data-Source`).
- Chart count limits. None are documented, and 15 charts is a modest number.

## Board baseline (read-only scan)
- 1,264 items: 636 issues, 628 PRs. Status: Done 1,242, Todo 19, In progress 3.
- Custom-field fill: Guild/Sprint/Start date/Target date 28 items each; Sequence 42.
- Hierarchy facts: 23 parents, 193 sub-issues. PR targets: 253 → main, 375 → integration branches.
- Labels: enhancement 379, skill 363, discovery 53, agent 35, documentation 26, bug 11.
- PR head prefixes: issue- 364, arch- 219, feature/ 18, research 8, improve 5, fix 4, fresh 3.

## Decision for Wave 2
The 14-field model and the 15-chart list in the plan stand. Two changes:
1. Field names are hyphenated, so filters need no quoting.
2. Chart 1 (burn-up) is historical with Status as the implicit series. If historical charts are unavailable, it falls back to X = Sprint / Group by = Status.
