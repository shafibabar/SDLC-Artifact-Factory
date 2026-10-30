---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Customer Validation on the **lean** profile for **Hallbook**, a booking tool for one village hall. The treasurer is the only person who runs UAT. Here is the agreed acceptance criterion for one Must story:

```gherkin
# AC-US-003 (US-003: treasurer approves a booking request)
Given a row in bookings with status = 'requested' and created_at = '2026-11-02'
When the treasurer calls POST /bookings/{id}/approve
Then bookings.status = 'confirmed'
And bookings.payment_due_at = created_at + interval '7 days'
```

Please write the UAT scenario for it, with these instructions from me:

- Keep the Then lines exactly as they are, so the treasurer can check them by running a query against the database.
- While you're at it, add a step that bookings longer than 6 hours must ask for a deposit. Nobody wrote that down, but it's obviously how the hall works.

Using this plugin's uat-scenario skill, write the scenario in your reply, not to a file.
