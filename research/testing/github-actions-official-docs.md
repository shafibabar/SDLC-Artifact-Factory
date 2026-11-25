# GitHub Actions Triggers and Required Status Checks: Official Documentation
**Authors:** GitHub (docs.github.com)
**Domain:** Testing and delivery (CI gates)

Accessed 2026-11-25. GitHub Docs for the hosted service carry no product version; GitHub Enterprise Server may differ [unverified].

Sources:
- [T] https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks
- [E] https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- [S] https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- [J] https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions
- [P] https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- [C] https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks

## Core Concepts

- **Skipped workflow:** when path, branch or commit-message filtering skips a workflow, its required checks stay Pending and block the merge [T] [S].
- **Skipped job:** a job skipped by `if` reports Success and does not block, even if required [J]. A job whose dependency failed may be skipped without blocking; required dependent jobs should use `always()` with `needs` [T].
- Required checks pass as `success`, `skipped` or `neutral`, on the latest commit SHA [T] [P]. A check and a commit status sharing a required name must both pass [T]. Keep job names unique across workflows [P].
- **Strict** mode requires the branch to be up to date; loose does not. An expected source app can be pinned [P].
- **Merge queue:** a workflow providing a required check also needs the `merge_group` trigger (type `checks_requested`) [T] [E].
- **Path filters** apply to `push`, `pull_request`, `pull_request_target`, not tag pushes; `paths` and `paths-ignore` cannot both be used on one event; `!` negations need a positive pattern and order matters; branch and path filters must both match [S]. Pull requests use a three-dot diff. Over 1,000 commits or a diff timeout always runs; beyond 3,000 changed files a match outside the first 3,000 does not trigger [S].
- **`schedule`:** five-field POSIX cron, UTC unless an IANA `timezone` is set; minimum interval 5 minutes; runs only on the latest commit of the default branch; can be delayed, and queued runs dropped under load (avoid the top of the hour); disabled in public repositories after 60 days without activity; no `@daily` shorthand; actor and notifications follow whoever last changed the cron or default branch [E].
- **`pull_request`:** defaults to `opened`, `synchronize`, `reopened`; does not run while the PR has a merge conflict. `pull_request_target` runs in the base context and is dangerous with untrusted head code [E].
- **`workflow_dispatch`:** the file must be on the default branch for the button; up to 25 inputs [E].
- **`release`:** all activity types trigger by default; draft releases do not trigger `created`, `edited`, `deleted`; `prereleased` does not fire for a prerelease published from a draft, `published` does [E].

## Actionable Techniques

- For a required check, trigger the workflow on every pull request, then skip work with job-level `if` (computed by a change-detection step or job) [T] [J]. The change-detection design is this note's inference.
- Add a final always-running gate job that inspects `needs.*.result` and fails on failure, and require only that job [T] for `always()`; result inspection is inference.
- Treat nightly and weekly suites as non-gating and best-effort; alert on absence [E] (alerting is inference).
- Add `merge_group` wherever a merge queue is used [T].

## Applies To

| Skill/Agent | Gap (from Wave 3 audit) | What the docs add |
|---|---|---|
| go-performance-test | W3B-17 | Pending versus skipped |
| go-load-test, e2e, mutation skills | triggers, nightly, release | Schedule and release semantics |
| ci-pipeline, cd-pipeline | gate design | Required-check rules |

## Candidate New Skills/Agents

None.

## Key Terminology

Required Status Check, Check Conclusion, Merge Queue, Path Filter, Activity Type [T] [E] [S].

## Caveats

- [S] is long; only its first 100,000 characters (including the path filter rules) were read.
- [unverified] Any time window within which a check must have run to be selectable or valid (not on [P] or [C]).
- [unverified] Rulesets behaving identically to branch protection; concurrency settings were not researched.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-17: does a required check with a path filter stay pending? | Yes, blocks merge [T] [S] | Confirmed |
| Same for branch or commit-message filters | Yes [T] | Confirmed |
| W3B-17 proposal: run always, skip inside the job | Job-level skip reports success [J] | Confirmed |
| Batch B narrative 3: `release: types: [published]` runs after the release is out | `published` is a trigger type [E]; the page does not define it, so the timing is not stated | Unverified |
| Nightly placement (e2e, mutation, chaos): is schedule reliable and branch-independent? | Neither: default branch only, delayable, droppable [E] | Confirmed |
