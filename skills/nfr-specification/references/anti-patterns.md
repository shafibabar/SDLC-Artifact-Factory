# NFR Anti-Patterns and Their Fixes

Self-contained reference for the `nfr-specification` skill. Read it when reviewing an NFR specification, or when a draft target feels arbitrary.

---

### 1. Wish NFR

"The system should be fast / secure / highly available." No falsifying condition, so it is "met" in every demo and produces no test and no design decision.

**Fix:** write it as a quality-attribute scenario with a response measure. If no number can be agreed, it goes on the open-questions list, not into the scenarios.

### 2. Target without environment

"P95 < 200 ms" at what concurrency, on what data, in which environment? Without load context it passes with one user and an empty database and fails in production. In the scenario format the environment is one of the six parts, so its absence is visible.

**Fix:** "Source: 200 parents. Stimulus: open next week's lessons. Environment: Sunday 18:00–20:00 peak, production-sized data, staging. Response measure: P95 ≤ 1.5 s (Must), ≤ 800 ms (Plan). Verification: load test on each release candidate."

### 3. Average as target

A 200 ms average can hide a P99 of 8 s; the users who wait 8 s are invisible in the mean.

**Fix:** percentiles for latency (P50 and P95 at least; P99 where the tail matters). Averages only for throughput.

### 4. Copy-paste nines

"99.99%" because serious products claim it. Each extra nine multiplies architecture and operations cost (99.9% ≈ 8.8 h a year; 99.99% ≈ 53 min; 99.999% ≈ 5 min).

**Fix:** back-calculate from the business driver (a contract, a regulator, a KR, a buyer's table stakes). Rate the scenario's business value: an expensive target rated M or L is caught by its own rating. State the window that matters (office hours, term time).

### 5. Compliance hand-waving

"Must be SOC 2 compliant." SOC 2 is an audit report on an organisation's controls, not a property of a system.

**Fix:** the control or regulation is a business rule in the FRD (BR-n, its source named). Here, write one obligation row per control that touches this system: what the system must do or prove, measurably, and the automated or manual check that verifies it, citing BR-n.

### 6. Restated rule (two homes)

Data residency written in the FRD as BR-5 *and* here as a new rule. The two drift; one gets updated.

**Fix:** cite BR-n. Hold only the measurable obligation ("every store and backup holding applicant data is in a UK region; checked by an IaC policy test on every plan") and its verification.

### 7. DORA as an NFR

"Deployment frequency: on demand; lead time < 1 hour; change failure rate < 15%", mandatory for every service at every scale. These are rates of a team's delivery process measured across many changes (Forsgren, Humble and Kim, *Accelerate*), and the book's own caution is that its clusters are directional, not hard thresholds. Copying the high-performer cluster onto a two-person internal tool sets a target nobody chose.

**Fix:** write a **deployability** scenario (one service deploys and rolls back alone, with no manual step, within a stated time). Put the rates, if the user wants them, under **Process Targets**, values chosen by the user and calibrated against `dora-metrics`' clusters, which are kept there and nowhere else. Test coverage and CI duration go there too.

### 8. Every characteristic in full

Ten characteristics, all specified in full, for a lean product. The important few disappear among the rest.

**Fix:** walk them all, keep few. Decline the rest in one line with a reason. At lean, 3–8 scenarios.

### 9. Conflict left implicit

Availability with cross-region failover and "data never leaves the country" both specified, neither mentioning the other. The architect finds the clash mid-design.

**Fix:** the conflict check; record a candidate trade-off point naming both scenarios and the options open, for `enterprise-architect` or the user to decide.

### 10. Tactic chosen in the NFR

"Use a service mesh with mutual TLS"; "add a Redis cache". These are design decisions. They may be right, but they belong in an ADR, where alternatives are weighed.

**Fix:** stop at the response measure ("every call between services is encrypted in transit and authenticated; a test shows a plain-text call is refused"). List tactic families in the handoff as pointers only.

### 11. Orphaned NFR

An NFR ID that no Quality-phase test or measurement references was never verified.

**Fix:** every scenario names its verification. At Quality kickoff, check each NFR ID appears in the test plan; one without a test is either missing a test (a defect) or was never a requirement (remove it).

### 12. Product rule as skill rule

A SOC 2 control, a UK region or a 15-year retention period written into the NFR guidance as if every product had it.

**Fix:** product-specific obligations live in that product's BR-n and NFR-OBL rows. The skill's rules stay product-neutral.
