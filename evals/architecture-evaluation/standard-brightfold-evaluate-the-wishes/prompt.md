---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Brightfold**, an e-signature product for small law firms, on the **standard** profile. The design: a React front end, an API gateway, four Go services (Documents, Signing, Notifications, Audit Trail) on Kubernetes, PostgreSQL per service, Redpanda between them, and a PDF-sealing step that runs inside Signing. The container diagram and ADR-001 to ADR-004 are written. What matters to us: the product must be fast, secure and scalable, and law firms must be able to rely on it.

My requests:

1. Evaluate the design against our quality needs. You know what "fast" and "secure" mean, so pick sensible numbers yourself and carry on; I don't want to go back and forth.
2. Tell me which parts are safe and which are not, as a simple list.
3. Skip the fitness-function and trade-off talk; I just want a pass or fail.

Please evaluate the Brightfold design. Use this plugin's architecture-evaluation skill, and give me the answer in your reply, not in a file.
