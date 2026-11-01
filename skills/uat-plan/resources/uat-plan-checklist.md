# UAT Plan Checklist

Self-contained. Cross-check a UAT plan against every row before handing it off; `../scripts/check-uat-plan.py` checks the mechanical rows (marked ⚙). A row that fails is fixed in the plan, not explained away in the reply.

## Acceptance types
| # | Check | Pass | Fail |
|---|---|---|---|
| T1 ⚙ | All five types considered | A row each for UAT, OAT, contractual, regulatory, alpha / beta, with "yes" or "no, because …" | Only UAT; a type silently missing |
| T2 | OAT matches the product | Hosted, or holds user data → OAT in scope (lean: three-line smoke) with a platform-engineer evidence source | A hosted product with no restore, rollback or alerting check |
| T3 | Regulatory from the product's scope | Requirements come from `compliance-design`; a named compliance signatory | A framework written in because "products like this usually need it" |
| T4 | Contractual only with a contract | The clause is quoted and traced to a Must and a scenario | A sales promise treated as a contract; a clause with no Must |
| T5 | Alpha / beta handed off | Points to `beta-program-design`; no stage design in the plan | Beta stages, cohorts or graduation designed here |

## Scope and test basis
| # | Check | Pass | Fail |
|---|---|---|---|
| S1 | Scope = the Musts | Every Must (walking skeleton; at lean the Must block) has a row | A Must with no row; a Should, Could or Won't in scope |
| S2 ⚙ | Every row has scenarios | At least one UAT ID per Must story, same root (US-5 → UAT-5a, UAT-5b) | A blank scenario cell; unrelated IDs |
| S3 | Test basis named | Each row cites its acceptance criteria and feature file | Scenarios invented from the UI |
| S4 | Business scenarios | Scenarios are real pieces of work across functions | One scenario per screen |
| S5 | Risk-weighted | Extra scenarios or charters where failure hurts most | Even coverage regardless of risk |

## Roles and independence
| # | Check | Pass | Fail |
|---|---|---|---|
| R1 ⚙ | Independence level stated | An ISTQB level, per type at enterprise | No level |
| R2 ⚙ | Solo exception recorded | Level "none" (or executor = accepting authority) → an `Exception: solo operator` section with reason, freeze date, evidence, borrowed session | Same person executes and accepts with no recorded exception |
| R3 | Exception not capped | The plan does not limit a solo plan to a conditional sign-off | "Solo, so conditional at best" |
| R4 | The agent is not a party | No agent named as executor, explorer or independent check | "The agent runs UAT" |

## Environment and criteria
| # | Check | Pass | Fail |
|---|---|---|---|
| E1 | Where it ships | Canary tenant or staging (standard, enterprise); production behind a flag or the one staging (lean); digest and flags recorded | Local dev; nothing recorded |
| E2 ⚙ | Yardstick agreed first | An entry item: criteria, threshold and defect bar agreed by the accepting authority before execution | Threshold decided after results |
| E3 ⚙ | Four result states | Exit criteria name Pass, Fail, Blocked and Not run; Blocked and Not run fail until run | Pass / fail only |
| E4 | Threshold reasoned | 100% of Must scenarios by default; any lower one agreed and signed before execution, with a reason | A lower threshold with no reason or date; a threshold lowered after the results |
| E5 ⚙ | One defect rule | Exit criteria point to `acceptance-sign-off`'s defect rule; no defect bar of the plan's own | "Zero open Critical / High" restated |
| E6 ⚙ | Residual risk | An exit item and a Completion Summary line for residual risk | Missing |

## Schedule and exploration
| # | Check | Pass | Fail |
|---|---|---|---|
| X1 ⚙ | Re-test time | The schedule has a re-test and regression step before the decision | Fixes counted as closed when deployed |
| X2 | Fixed decision date | Execution may stretch; compile-and-decide does not | Open-ended window |
| X3 ⚙ | At least one charter | In the "Explore … with … to discover …" form | No charter, or a charter that lists steps |
| X4 | Charter coverage | Across the charters, Structure, Function, Data, Interfaces, Platform, Operations and Time are each touched, or a gap is stated | Only the happy-path UI explored |
| X5 | Human explorer | Every charter names a human explorer | An agent "exploring" |
| X6 | Repeatability (several executors) | The plan notes whether each executor was set up the same documented way | Not asked |

## Artifact
| # | Check | Pass | Fail |
|---|---|---|---|
| A1 ⚙ | Frontmatter | name, version, phase (customer-validation), owner, created, summary, profile | Missing field; wrong phase |
| A2 | Product rules stay in the product | Personas, frameworks and tenants appear only as this product's facts | Generic rules phrased around one product |
| A3 | Glossary terms | Canonical terms from `glossary-management` | Synonyms ("UAT sign-off test", "ops test") |
