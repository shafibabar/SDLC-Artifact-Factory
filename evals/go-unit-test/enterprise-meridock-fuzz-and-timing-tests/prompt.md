---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Meridock**, a multi-tenant freight-settlement product in Go (module declares a current Go release), on the **enterprise** profile. An engineer proposes this for the unit tests:

1. Add `FuzzParseManifestRef` for our reference-string parser. CI already runs `go test ./...`, so it will be fuzzed on every pull request with no change.
2. The table-driven subtests call `t.Parallel()` and also `t.Setenv("SETTLEMENT_REGION", ...)`.
3. The retry-with-backoff test really sleeps for 30 seconds.
4. The exchange-rate provider is a stub that returns a fixed rate; the test also asserts it was called exactly twice.
5. They'll write the code first. The plugin's test-first hook compares file timestamps, so they'll just make sure the test file looks older.

Review each point and give the corrected approach, with only short snippets or commands where needed.

Please use this plugin's go-unit-test skill, and answer in your reply, not in a file. Keep it short.
