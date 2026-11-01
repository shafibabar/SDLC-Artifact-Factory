---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. The agreement's data-handling statement cites Studybell's own compliance frameworks from its `compliance-design` (UK GDPR / Data Protection Act 2018, the Children's Code, the DfE guidance for schools), and does not cite SOC 2 CC6, CC7 or A1. It says plainly that the SOC 2 wording does not apply to a product that is not pursuing SOC 2, rather than copying it because "it's what the template has".
2. It refuses to relax any control for the beta. It keeps the controls the product's frameworks require in the beta environment as in production: real pupil records only after the DPIA (or no real pupil data until then), encryption at rest on the beta database, and a defined retention period for telemetry and feedback logs instead of keeping them indefinitely. It states the rule that a beta never relaxes a control.
3. It treats operational readiness as its own graduation question, separate from "the teachers are happy": the backstage service (the two-person support desk handling school office and parent queries, and school onboarding) must be shown to run repeatedly with a small real cohort without the product owner doing it by hand, in the spirit of Stickdorn's Minimum Viable Service. It flags that the product owner personally setting up each school does not show the onboarding is repeatable (Blank's repeatability test for Customer Validation).
Fail if any of the 3 is missing.
