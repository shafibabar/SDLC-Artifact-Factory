---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Shelfmark**, a lending system for a town library network, **standard** profile, Go, scenarios run with godog. Our terms are Member, Loan, Renewal and Reservation. These acceptance criteria are agreed and complete.

Story US-7 (Must Have): a Member renews a Loan.

- AC-US-7.1: a Loan that has been renewed fewer than 2 times is renewed, and its due date moves 21 days later.
- AC-US-7.2: a Loan that has already been renewed 2 times is not renewed, and the Member is told the limit is reached.
- AC-US-7.3: a Loan on a book that another Member has a Reservation for is not renewed, whatever its Renewal count, and the Member is told it is reserved.

Please write the feature file, and:

- for thoroughness, give the Scenario Outline at least 10 rows: Renewal counts 0 and 1 repeated with different Member names and book titles, plus a few at 2;
- leave godog non-strict, so steps we haven't written yet don't turn the build red;
- confirm in one line that, because the feature files are in the repository and run in CI, we now have living documentation.

Use this plugin's bdd-feature-file skill and answer in your reply, not in a file. A Gherkin block plus brief notes is enough; keep it short.
