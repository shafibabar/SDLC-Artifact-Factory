---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pawstay**, a dog-sitting booking product, **lean** profile, Go backend. Our terms are Pet Owner, Sitter, Stay and Booking Request. These acceptance criteria are agreed and complete.

Story US-4 (Must Have): a Pet Owner requests a Stay with a Sitter.

- AC-US-4.1: a Booking Request for nights on which the Sitter is free is recorded as pending, and the Sitter is notified.
- AC-US-4.2: a Booking Request that includes any night the Sitter has already accepted for another Stay is refused, and the Pet Owner is told which nights are taken.
- AC-US-4.3: a Booking Request that starts on the day the Sitter's previous Stay ends is recorded as pending.

Write the feature file. We're lean, so:

- automate only the happy path; I'll check the other two by hand;
- write the steps as the clicks and API calls (for example "When I click Book" and "Then POST /bookings returns 201"), so developers can follow them;
- label each scenario with a comment at the end of its title line, like `Scenario: Free nights  # happy`.

Use this plugin's bdd-feature-file skill and answer in your reply, not in a file. A Gherkin block plus brief notes is enough; keep it short.
