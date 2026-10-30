# User Personas — Hand-off Checklist

Self-contained. Validate the artifact against every row before hand-off. Rows marked **(script)** are also checked by `../scripts/check-user-personas.py`.

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase: ideate`, `owner`, `created`, `summary`, `profile`, `grounding`, `review-by` **(script)** | Any missing; `phase: strategy`; generic `summary` |
| 2 | Shape matches the profile: lean 1–2 personas with JTBD folded in; standard with the variable table; enterprise with personas per tenant role, matrix and foundation | A lean set with a feature matrix; an enterprise set with one persona per role across all tenant types |
| 3 | Every persona block has a `Grounding:` line; every PROTO line names the author, the inputs and "no user research" **(script)** | "PROTO" alone; "team assumptions" |
| 4 | No RESEARCH label unless every load-bearing attribute is interview-tagged and the user confirmed it; never with `evidence: none` **(script, the evidence part)** | An agent-applied RESEARCH label |
| 5 | Every attribute carries a source tag; interview tags point at notes the user supplied | Untagged attributes; an interview tag with no notes behind it |
| 6 | Every PROTO or MIXED persona has validation questions about specific past events, each with a "wrong if" **(script: presence)** | No questions; hypotheticals ("would you use…?") |
| 7 | Every persona has exactly one `Type:` from the six; at least one Primary; no two Primaries share an interface **(script)** | A persona with no type; "Buyer" or "Champion" as a type; two primaries on one surface |
| 8 | Buyer and daily user are separate personas when they differ; served personas where the product acts on non-users; one negative persona | One blended "user"; patients, clients or data subjects ignored |
| 9 | Goals split into end and experience goals (life goals optional); all solution-free | One "Goals" list; "wants our dashboard" |
| 10 | Trigger, current approach and adoption barrier present for every primary (push, habit, anxiety) | Missing current approach: no switching story |
| 11 | Trust in automated output recorded wherever the product drafts, classifies or decides | Silent on trust for an automation product |
| 12 | Job field: one job statement at standard and enterprise; job stories and a forces line only at lean **(script: warns on job stories outside lean)** | Job stories duplicated from `jtbd-analysis` |
| 13 | Personas that differ only in demographics or title are merged; gaps in the variable mapping are flagged | Two personas with identical variables |
| 14 | No age, gender, hometown, hobbies, photo or invented quote **(script: field labels)** | Any present |
| 15 | Personas come from buying-committee roles or role brainstorming, never from delivery stakeholders | The product owner or a design partner as a persona |
| 16 | `review-by:` set; reopen triggers listed; retired personas kept with date and reason | Silently deleted personas |
| 17 | Canonical glossary terms | "Champion persona", "buyer persona" as a type name |
