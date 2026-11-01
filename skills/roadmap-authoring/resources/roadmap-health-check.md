# Roadmap Health Check

Self-contained. Run every check before handing the roadmap off for approval. **Every row is a hard stop**: fix the roadmap, then re-run. Sources are named so a reviewer can follow the reasoning: Lombardo et al. (*Product Roadmaps Relaunched*), Rumelt (*Good Strategy / Bad Strategy*), Doerr (*Measure What Matters*), Cagan (*Inspired*).

## Order and inputs

| # | Check | Fails when |
|---|---|---|
| 1 | The OKR set exists and is the roadmap's input (with the vision and the strategy kernel) | The roadmap was written first, or sets its own goals or targets |
| 2 | Every KR in the OKR set is served by at least one theme, or is flagged back to `okr-authoring` in the revision history | A KR silently has no theme |
| 3 | The North Star appears only in the vision line, as the vision states it | A new North Star or a "roadmap goal" section |

## Primary components (Lombardo)

| # | Check | Fails when |
|---|---|---|
| 4 | Vision line present | Missing, or a rewritten vision |
| 5 | Objectives block lists the Objectives and KRs served | Missing |
| 6 | Broad timeframes; no date past Now except a committed-OKR date marked "committed" | Quarters or dates 18 months out; a dated feature in Next or Later |
| 7 | Rows are themes | Any row is a feature, a capability category or a quality target |
| 8 | Disclaimer is its own section | Missing, or a footnote |

## Rows

| # | Check | Fails when |
|---|---|---|
| 9 | Each theme is a customer problem more than one solution could satisfy | Only one feature could satisfy it |
| 10 | Each theme names the KR it serves, or "Guiding policy: [clause]" | "Strategic — …", "expands TAM", or blank |
| 11 | Candidate solutions only in Now, written as bets drawn from the OKR set's Initiatives | Solutions in Next or Later, or written as commitments |
| 12 | Confidence on every row, decaying with horizon (High / Medium / Low; plugin convention > 80% / 50–80% / < 50%) | Missing, or uniform across horizons |
| 13 | Stage on every row (standard and enterprise) | Missing at standard+ |
| 14 | Dependencies named where they exist | A theme that needs another team or decision says nothing |

## Strategy (Rumelt)

| # | Check | Fails when |
|---|---|---|
| 15 | Now themes reinforce each other or the guiding policy, and say which | A traceable but unrelated pile |
| 16 | If a weakest link exists, its theme is first in Now | It sits behind "higher value" themes |
| 17 | Nothing on the roadmap is something the guiding policy rules out | A theme the kernel's rules-out list names |
| 18 | Every "Not On This Roadmap" entry cites a guiding-policy clause or the diagnosis | Any entry has no reason, or a reason tied to nothing |

## Process

| # | Check | Fails when |
|---|---|---|
| 19 | "How this was prioritised" names the framework (critical path at lean; scored scorecard at standard+) | No method, or "by value" |
| 20 | Review pre-wired: objections listed (lean) or the consultation table filled (standard+) | Absent |
| 21 | Revision history table present, with the named triggers | Absent |
| 22 | Size matches the profile (lean: one page, 2–5 themes; enterprise: product-area swimlanes) | Lean over a page; enterprise with no swimlanes |
| 23 | Frontmatter has name, version, phase, owner, created, summary, profile | Any missing |
