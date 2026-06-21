# Skill: core/value-stream-map

## Purpose
Produce the Value Stream Map — a visualisation of all steps required to deliver value from idea to production. Identifies waste, delays, handoffs, and bottlenecks in the development and delivery process. Used to improve flow and measure lead time improvement over time.

## Inputs
- `sdlc-manifest.json` → phase completion times (to calculate actual cycle times)
- `sdlc-config.json` → product name, team context
- `artifacts/strategy/okrs.md` → delivery OKRs
- `artifacts/deploy/ci/` → CI pipeline definitions (to understand automation coverage)

## Output
**File:** `artifacts/core/value-stream.md`
**Registers in manifest:** yes

## Value Stream Concepts
- **Lead time**: Total time from idea (story created) to production deployment
- **Process time**: Time actually working on the step (not waiting)
- **Wait time**: Time between steps (handoffs, queues, approvals)
- **Efficiency %**: Process time / Lead time × 100 — a high % means less waste
- **Waste types**: Waiting, overproduction, defects, over-processing, transport (handoffs)

## Artifact Template

```markdown
# Value Stream Map
**Product:** {product_name}
**Phase:** Core
**Artifact:** Value Stream Map
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Current State Value Stream

### Steps and Timing

| Step | Actor | Process time | Wait time | Automation | Notes |
|------|-------|-------------|----------|-----------|-------|
| Problem statement → Story | PM | 2h | 24h | Manual | Story creation in backlog |
| Story → READY (refinement) | PM + Dev | 1h | 48h | /sdlc-story (partial) | Backlog-refiner, TDD spec, BDD feature |
| READY → Implementation | Dev | {Xh} | {Xh} | Manual | Coding phase |
| Implementation → PR review | Dev | 30m | 4h | Automated CI gates | PR creation |
| PR → Merged | Tech lead | 30m | 2h | CI must pass | Review and merge |
| Merged → Staging | CI/CD | 5m | 0 | GitHub Actions + ArgoCD | Automated |
| Staging → Production | Platform | 10m | 24h | Manual approval gate | Continuous Delivery (human gate for prod) |

**Total lead time (target):** {N} days
**Total process time (target):** {N} hours
**Efficiency:** {process_time / lead_time × 100}%

---

## Waste Identified

| Waste type | Location | Impact | Elimination approach |
|-----------|---------|-------|---------------------|
| Waiting | Story → READY (48h) | MEDIUM | /sdlc-story automates TDD/BDD generation; reduces wait to same day |
| Waiting | PR → Merged (4h) | LOW | Async review; pair programming for complex PRs |
| Waiting | Staging → Production (24h) | MEDIUM | Short-lived: production approval is intentional; accept this waste |
| Defects | Re-work after integration failures | HIGH | TDD + integration tests in CI; catch defects before merge |

---

## Improvement Targets

| Metric | Current (estimated) | Target (6 months) |
|--------|-------------------|------------------|
| Lead time: Story → Production | {N} days | {N} days |
| Change failure rate | {N}% | < 5% |
| Mean time to recover (MTTR) | {N} hours | < 1 hour |
| Deployment frequency | Weekly | Daily |

These targets align with DORA (DevOps Research and Assessment) Elite performer metrics.

---

## Factory Contribution to Value Stream

The SDLC Artifact Factory reduces waste by:
- **Eliminating handoff delays**: `/sdlc-story` generates TDD spec and BDD feature in one command
- **Reducing defect waste**: Pre-implement hooks enforce TDD existence before code generation
- **Automating compliance**: Compliance tests in CI eliminate manual compliance review before release
- **Standardising onboarding**: Coding standards and repo structure artifacts reduce new developer wait time
```

## Quality Checks
- [ ] Lead time and process time are specified per step
- [ ] Efficiency percentage is calculated
- [ ] Waste is classified by type (waiting, defects, etc.)
- [ ] DORA metrics are referenced as improvement targets
- [ ] Factory contribution section explains how this plugin reduces waste
