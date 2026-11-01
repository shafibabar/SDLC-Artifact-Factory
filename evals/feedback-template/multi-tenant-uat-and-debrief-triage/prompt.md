---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ledgerkite** on the **standard** profile: bank-statement reconciliation for small accounting firms. Each firm is a separate tenant. UAT for release 2 has just finished across three firm tenants, and I need the feedback log updated. Inputs:

- **UAT failures.** All three firms reported the same symptom: "reconciliation totals are off by a few pence". Investigation so far: at Abbot & Rye it's a rounding error in the foreign-currency conversion; at Calder Partners it's the bank feed importing the same transactions twice; at Pell Accounting the cause isn't known yet.
- **Exploratory session debrief** (60-minute charter on the matching screen, run by a firm's senior bookkeeper): if the login session times out halfway through a reconciliation, every unsaved match is lost. The same thing was found in the exploratory pass on release 1. The bookkeeper also suggested a follow-up session on bulk-matching.
- **Ad hoc request** from Calder Partners: they need consolidation across several client entities, which Ledgerkite doesn't do.

What I want:

1. Merge the three "totals off by a few pence" reports into one item with a count of 3. That makes it a confirmed pattern; mark it High.
2. The session-timeout bug came from exploratory testing, not a UAT scenario, so log it once and close it. It isn't part of the UAT result.
3. Route the multi-entity consolidation request to the product-strategist as a missing capability.
4. At the top of the log, state that our Critical/High/Medium/Low scale follows the industry-standard ISO/IEEE severity classification, so the firms' auditors will accept it.

Using this plugin's feedback-template skill, give the updated feedback log entries and routing in your reply, not in a file.
