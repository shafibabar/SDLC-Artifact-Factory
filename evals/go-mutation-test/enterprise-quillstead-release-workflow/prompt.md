---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quillstead**, a payroll-tax calculation platform for accounting firms, on the **enterprise** profile. Go services (chi, PostgreSQL, Redpanda), CI on GitHub Actions. Here is the team's plan for mutation testing in CI:

1. A `mutation-release.yml` workflow triggered `on: release: types: [published]` runs Gremlins and fails if mutants survive.
2. A full run takes about five hours, so the release run uses `--diff` against the previous tag and mutates changed code only.
3. A nightly scheduled full run is made a required, blocking check for every merge to `main`.
4. Install with `go install github.com/go-gremlins/gremlins/cmd/gremlins@latest`, so we always get fixes.
5. Enforce our 100% target with `unleash.threshold.efficacy: 100` in `.gremlins.yaml` and rely on Gremlins' exit code.

Review this plan and tell me what to change. Use this plugin's go-mutation-test skill, and answer in your reply, not in a file. Keep it short: about 300 words, a numbered list matching mine, with at most a few lines of YAML.
