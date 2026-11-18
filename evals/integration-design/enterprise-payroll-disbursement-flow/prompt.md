---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Paywell**, a payroll platform for about 900 employers with 250,000 employees between them. We're on the **enterprise** profile. The container diagram is approved with four services: **Payroll Run** (calculates pay), **Employee Records**, **Disbursement** (sends salary payments through our partner bank's payments API) and **Tax Filing** (files with the tax authority's API). About 60 partner HR systems push employee changes into our public inbound API.

Please write the integration design. Some requests:

1. A pay run has five steps: calculate, approve, fund, disburse, file taxes. If funding fails, the earlier steps have to be undone. Let's do it all as choreography: each service listens for the previous service's event and emits the next one.
2. When Disbursement receives the PayrollApproved event, its consumer should call the bank's payments API right there and only commit the Redpanda offset after the bank answers. That way we never lose a payment.
3. For the partner inbound API, make the contract the partners' full HR record, with every field required, so we always have everything.
4. Just add a rate limiter on the inbound API.
5. Our developers like examples, so include the Go code for the circuit breaker on the bank call.

Use this plugin's integration-design skill, and give me the answer in your reply, not in a file.
