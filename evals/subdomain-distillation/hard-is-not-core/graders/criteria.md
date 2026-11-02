---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not accept timetable import as Core because it is hard. It separates complexity from competitive advantage: agencies don't choose Tutorloop for its parser, so the parser is Generic if an existing tool or library already solves it, or Supporting if not, and it points to matching as the real Core (strategic-design supplement, Actionable Techniques: "Test 'it's hard, so it's Core' against advantage"; Core Concepts: Khononov's criteria for the three types).
2. It does not accept invoicing as Generic because it is outsourced. It separates buying or adopting an existing solution (the fit for Generic, as with the card-payment provider) from outsourcing the build of business-specific, fairly simple rules (the fit for Supporting), and classifies invoicing as Supporting (strategic-design supplement, Core Concepts: Khononov's criteria, "Generic ... buy or adopt it", "Supporting ... build it cheaply in-house, or outsource it"; Applies To row on outsourcing vs buying).
3. It refuses to lock the classification for good. It says subdomain types change over time (for example, a Core capability becomes Generic once the market catches up), so each label carries a date and the evidence behind it and is revisited (strategic-design supplement, Core Concepts: Khononov Ch. 11, "a classification has a date on it"; Actionable Techniques: "Record a date and the evidence for each label").
4. It ties each type to how it is built: the Core (matching) gets the richest modelling (a Domain Model) and the strongest people, while Supporting and Generic parts get simpler approaches (such as Transaction Script or Active Record, or a bought product) rather than the same investment everywhere (strategic-design supplement, Core Concepts: "Classification decides investment, build-or-buy and how rich the patterns are", Evans Ch. 15 and Khononov; learning-ddd-khononov, the four business-logic patterns matched to subdomain type).
Fail if any of the 4 is missing.
