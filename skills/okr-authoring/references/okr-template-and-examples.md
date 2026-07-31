# OKR Template and Worked Examples

Reference material for `okr-authoring`. Contains the OKR-set artifact template and a full set of worked, outcome-based examples for this repo's first product (Data Estate Mapping and Compliance Intelligence — an event-driven, private-deployment platform for SMBs, whose primary personas are the **Data Steward** and the **Compliance Officer**). Each worked KR is paired with the output-shaped anti-example it replaces, so the outcome-not-output rule is visible in context.

---

## 1. The OKR-set artifact template

Copy this shape into the produced artifact. Frontmatter follows the plugin's Artifact Standards (`name:`, never `artifact:`).

```markdown
---
name: okr-set
product: [product name]
cycle: [Q3 2026 / H2 2026 / Annual 2026]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
north-star-metric: [single metric]
---

# OKRs — [Cycle]

## North Star Metric

[Single metric that best captures the core value delivered to customers]
Baseline: [value] | Target: [value] | By: [date]

---

## Objective 1 — [Qualitative, inspiring, time-bound statement]

*Company Objective supported: [name] (or "unified — solo operator")*
*Roadmap link: [Now / Q3 theme name]*

| Key Result | Metric | Baseline | Target | Direction | Owner | Confidence |
|---|---|---|---|---|---|---|
| KR1.1 | | | | ↑/↓ | | 70% |
| KR1.2 | | | | | | |
| KR1.3 | | | | | | |

**Hypothesis framing (optional, LeMay):** We believe [Initiative] will cause [KR movement], and we'll know we're right when [signal].

**Initiatives (bets on how to move the KRs — may change mid-cycle):**
- [Initiative 1]
- [Initiative 2]

---

## Objective 2 — [Qualitative statement]
[Repeat structure]

## Objective 3 — [Qualitative statement]
[Repeat structure]

---

## OKR Health Check

[All 5 health-check questions answered for each Objective.]

## Grading (completed at quarter-end)

| Objective | KR grades (0.0-1.0) | Objective grade (avg) | What we learned |
|---|---|---|---|
| O1 | | | |
```

Field notes:
- **Confidence** starts near 70% and is updated at each weekly check-in — it is the leading indicator.
- **Direction** (↑ higher-is-better / ↓ lower-is-better) removes any ambiguity when grading.
- The **Grading** block is filled at quarter-end, not at authoring time.

---

## 2. A complete worked OKR set (Q3 2026)

Three Objectives for the first product, illustrating outcome KRs, honest baselines, and calibrated ambition.

### North Star Metric

**Number of design-partner accounts with a maintained, trusted compliance picture** (an account that has classified its estate *and* returned to act on findings in the last 14 days).
Baseline: 0 (pre-launch) | Target: 5 | By: end of Q3 2026.

---

### Objective 1 — Prove that an SMB can go from zero to a trustworthy compliance picture in a single session.

*Company Objective supported: unified — solo operator.*
*Roadmap link: Now — "Frictionless Onboarding".*

| Key Result | Metric | Baseline | Target | Dir | Owner | Conf |
|---|---|---|---|---|---|---|
| KR1.1 | % of trial users who discover their first compliance gap within 30 min of connecting a source | n/a (pre-launch) | 80% | ↑ | Shafi | 70% |
| KR1.2 | Median time from Google Drive connection to full sensitivity classification (estates ≤ 100k files) | n/a | ≤ 30 min | ↓ | Shafi | 60% |
| KR1.3 | Design-partner deployments completed without any support contact | 0 of 3 | 3 of 3 | ↑ | Shafi | 70% |

**Why this passes:** the Objective is qualitative and time-bound; if all three KRs land, "zero to trustworthy compliance picture in one session" is genuinely accomplished; every KR is measurable from telemetry with no self-assessment; and none can be gamed without actually delivering the onboarding outcome — an onboarding wizard users abandon fails KR1.1 regardless of effort spent.

**Output anti-examples this Objective avoids:**

| ❌ Output (rejected) | Why it fails | ✅ Outcome used instead |
|---|---|---|
| "Launch the onboarding wizard" | Ships whether or not anyone finishes it | KR1.1 (users reach first gap in 30 min) |
| "Build the Google Drive connector" | Buildable and ignorable | KR1.2 (median time to classification) |
| "Write onboarding docs" | Effort, not user success | KR1.3 (deploys with zero support contact) |

