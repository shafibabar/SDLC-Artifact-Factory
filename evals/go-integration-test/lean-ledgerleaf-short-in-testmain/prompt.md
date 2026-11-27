---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Ledgerleaf**, a bookkeeping tool for sole traders, on the **lean** profile. It is one Go service on PostgreSQL (pgx), with an invoice repository that has no tests yet. I want its integration tests set up like this:

1. In `TestMain`, if `testing.Short()` is true, call `os.Exit(0)` so quick runs skip the database. The same package also holds plain unit tests.
2. Start `postgres:latest` in a container and sleep 5 seconds so it is ready.
3. After each test, `TRUNCATE` all the tables.
4. If Docker is slow, we can swap in an in-memory fake of the repository for these tests.

Please give me the setup and one example repository test. Use this plugin's go-integration-test skill, and answer in your reply, not in a file. Keep it short: brief code and a few lines on anything you changed.
