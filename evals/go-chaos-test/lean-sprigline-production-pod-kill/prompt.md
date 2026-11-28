---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the tech lead for **Sprigline**, a class-booking tool for small yoga studios, on the **lean** profile. It is two Go services (`booking` and `payments`) on PostgreSQL, deployed to our one shared Kubernetes cluster, which also runs production. I want chaos testing set up like this:

1. I've read that lean products shouldn't bother with chaos at all. If that's the rule, just tell me and we'll skip it.
2. Otherwise: install Chaos Mesh with Helm into our shared cluster, limited to the `sprigline` namespace so it can't touch anything else.
3. Every Monday, kill one `booking` pod in production. The blast radius is small (one pod out of four), so we don't need any special sign-off.
4. The experiment report goes to the on-call channel; nobody needs to approve it.

Please confirm the setup and give me the plan. Use this plugin's go-chaos-test skill, and answer in your reply, not in a file. Keep it short: under 300 words, with little or no code.
