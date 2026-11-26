---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It refuses the rollback wrapper for the outbox test, because the test needs a real commit: uncommitted rows are not visible to the relay's separate connection, so the behaviour under test cannot be proven.
2. For that test it uses data scoped to the test (for example identifiers unique to this test, with queries and assertions limited to them) and removes only that data afterwards from both tables, without truncating or wiping the shared tables.
3. Failures of that cleanup are reported (logged or failing the test), not silently ignored.
4. It keeps rollback as the default for the other database tests, treating scoped committed data as the exception for cases that need a real commit.
5. It fixes the cause of the golden-file failure by making the payload deterministic (fixed or injected event ID and time, or equivalent normalising of those values).
6. It rejects updating golden files automatically in CI: updates are a deliberate step whose diff is reviewed, and the update command is scoped to the `events` package, not `./...`.
Fail if any of the 6 is missing.
