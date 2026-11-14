---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **ParkPass**, a SaaS that city councils use to sell residential and visitor parking permits online. We're on the **standard** profile with the default stack (Go with chi, PostgreSQL, Redpanda, Kubernetes). The container diagram is approved and has four Go services:

- **Accounts**: resident profiles and addresses. Plain CRUD.
- **Payments**: takes card payments through Stripe and publishes `PaymentSettled`.
- **Notifications**: consumes events and sends emails and SMS.
- **Permits**: issues and renews permits. This one is unusual. It checks every vehicle against the state motor-vehicle agency's old SOAP registration feed, and we wrap that feed in an anti-corruption layer so its odd field names and codes don't leak into our model. It also runs a projector that builds a "plate → valid permits" lookup table, which the parking wardens' handheld app reads.

The architect confirmed that Accounts, Payments and Notifications follow the plugin's standard Go service skeleton with nothing added. Please now draw the component diagrams. Some requests:

1. Draw one for **all four services**, so the set is complete and nobody asks why one is missing.
2. For Permits, put one box per handler function and per struct (`CreatePermitHandler`, `RenewPermitHandler`, `PermitRepo`, `DMVSoapClient`, `PlateLookupProjector`, and so on), so the developers see everything.
3. Just give us Mermaid. We paste everything into Confluence, so plain-text pictures and tables are a waste of time.

Use this plugin's component-diagram skill, and give me the answer in your reply, not in a file.
