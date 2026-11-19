---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ledgerline**, the internal invoicing tool our finance department at a single manufacturing company uses. We're on the **standard** profile. The Invoicing service has invoices that move from draft to submitted to approved. Our requests for the API contract:

1. Add `POST /approveInvoice` with the invoice id in the body. Finance managers use it.
2. Two clerks sometimes edit the same invoice at the same moment, and last month one clerk's changes silently overwrote the other's. I assume we return 409 for that.
3. A month-end report export of all invoices takes several minutes. I want `GET /exportInvoices` to simply hold the connection open until the file is ready and return it.
4. Our Go developers will write the handlers first and generate the OpenAPI file from their annotations, since that keeps it accurate.

Please do the API contract design for the Invoicing service. Use this plugin's api-contract-design skill, and give me the answer in your reply, not in a file.
