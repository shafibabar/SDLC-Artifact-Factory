---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **ClaimHarbor**, a SaaS platform that regional insurers use to process property damage claims: policyholders file claims with photos, adjusters assess them, and payments are released once a claim is approved. We're on the **enterprise** profile, with about 40 insurer customers in the EU and the US, and four teams. The NFRs say EU insurers' claims data must stay in the EU, and two large insurers have asked about isolation in their contracts. We have **not** run the multi-tenancy design yet. We use the default stack: Go with chi, PostgreSQL, Redpanda, React + TypeScript, Kubernetes, OpenTofu + Helm, Linkerd.

The services are agreed: **Claim Intake**, **Assessment**, **Payments** and **Policy Lookup**, plus the React adjuster portal and an API gateway. Please draw the container diagram. Some requests:

1. Ops wants to see sizing, so please write the pod counts and autoscaling limits on each container box (for example "Assessment ×6 pods, HPA max 20"), and add "×40" next to each database to show there's one per insurer.
2. Use the plugin's standard tenancy model. I believe that's one dedicated stamp per insurer, so draw a full stamp for each tenant on the container diagram.
3. Also give me a separate deployment diagram as its own artifact for the platform team.
4. And a component diagram for every one of the four services, so the set is complete.

Use this plugin's container-diagram skill, and give me the answer in your reply, not in a file.
