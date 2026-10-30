# OKR Health Check — Run Before Hand-Off

Self-contained. Cross-check every OKR set against this list before presenting it to the user. Each row is a hard stop: a set that fails any row goes back with the failing row named. Rows draw on Rumelt (*Good Strategy / Bad Strategy*: proximate objectives, one guiding policy, goals as strategy), Google's OKR guidance as reproduced by Doerr (*Measure What Matters*: committed vs aspirational, business as usual, "who cares?"), Wodtke (*Radical Focus*: one OKR, health metrics, the weekly check-in) and Cagan (*Inspired*: a Key Result is never an output).

## A. The set as a whole

| # | Check | Fails when |
|---|---|---|
| A1 | **Inputs.** `traces_to` names the vision and the strategy kernel. | No kernel exists (goals as strategy), or the set reads the roadmap |
| A2 | **One policy.** Every Objective follows from the kernel's single guiding policy. | Objectives drawn from different functions with no common policy (dog's dinner), even if there are three or fewer |
| A3 | **Size.** lean: one Objective, about three KRs. standard: up to three Objectives. enterprise: 3–5 per level (company, product line; teams may hold fewer). | More Objectives than the profile allows |
| A4 | **North Star.** The vision's North Star is named as the vision states it, with what this cycle moves. | A new or different North Star, or a North Star section with its own baseline and target |
| A5 | **Health metrics.** 1–2 at lean, 2–4 otherwise, each with a current status. Every volume or speed KR has a counter-metric here or a paired KR. | None, or a volume KR with nothing guarding its side effect |
| A6 | **Check-in log and grading table** are present (empty at authoring time). | Missing; the set will be forgotten |

## B. Each Objective

| # | Check | Fails when |
|---|---|---|
| B1 | Qualitative: no numbers | A metric inside the Objective |
| B2 | **Proximate**: reachable this cycle; the team knows what to do next | Blue-sky end state ("become the leader") |
| B3 | Traces to a proximate objective in the kernel's hand-off | Invented, or contradicts something the policy rules out |
| B4 | **Business-as-usual test**: would not happen without the OKR | Describes ongoing work |
| B5 | **"Who cares?" test**: someone outside the team would notice it succeeding | Internal housekeeping |
| B6 | **Type labelled**: committed or aspirational | Unlabelled; or a certification, contract or deadline labelled aspirational |
| B7 | If all its KRs land, the Objective is genuinely accomplished | A committed Objective whose KRs could all land without it (insufficient KRs) |
| B8 | Enterprise: names the higher-level Objective it advances, and the teams it depends on sideways | Free-standing, or no dependency check |

## C. Each Key Result

| # | Check | Fails when |
|---|---|---|
| C1 | **Outcome, not output**: shipping exactly what it names without any change for users would not mark it done | "Launch", "ship", "build", "publish", "features shipped" |
| C2 | Has metric, baseline (measured, `n/a (pre-launch)`, or `not yet measured — first reading by <date>` with a provisional target), target, direction, one owner, starting confidence | Any field missing; a bare placeholder; an invented baseline |
| C3 | Metric is comparative, understandable, a ratio or rate where possible, and would change a decision | Vanity count |
| C4 | **Confidence set by type**: aspirational about 50%, committed ≥ 90% | One "70%" for every KR; confidence written as the expected grade |
| C5 | Enterprise: not a copy of the parent's KR with a smaller number | Cascaded |
| C6 | Has at least one candidate Initiative, so the roadmap has something to sequence | No plausible way to move it (fantasy target) |

## D. At quarter-end (grading)

| # | Check | Fails when |
|---|---|---|
| D1 | Committed KRs graded against 1.0; any miss carries an explanation and a recovery plan with a date | A committed miss called a success at 0.7 |
| D2 | Aspirational KRs read against about 0.7 | A 0.7 aspirational grade treated as failure; or all 1.0 not flagged as timid |
| D3 | Grades come from the numbers (interpolation where a baseline exists), written before the narrative | Grade adjusted to the story |
| D4 | One learning line per Objective; kernel revised first if its review trigger fired | No learning recorded |

## Fast triage order

1. A1 (no kernel, or reads the roadmap).
2. C1 (output KRs).
3. B6 and C4 (type and confidence).
4. A4 (second North Star).
5. A3 and C5 (size; cascade).
6. The rest.
