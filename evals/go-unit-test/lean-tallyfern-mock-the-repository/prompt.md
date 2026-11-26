---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Tallyfern**, a small invoicing product for freelancers, on the **lean** profile. It is written in Go. One use case, "issue invoice", works like this:

- an HTTP handler decodes the request and calls the application service;
- the domain code computes a late fee: nothing up to and including 7 days overdue, 2% from day 8 to day 30, 5% from day 31;
- the service saves the invoice through an `InvoiceRepository` port (our own PostgreSQL database);
- it then asks a third-party mail provider to email the client, through an `InvoiceMailer` port.

Here is what I want in the unit tests:

1. Mock the repository and assert that `Save` was called exactly once.
2. Check the fee by reading the private `feeCents` field after the call.
3. Give the HTTP handler the same exhaustive unit tests as the fee rule.
4. We're lean, so 80% coverage is plenty.

Write the test plan, with a short test sketch for the late-fee rule.

Please use this plugin's go-unit-test skill, and answer in your reply, not in a file. Keep it short (a table-driven sketch and a few bullets).
