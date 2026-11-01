# UAT Scenario Checklist

Self-contained. Cross-check every scenario file against this before handing off. Rows marked ⚙ are checked by `../scripts/check-uat-scenarios.py`; the rest need a reader.

| # | Check | Pass | Fail |
|---|---|---|---|
| F1 ⚙ | Frontmatter | `name`, `version`, `phase: customer-validation`, `owner`, `created`, `summary`, `story`, `traces-to` | Missing fields; `artifact:` instead of `name:` |
| I1 ⚙ | ID convention | Every heading is `UAT-<n><letter>` and `<n>` is the story's number | `UAT-005` for US-5; a scenario with no letter; another story's number |
| I2 ⚙ | Traced | Every scenario has a `Traces to:` line naming at least one `AC-US-<n>` criterion | No trace, or a trace to another story |
| T1 | Rule unchanged | The outcome lines mean exactly what the criterion says | A check dropped, softened or added |
| T2 ⚙ | Plain-language steps | No HTTP verbs, field assignments, SQL or code in Steps or Expected Outcome | `PATCH`, `status=…`, `SELECT`, backticked field names |
| T3 | Observable outcome | Every outcome line is something the tester can see | An internal value, an event, a log line |
| T4 | Business scenario | The scenario is a piece of work the role really does | A copied system-test script; one screen with no purpose |
| D1 ⚙ | Named test data | A Preconditions section with at least one item and a "confirm by" | "A user", "an invoice", no way to confirm |
| D2 ⚙ | Environment recorded | An `Environment:` line | No environment |
| D3 | Isolation proved | A multi-tenant isolation scenario seeds look-alike data in two tenants | One tenant only, so a leak would not show |
| R1 ⚙ | Four results only | Each run's result is Pass, Fail, Blocked (with a reason) or Not run | "Passed with issues", "N/A", Blocked with no reason |
| R2 ⚙ | Fail has a defect | Every Fail run names a feedback ID and a workaround (or "none") | A bare Fail |
| R3 | Re-test linked | A re-run after a fix says `Re-test of` the failed run | A Fail silently replaced by a Pass |
| R4 | Stray findings separate | Findings outside the Context are their own feedback items, listed in the last column | A different bug recorded as this scenario's Fail |
| R5 ⚙ | No defect bar | The file does not say what open Highs or Criticals allow | A restated sign-off rule |
| C1 | Coverage | Every acceptance criterion of the story is in at least one scenario's `Traces to:` | A criterion nobody runs |
