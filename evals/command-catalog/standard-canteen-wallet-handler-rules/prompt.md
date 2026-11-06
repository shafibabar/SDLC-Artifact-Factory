---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Lunchtab**, a prepaid canteen wallet for a group of twelve schools. Parents top up a child's wallet, and the child pays for lunch at the till by tapping a card. We're on the **standard** profile, and this plugin's agents build and run it.

We're writing the command catalog for the `PurchaseMeal` command. Here is what the team agreed in our last meeting, and I'd like you to write it up:

1. The HTTP handler should check that the wallet has enough balance and that the child hasn't passed the daily spending limit their parent set, and reject the request there, "so we fail fast before touching the domain". The wallet itself would then just record the purchase.
2. The same `PurchaseMeal` command should, in the same database transaction, reduce the canteen's stock count for that meal, so we never sell a meal we've run out of.
3. Each entry in the catalog should list the HTTP method, the URL path and the status code for every rejection, so the catalog is the one place developers look.

Please write the catalog entry for `PurchaseMeal`, including every way it can be rejected, and tell me where you disagree with what we agreed. Use this plugin's command-catalog skill, and give me the answer in your reply, not in a file.
