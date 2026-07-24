# Burn-Rate Derivation and the Four Golden Signals

## The Derivation Arithmetic

*Stub — to be filled by sub-issue #205. Brief: shows the worked formula `budget-consumption target × (SLO window / alert window) = burn-rate multiplier`, deriving the fast-burn row's 14.4 from first principles (0.02 × 672 ≈ 13.44, rounding to the SRE Workbook's published 14.4), so the 14.4/6/1 table in `SKILL.md` stops reading as a received constant and becomes recomputable if the SLO window ever changes from 28 days.*

## Two-Source Citation

*Stub — to be filled by sub-issue #205. Brief: states precisely that the error-budget/burn-rate concept comes from Google's 2016 SRE book (Ch. 3–4), while the specific multiwindow multiplier table comes from the 2018 SRE Workbook (Ch. 5, "Alerting on SLOs") — the two texts should never be conflated or credited to each other.*

## Why Paired Long/Short Windows

*Stub — to be filled by sub-issue #205. Brief: explains that the long window confirms the burn is real (statistically significant, not noise) while the short window confirms it is still happening (so the alert stops firing promptly after recovery) — a long window alone would keep paging for its full duration even after the underlying problem is fixed.*

## The Four Golden Signals Applied to This Skill

*Stub — to be filled by sub-issue #205. Brief: maps Latency, Traffic, and Errors onto the existing SLO burn-rate alerts already in `SKILL.md`, and introduces Saturation as the missing fourth signal.*

## Generic Saturation Alert Pattern

*Stub — to be filled by sub-issue #205. Brief: a resource-agnostic, ticket-severity alert pattern using `deriv()` to project time-to-exhaustion (mirroring `PipelineConsumerLagGrowing`'s existing trend technique), with a worked YAML example for a DB connection-pool saturation alert built on `prometheus-metrics-design`'s existing `db_pool_in_use / db_pool_max` query, promoting it from dashboard-only to an actual alert.*