The rejected outputs are not discarded — they become **Initiatives** under this Objective: *build the onboarding wizard; ship the Google Drive connector; write self-serve docs.* They are the bets; the KRs are the outcomes those bets must produce.

---

### Objective 2 — Earn the Compliance Officer's trust that the platform's findings are worth acting on.

*Roadmap link: Now — "Actionable Findings".*

| Key Result | Metric | Baseline | Target | Dir | Owner | Conf |
|---|---|---|---|---|---|---|
| KR2.1 | % of flagged compliance gaps resolved within 5 business days of surfacing | 40% (design-partner pilot) | 70% | ↑ | Shafi | 65% |
| KR2.2 | % of surfaced findings a Compliance Officer marks "false positive" | 22% | ≤ 8% | ↓ | Shafi | 60% |
| KR2.3 | Weekly active Compliance Officers across design-partner accounts | 40 | 120 | ↑ | Shafi | 70% |

**Why this passes:** trust is intangible, so the Objective stays qualitative; the KRs operationalize trust as *acted-on findings* (KR2.1), *signal quality* (KR2.2), and *sustained use* (KR2.3) — three independent behavior changes that together evidence the Objective. KR2.1's baseline of 40% is measured from the pilot, not guessed, so a 70% target is a real +30-point stretch, not a mystery number.

**Output anti-examples this Objective avoids:**

| ❌ Output (rejected) | Why it fails | ✅ Outcome used instead |
|---|---|---|
| "Ship the remediation-workflow feature" | A feature can ship and go unused | KR2.1 (gaps actually resolved) |
| "Improve the classification model" | "Improve" is unmeasured; model change ≠ trust | KR2.2 (false-positive rate falls) |
| "Add a findings dashboard" | Dashboard existence isn't engagement | KR2.3 (weekly active officers) |

---

### Objective 3 — Make the platform demonstrably safe to run inside an SMB's own environment.

*Roadmap link: Next — "Private-Deployment Assurance".*

| Key Result | Metric | Baseline | Target | Dir | Owner | Conf |
|---|---|---|---|---|---|---|
| KR3.1 | Achieve SOC 2 Type II certification (binary) | not started | achieved | — | Shafi | 70% |
| KR3.2 | % of design partners who complete a security review without a blocking finding | n/a | 100% (3 of 3) | ↑ | Shafi | 55% |
| KR3.3 | Mean time to patch a flagged CVE in the deployment image | n/a | ≤ 3 days | ↓ | Shafi | 65% |

**Why this passes:** the Objective names a state of the world ("demonstrably safe to run"), not a task. KR3.1 is a legitimate **binary** KR — graded 1.0 if achieved, 0.0 if not, no partial credit for effort (see `references/okr-rules-and-grading.md` §4). KR3.2 and KR3.3 are continuous, keeping the Objective's grade informative rather than all-or-nothing.

---

## 3. Grading the set at quarter-end (illustrative)

Suppose at end of Q3 the values landed as: KR1.1 = 72% (target 80%, baseline 0) → 0.90; KR1.2 = 34 min (target 30, from a first-run start) → ~0.7; KR1.3 = 2 of 3 → 0.67.

| Objective | KR grades | Objective grade (avg) | Learned |
|---|---|---|---|
| O1 | 0.90 / 0.70 / 0.67 | **0.76** | Onboarding lands; classification time is the drag — an Initiative for next quarter. |

An average of **0.76** on O1 is a **healthy, well-calibrated result**, not a shortfall — it sits right in the 0.7-1.0 green band and signals the ambition was set correctly. Had every KR come in at 1.0, the read would be the opposite: the targets were sandbagged and should be raised next cycle.

---

## 4. Traceability downstream

Each Key Result above becomes an anchor the Ideate phase traces back to:

- **`impact-mapping`** starts from a KR as its measurable goal (the WHY), then maps actors → impacts (behavior changes) → deliverables — never letting a deliverable become the goal.
- **`story-mapping`** organizes the backbone of user activities toward the same outcomes, so the walking skeleton delivers against a KR rather than a feature wish-list.

Because every KR here is an *outcome*, this trace stays honest: downstream work is measured by whether it moved the KR, not by whether the named feature shipped. A KR written as an output would break the chain — Ideate would inherit a solution to build instead of a problem to solve, which is exactly the feature-team failure Cagan warns against.
