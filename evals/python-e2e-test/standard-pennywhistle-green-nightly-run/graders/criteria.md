---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the nightly run is selecting no tests, because no test carries the marker the job selects, and that a run which collects nothing must fail rather than pass, so pytest's exit code 5 is treated as a failure (W3-D10; `research/testing/pytest-e2e-mechanics-official-docs.md`, exit codes). How the mismatch is prevented in future, for example strict marker registration, is not required.
2. It limits a failed end-to-end test to at most one retry, in place of three (W3-D11). It does not matter whether a plugin or the runner performs the retry.
3. It says a test that passes only on its retry is reported as flaky and not as green, and that the exit status alone does not show this, because pytest exits 0 for such a run (W3-D11; `research/testing/pytest-e2e-mechanics-official-docs.md`, rerun behaviour). Any way of surfacing the flaky result is acceptable, for example a setting that fails the run or a record read from the report.
4. It says each quarantined test is named in a list file together with an issue and a deadline, and that a quarantined test never counts as passed (W3-D11 and the end-to-end decision of 2026-11-28). The file's name and format do not matter.
5. It replaces `time.sleep(10)` with polling for the reminder until a deadline, failing when the deadline passes (`research/testing/httpx-guards-and-polling-official-docs.md`, polling). A shorter or longer fixed sleep does not satisfy this.
Fail if any of the 5 is missing.
