---
name: pact-impact-[YYYY-MM-DD]
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: product, date, how many service and environment checks are verified and how many need attention]
traces-to: [implement/test-strategy.md]
---

# Pact Impact Report: [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/pact-impact-[YYYY-MM-DD].md. The product owner approves it.
     ../scripts/write-pact-impact-report.sh writes this file from the broker's answers; fill it by hand only
     when the script could not run, and say so. Never fill it from the test run's exit status: a failing
     pending pact leaves the provider's run green. -->

What yesterday's code changes mean for the calls between services that are already in use. Built from the Pact Broker's answers. Pact does not block a pull request, so a break listed here may already be merged; it cannot be deployed, because a deployment asks the broker first.

## Result

**[Every check is verified. / N check(s) need attention.]**

| Service | Environment | Result | What the broker said |
|---|---|---|---|
| [service] | [environment] | [verified / BROKEN / NOT VERIFIED / NO RESULT] | [the broker's reason, copied] |

## Flows checked

| Environment | Calling service | Called service | Verification |
|---|---|---|---|
| [environment] | [consumer and commit] | [provider and commit] | [passed / FAILED / not verified] |

## What each result means

- **verified**: this commit works with every caller and called service now in that environment.
- **BROKEN**: a caller's recorded expectation fails against this commit. It must not be deployed.
- **NOT VERIFIED**: no verification is recorded for this pair, for example a new expectation the other side has not met yet, or nothing deployed there yet.
- **NO RESULT**: the question could not be asked. Treated as a failure.

## Action for each item needing attention

- [service] in [environment] ([result]): [owner and fix, or the reason no fix is needed]

## Approval

Product owner: [name], [date], [approved / comments]
