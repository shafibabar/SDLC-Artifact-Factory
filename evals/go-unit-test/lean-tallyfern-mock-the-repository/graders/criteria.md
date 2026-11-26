---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects mocking the repository and asserting that `Save` was called once: the repository is a managed dependency (the product's own database), so it is verified by end state, with a state-based fake in unit tests and/or an integration test against the real database, never by call-count verification.
2. It uses a mock (verifying that the call happened, with its arguments) for the `InvoiceMailer`, because the email is a side effect observable outside the application (an unmanaged dependency). A hand-written or generated double both count.
3. It refuses to assert on the private `feeCents` field and asserts only observable behaviour through the public contract (return value, public accessor or resulting state), explaining that otherwise a refactor that changes no behaviour breaks the test.
4. It does not give the thin HTTP handler the same exhaustive unit testing: the unit-test effort goes to the fee rule (domain logic), and the handler/controller layer is kept thin and covered mainly by a handful of integration tests.
5. The late-fee cases include the values on both sides of both boundaries: 7 and 8 days, and 30 and 31 days overdue.
6. It rejects the 80% target: the target is 100% (statements and branches) at lean as at every other size. Mentioning that the product owner may waive a remaining gap only after measurement, when the result is above 90%, or approve a listed coverage exclusion, does not fail this.
Fail if any of the 6 is missing.
