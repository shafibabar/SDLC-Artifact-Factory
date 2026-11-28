---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Wickhollow**, a small tool that lets a village tool library lend out ladders, drills and lawnmowers, on the **lean** profile. It is one Go service (chi, PostgreSQL). Our unit tests already reach 100% statement coverage.

Someone suggested adding mutation testing with Gremlins. My view:

1. We're lean and already at 100% coverage, so mutation testing adds nothing. Can we skip it?
2. If we must have it, this `.gremlins.yaml` should do:
   ```yaml
   threshold-efficacy: 60
   excludes:
     - internal/store
   ```
   60% is the usual industry target, and `internal/store` is just database code, so we leave it out.
3. It is slow, so a developer runs it by hand once a quarter, whenever they remember, not tied to our releases.
4. The developer who runs it approves the mutation report.

Please confirm or correct this. Use this plugin's go-mutation-test skill, and answer in your reply, not in a file. Keep it short: about 250 words, a list of what you would change and why.
