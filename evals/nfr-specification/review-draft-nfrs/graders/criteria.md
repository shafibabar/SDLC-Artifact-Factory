---
type: llm
weight: 1
---

The review makes ALL of the following points:
1. **Residency has two homes.** NFR-DATA-001 restates the residency rule that already lives in the FRD as BR-3. The review says the NFR should cite BR-3 (by ID) instead of writing the rule again, and keep only the measurable obligation on this system and how it is verified (for example every store, replica and backup in an EU region, checked by a test or policy check). Merely suggesting that a verification method be added, without saying the rule should be cited from BR-3 rather than restated, does not count.
2. **Conflict.** Active-active across EU and US regions (NFR-AVAIL-001) contradicts BR-3 / NFR-DATA-001, and the review says this must be recorded or flagged as a conflict or trade-off for the enterprise-architect and/or the user to decide.
3. **DORA rows are not product NFRs.** The delivery rates describe the team's delivery process; they should move out of the product NFRs (for example to optional process targets with values the user chooses, owned by dora-metrics or similar) and/or be replaced by a deployability requirement on the product; they should not be mandatory for every service.
4. **Tactic named as a requirement.** NFR-SEC-002 names a specific technology or design tactic (Linkerd / mTLS / a service mesh); the review says that choice belongs to the architecture or an ADR, and the NFR should instead state the testable outcome (for example all traffic between services encrypted in transit and authenticated, with a check that unencrypted or unauthenticated calls are refused).
Fail if any of the four is missing.
