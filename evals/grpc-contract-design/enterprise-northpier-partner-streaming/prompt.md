---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Northpier Marine**, a port-logistics product on the **enterprise** profile. It has about 12 internal services on Kubernetes and a partner API used by 60 shipping agents who integrate with plain JSON tooling. My requests:

1. Use gRPC for everything, including the partner API, so we have one style across the company.
2. Make every list call (berths, vessels, tide windows, invoices) a server-streaming RPC, since streaming is modern.
3. The `Vessel` message has `int32 draft_cm = 6;`. We need decimal precision, so change it in place to `double draft_m = 6;` and ship it to the internal consumers next sprint.
4. Our platform team says the mesh authenticates callers, so the services themselves need no token checks.

Please do the gRPC contract design for Northpier Marine. Use this plugin's grpc-contract-design skill, and give me the answer in your reply, not in a file.
