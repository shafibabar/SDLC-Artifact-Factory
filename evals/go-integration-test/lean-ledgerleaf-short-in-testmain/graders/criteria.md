---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects exiting from `TestMain` under short mode, because that skips every test in the package, including the plain unit tests. Instead each integration test (directly or through a shared helper that receives the test) calls `t.Skip` when `testing.Short()` is true. Also mentioning build tags as another way to separate suites does not fail, provided the integration tests are not removed from the normal full check.
2. It replaces the 5-second sleep with the PostgreSQL module's wait strategy (`BasicWaitStrategies()`, or an explicit wait for the readiness log line and the listening port), and replaces `postgres:latest` with a specific version tag. Which version is chosen does not matter.
3. It handles the container's life cycle: in `TestMain` a start step that returns an error rather than needing a `*testing.T`, with the container terminated after `m.Run`; or, if the container is started inside a test, `CleanupContainer` registered before the start error is checked.
4. It makes rolling back a transaction per test the default isolation, in place of truncating all tables after each test, and reserves another method (data scoped to the test, or a snapshot or reset) for tests that need a real commit.
5. It keeps these tests against a real PostgreSQL and rejects the in-memory fake as a substitute for them, because the database is a dependency the application controls and the repository is verified by the resulting state in the real database. Saying a fake is fine in separate unit tests of other code does not fail.
Fail if any of the 5 is missing.
