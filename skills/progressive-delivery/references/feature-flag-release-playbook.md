# Feature-Flag Release Playbook — Progressive Delivery

Self-contained reference. Covers the step-by-step release procedure using feature flags as the release
mechanism when the code is already deployed to 100% of production instances. Works alongside
`feature-flag-design` (flag definition, targeting rules, OpenFeature/flags.json) and
`progressive-delivery/SKILL.md` (strategy selection criteria).

---

## Preconditions

A feature-flag-only release is only valid when ALL of the following are true:

| Precondition | How to verify |
|---|---|
| Code is deployed to 100% of production instances | `kubectl get pods -n <namespace> -l app=<service>` — all pods are `Running` on the new image tag |
| Flag exists in `flags.json` with targeting set to `0%` or `false` | `cat flags.json | jq '.flags["<flag_name>"]'` — returns the flag definition |
| Flag has been tested in staging with targeting at 100% | Staging smoke tests pass with flag enabled globally |
| Flag has a hard removal date set in the flag definition | The `expires` field in the flag definition is populated (see `feature-flag-design` for the removal-date rule) |
| Monitoring dashboards are set up for the flagged behavior | Grafana dashboard exists for the metric that tracks the new behavior's outcome |

If any precondition fails, do not proceed with a feature-flag-only release. If the code is not yet deployed, deploy first (using canary), then return to this playbook.

---

## Flag Definition Template

Before the release, confirm the flag is correctly defined in `flags.json` (OpenFeature format):

```json
{
  "flags": {
    "upload_drag_drop_enabled": {
      "state": "ENABLED",
      "defaultVariant": "off",
      "variants": {
        "on": true,
        "off": false
      },
      "targeting": {
        "rules": [
          {
            "if": [
              {
                "in": [
                  { "var": "userId" },
                  []
                ]
              },
              "on",
              {
                "fractionalEvaluation": [
                  "upload_drag_drop_enabled",
                  ["on", 0],
                  ["off", 100]
                ]
              }
            ]
          }
        ]
      },
      "expires": "2026-10-31",
      "owner": "platform-engineer",
      "jira": "PLAT-1024"
    }
  }
}
```

The `fractionalEvaluation` percentage (`["on", 0]` = 0% enabled) is what gets changed during the release procedure.

---

## Release Procedure

### Phase 0: Pre-Release Verification (do not skip)

```bash
# 1. Confirm all pods are running the correct image tag
kubectl get pods -n <namespace> -l app=<service> \
  -o jsonpath='{.items[*].spec.containers[0].image}'
# All pods must return the same image:tag

# 2. Confirm the flag is currently at 0% in production
curl -s https://flagd.internal/flags/<flag_name>/evaluate \
  -H 'X-User-Id: test-user-001' | jq '.value'
# Expected: false (flag is off for all users)

# 3. Confirm staging completed with flag at 100%
# (Review staging smoke test results from the CI run that shipped this image)
```

### Phase 1: Initial Exposure — 5%

```bash
# Edit flags.json: change the fractionalEvaluation "on" percentage from 0 to 5
# flags.json diff:
#   - ["on", 0],
#   + ["on", 5],
#     ["off", 95]

git add flags/flags.json
git commit -m "release: enable <flag_name> for 5% of users"
git push origin main
# GitOps reconciles the updated ConfigMap within the Flux reconciliation interval (typically 1m)
```

**Hold period: 24 hours**

During the hold, monitor:
- Error rate for the flagged code path: `<service>_<feature>_errors_total` counter (from OTel instrumentation)
- The key outcome metric for the new behavior (e.g., `upload_drag_drop_completion_rate`)
- Overall service error budget burn (SLO burn-rate dashboard)

**Gate criteria to advance from 5% to 25%:**
- No increase in `<service>_<feature>_errors_total` rate vs. the baseline (users with flag off)
- Outcome metric shows expected behavior (flag-on users have higher completion rate OR equivalent; no degradation)
- SLO burn-rate does not change across the hold period

### Phase 2: Widening — 25%

```bash
# flags.json diff:
#   - ["on", 5],
#   + ["on", 25],
#     ["off", 75]
git commit -m "release: widen <flag_name> to 25% of users"
```

**Hold period: 48 hours**

### Phase 3: Majority — 50%

```bash
# flags.json diff:
#   - ["on", 25],
#   + ["on", 50],
#     ["off", 50]
git commit -m "release: widen <flag_name> to 50% of users"
```

**Hold period: 48 hours**

At 50%, the A/B split is statistically symmetric — this is the best point to run any formal analysis of the outcome metric across both cohorts (flag-on vs. flag-off users) before proceeding to 100%.

### Phase 4: Full Release — 100%

```bash
# flags.json diff:
#   - ["on", 50],
#   + ["on", 100],
#     ["off", 0]
git commit -m "release: <flag_name> enabled for all users (100%)"
```

**Bake period: 72 hours at 100%**

At 100%, all users are on the new behavior. The 72-hour bake period is the window during which rollback is still the preferred response to any issue. After the bake period, the code and flag are stable; proceed to Phase 5.

### Phase 5: Flag Removal (Required — Not Optional)

