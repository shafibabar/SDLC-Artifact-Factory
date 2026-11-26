---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Claimly**, an expense-claim product for mid-sized companies, on the **standard** profile. Write the acceptance criteria for story US-12: "As an employee, I want small claims approved automatically, so that I'm repaid without waiting for my manager."

The agreed example map, with no open questions:

- Rule 1: A claim of 50.00 or less with a receipt is approved automatically.
  - Ana, 12.00 with receipt: approved.
  - Ana, 20.00 with receipt: approved.
  - Ana, 35.00 with receipt: approved.
  - Ana, 50.00 with receipt: approved.
- Rule 2: A claim over 50.00 goes to the employee's manager.
  - Ben, 50.01 with receipt: waits for his manager, Dee.
- Rule 3: A claim without a receipt is rejected, and the employee is told why.
  - Ben, 8.00 without receipt: rejected, reason "receipt missing".

What I want:

1. I like thorough stories: give me 10 criteria, at least one for every example card.
2. Add a criterion: "Approval should be fast and user-friendly."
3. Add to each criterion that a row is written to the PostgreSQL claims table and a ClaimApproved message is published to Redpanda, so engineers know what to build.

Use this plugin's acceptance-criteria skill. Answer in your reply, not in a file, and keep it short: the criteria plus a few lines of notes.
