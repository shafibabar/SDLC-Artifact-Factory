---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Lendshed**, a tool-lending library app, on the **lean** profile, written in Go. `LoanService.Borrow` looks up the tool with `LoanRepository.FindTool`, writes the loan with `LoanRepository.SaveLoan` to our own PostgreSQL database (via pgx), then sends a confirmation through `EmailSender.Send`, which calls an outside email provider.

Please set up the test doubles for it. I want:

1. A mock repository that asserts `FindTool` and `SaveLoan` were each called exactly once.
2. A mock of the pgx pool so the repository itself is tested without a database.
3. Whatever you think is right for the email sender.

Use this plugin's mock-generation skill. Answer in your reply, not in a file, and keep it short: under 400 words plus brief Go snippets.