Feature flags have a hard removal date. After the bake period, the flag is no longer a release mechanism — it is dead code with a maintenance cost. Remove it.

```bash
# 1. Remove the targeting rules and variants from flags.json
#    The behavior is now unconditional — the code runs for all users without a flag check.
#
# 2. Remove the flag evaluation call from the application code
#    (Backend: delete the OpenFeature evaluation call; always execute the new path)
#
# 3. Remove the flag from flags.json entirely
#
# 4. Deploy the code change that removes the flag evaluation via canary (normal release)
```

Flag removal is a code change and goes through the normal canary release. Removing the flag check from code before removing it from `flags.json` is safe — the flag evaluation returns `defaultVariant: off` if the flag is absent, which would break the feature. Always remove in this order:
1. Set targeting to 100% (done in Phase 4)
2. Deploy code with flag check removed (via canary)
3. Remove flag from `flags.json`

---

## Rollback Procedure

Feature-flag-only rollback is the fastest rollback on this platform — no redeploy, no image swap, no traffic weight change.

**Rollback trigger**: Any of the following during the hold period:
- `<service>_<feature>_errors_total` rate increases beyond 1.5x baseline
- Outcome metric degrades (flag-on users have worse outcomes than flag-off users)
- SLO fast-burn threshold breached: `service:http_request_errors:ratio_rate5m > 0.072`
- Any user-visible production incident correlated with the flagged behavior

**Rollback steps:**

```bash
# Immediate: set flag targeting to 0%
# flags.json diff:
#   - ["on", 50],   (whatever the current percentage is)
#   + ["on", 0],
#     ["off", 100]
git commit -m "rollback: disable <flag_name> for all users — incident <ID>"
git push origin main
# Flag change propagates within 1 minute (Flux reconciliation)
```

After rollback:
1. Open a post-mortem for any incident that triggered rollback
2. Do not re-enable the flag until the root cause is identified and the code is fixed
3. The fix goes through the standard canary release of the code before returning to Phase 1

---

## Targeting Rules Beyond Percentage

Percentage rollout is the most common targeting rule, but OpenFeature supports more precise targeting:

| Targeting type | Use when | `flags.json` excerpt |
|---|---|---|
| **User allowlist** | Internal users or beta testers first | `"in": [{"var": "userId"}, ["user-001", "user-002"]]` |
| **Tenant allowlist** | Release to one tenant before others | `"in": [{"var": "tenantId"}, ["tenant-canary"]]` |
| **Percentage rollout** | Gradual widening to anonymous users | `fractionalEvaluation` with percentage |
| **Attribute-based** | Users with specific plan tier or region | `"==": [{"var": "planTier"}, "enterprise"]` |

Combining tenant allowlist with percentage rollout is the feature-flag equivalent of the per-tenant canary wave (`cd-pipeline`): enable for `tenant-canary` first at 100%, observe, then widen to `tenant-acme` at percentage.

```json
{
  "if": [
    {
      "in": [{"var": "tenantId"}, ["tenant-canary"]]
    },
    "on",
    {
      "fractionalEvaluation": [
        "upload_drag_drop_enabled",
        ["on", 0],
        ["off", 100]
      ]
    }
  ]
}
```

This targeting rule: `tenant-canary` always gets `on`; all other tenants get `off` (until percentage changes). Change the `["on", 0]` to `["on", 5]` to begin the percentage rollout for non-canary tenants.

---

## Monitoring Checklist for Flag-Gated Releases

Set up these dashboards and alerts **before** Phase 1 begins:

| Signal | Prometheus/OTel query | Alert threshold |
|---|---|---|
| Feature error rate (flag-on users) | `rate(<service>_<feature>_errors_total{flag="on"}[5m])` | > 1.5x rate for flag-off users |
| Feature completion rate | `rate(<service>_<feature>_completions_total{flag="on"}[5m])` | < 0.9x rate for flag-off users |
| SLO burn rate | `service:http_request_errors:ratio_rate5m{service="<service>"}` | > 0.072 (fast-burn threshold) |
| Flag evaluation errors | `rate(openfeature_evaluation_errors_total[5m])` | > 0 (flag SDK should never error) |

These are created as `alerting-rules-design` alerting rules with `severity: page` for the error-rate alerts and `severity: warning` for the completion-rate signal. They use the same recording rules as the canary gate in `argo-rollouts-cookbook.md` — the monitoring infrastructure is shared.

---

## Common Mistakes

| Mistake | Consequence | Prevention |
|---|---|---|
| Enabling flag before code is deployed | Flag returns `on`, code path throws 404/500 | Verify pod image tag before Phase 1 |
| Skipping Phase 5 (flag removal) | Dead code accumulates; next flag for same feature path causes confusion | Set `expires` date in flag definition at flag creation; calendar reminder |
| Advancing phases on a schedule, not on signal | Moving to 25% after 24h regardless of error rate buries incidents | Gate advancement on metric check, not clock |
| No rollback test before Phase 1 | First rollback is during an incident | Perform a flag-off → flag-on cycle in staging before production Phase 1 |
| Using flags for non-behavioral changes | A flag that controls a data migration is a deployment mechanism, not a release mechanism — it is not idempotent | Flags control behavior visible to users, not infrastructure state |
