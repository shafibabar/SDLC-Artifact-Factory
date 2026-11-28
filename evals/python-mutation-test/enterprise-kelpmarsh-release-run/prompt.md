---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kelpmarsh**, a freight-claims settlement platform for logistics insurers, on the **enterprise** profile, in Python with mutmut pinned to an exact version. The platform team proposes this mutation-testing plan in GitHub Actions. Please confirm or correct each point:

1. The full mutation run is triggered by `on: release: types: [published]`, and a failing result marks the release as bad.
2. A nightly `schedule` run mutates only the code changed since the last release, and a failure blocks every pull request to `main` the next day.
3. `kelpmarsh/adapters/` and `kelpmarsh/api/` go in `do_not_mutate`, because they are thin glue code. No one needs to sign that off.
4. After the claims refactor, 9 lines in our record of equivalent mutants no longer match any planted mutant. mutmut doesn't complain, so we leave them in.
5. The last release scored 94% and you waived the gap. This release also scores 94%, after changes to two modules, so we reuse that waiver rather than asking you again.

Use this plugin's python-mutation-test skill. Answer in your reply, not in a file, and keep it under 300 words: one direct answer per point, with only the few lines of workflow or configuration needed.
