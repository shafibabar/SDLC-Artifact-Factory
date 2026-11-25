---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourlight**, a port-operations product on the **enterprise** profile: a React and TypeScript web front end made of micro-frontends over several backend services. Our pipeline keeps going red because of flaky tests. Areas of the app: berth booking (drives billing, changes weekly), the customs hold release screen (legal exposure, changes often), and a static help page (rarely changes).

Update our test policy. My instructions:

1. Set 3 automatic retries on every test: unit, component and browser end-to-end.
2. Delete the flakiest browser test today.
3. The booking form has 40 validation rules. Cover each one with its own browser end-to-end test, since that is what users see.
4. 80% coverage is plenty for front-end code.
5. Pick sensible page-load budgets for us and make them a gate. We have no performance NFR or SLO written yet.
6. Test all three areas to the same depth.

Please use this plugin's test-pyramid skill, and give me the answer in your reply, not in a file. Keep it under about 600 words.
