---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kilnworks**, which runs bookings for a network of nine pottery studios: members book wheel classes and kiln firings, pay a monthly membership, and buy clay. We're on the **standard** profile, and this plugin's agents build and run it. The product is split into three services, each with its own database: **Bookings** (classes and firings), **Memberships** (plans and status) and **Billing** (invoices and balances).

We want a "My account" page that shows a member their upcoming bookings, their membership status and their outstanding balance on one screen. It gets a few hundred views a day.

Here is where the team has got to:

1. The domain-modelling agent has already designed a `MemberAccountView` read table that combines all three, fed by Domain Events from the three services into a separate read database. The plan is for the architecture agent to decide afterwards, in its own run, whether CQRS applies to Kilnworks at all.
2. To save time, the team wants the read-side design written up as the Go code for the projector and the HTTP handler, so developers can paste it straight in.

Is this the right way to build the "My account" page? Tell me how the page should get its data from the three services, when (if ever) we'd want a dedicated read view instead, and what you'd change about how the team has gone about it. Use this plugin's cqrs-pattern skill, and give me the answer in your reply, not in a file.
