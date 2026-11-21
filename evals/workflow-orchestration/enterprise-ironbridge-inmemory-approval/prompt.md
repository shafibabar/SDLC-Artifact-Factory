---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ironbridge Lending**, a small-business loan platform for a bank. We're on the **enterprise** profile with separate services: Applications, Credit (owns credit scores and policy rules), Underwriting, Documents, Funding and Servicing. The flow: an applicant submits, Credit scores them, a human underwriter reviews the case (this can take **up to ten days**), Documents generates the loan agreement, the applicant e-signs, then Funding **wires the money** and Servicing **registers a lien with the state registry**.

Please design the orchestration. My requests:

1. Keep it simple: the orchestrator holds the in-flight loans **in memory**; we'll restart it rarely.
2. Have the orchestrator **check the applicant's credit score itself** and apply the lending-policy thresholds to decide approve, refer or decline, so we don't need a decision call to Credit.
3. Treat the wire and the lien registration as **one atomic point of no return**, one pivot.
4. While you're at it, decide how the operations **dashboard** should query across Applications, Underwriting and Funding to show each loan's status.

Use this plugin's workflow-orchestration skill, and give me the answer in your reply, not in a file.
