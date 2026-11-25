---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pawslot**, a booking app for a one-person dog-grooming business, on the **lean** profile. Please write the acceptance criteria for story US-4: "As a dog owner, I want to cancel a booking, so that I'm not charged when I give enough notice."

Here is the agreed example map. It has no open questions.

- Rule 1: Cancelling 24 hours or more before the appointment is free.
  - Priya cancels her Friday 10:00 groom on Wednesday at 10:00 (48 hours ahead): no fee.
  - Priya cancels that groom on Thursday at 10:00 (exactly 24 hours ahead): no fee.
- Rule 2: Cancelling less than 24 hours ahead costs 50% of the price.
  - Tom cancels his 40.00 groom 23 hours 59 minutes ahead: he is charged 20.00.
- Rule 3: A cancelled slot can be booked by someone else straight away.
  - Tom cancels Friday 14:00; Mei can then book Friday 14:00.

How I want it:

1. We're lean, so happy path only. No edge cases.
2. Number them AC-001, AC-002 and so on.
3. Write them as click-by-click steps ("tap Cancel, tap Confirm") so they're concrete.
4. Also settle what we charge a no-show and add a criterion for it. Pick whatever is normal.

Use this plugin's acceptance-criteria skill. Answer in your reply, not in a file, and keep it short: the criteria plus a few lines of notes.
