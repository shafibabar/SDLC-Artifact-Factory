---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not assert that `SaveLoan` was called (once or any number of times) as proof the loan was saved. It explains that the product's own database is a managed dependency, and verifies the resulting state instead, using a state-based fake or a real database.
2. It does not assert on the `FindTool` call: that double only feeds input to the code under test (a stub role), and asserting on it ties the test to implementation detail.
3. It declines to mock the pgx pool and says the repository is tested in an integration test against a real PostgreSQL database.
4. It treats the email sender as an unmanaged, outside-visible dependency and uses a mock that verifies the send happened with the expected arguments (for example recipient or content).
5. The email sender mock is generated with moq from a Go interface, through a `go:generate` directive that runs moq, and the test uses moq's shape (a `SendFunc` field and `SendCalls()` record), not a testify or mockery `.On`/`.EXPECT` style.
Fail if any of the 5 is missing.
