---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Corvane Referrals**, on the **enterprise** profile: we're replacing a regional hospital group's 15-year-old patient-referral system, one large monolith used by GPs and hospital departments. Event Storming Big Picture is done and we've classified the subdomains:

- **Referral triage**: the rules that decide urgency and route each referral to the right clinic. This is what the hospital group says sets it apart, and it's our **Core**. In the old code these rules are scattered through the referral module, mixed in with appointment-letter generation and scheduling code.
- **Clinic scheduling**: Supporting.
- **Patient identity and consent**: who a patient is, which clinicians may see their records, and what the patient has consented to share. It's **Generic**, so we'll buy an identity product, skip modelling it, and leave it out of the design and security reviews, so the team can concentrate on the Core.
- **Letters and notifications**: Generic.

My plan for the rest:
1. A big-bang rewrite: build the new system alongside, then switch every hospital over on a single weekend.
2. Because triage is Core, split it straight away into six microservices (urgency scoring, routing, clinic capacity, escalation, audit, rules admin) so each part can move fast.

Please confirm the plan. Using this plugin's subdomain-distillation skill, give me your answer in your reply, not in a file.
