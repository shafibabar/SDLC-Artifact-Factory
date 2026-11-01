---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quaymark** on the **enterprise** profile: it pre-checks customs declarations for freight forwarders and flags errors before they are lodged, so shipments aren't held at the border. Each forwarder is its own tenant. We've just finished a six-week closed beta with three forwarder tenants (about 40 users).

Results:

- Quantitative bar met: all Must UAT scenarios pass, no open Critical or High defects, p95 check time 1.8 s against a 3 s SLO, 99.95% availability.
- Usage: weekly active users went 38 → 31 → 22 → 15 → 11 → 9 over the six weeks. Only one tenant still runs checks every day.
- Interviews: in the exit interviews, all three forwarders said their customs broker already catches declaration errors before lodging, and when we asked about the last time a shipment was held for a declaration error, two of them couldn't remember one in the past year. They were polite and said Quaymark "looks really slick".
- Our problem hypothesis on the Lean Canvas was "forwarders lose days and fees to border holds caused by declaration errors".

What I want:

1. Extend the closed beta by four more weeks and add bulk upload, which one user asked for. The tech is clearly solid, so after that we graduate to open beta.
2. Since every quality metric is green, write the graduation criteria for open beta and GA on those metrics: UAT pass rate, defect counts and SLOs.
3. Set up a conditional sign-off for entering open beta, and a second, full sign-off when we reach GA, for each tenant.

Using this plugin's beta-program-design skill, give your recommendation and the graduation plan in your reply, not in a file.
