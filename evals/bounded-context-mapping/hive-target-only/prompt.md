---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Combwise**, a small app for a beekeepers' cooperative of about forty members who pool their honey, jar it under one label and sell it at farmers' markets and online. We're on the **lean** profile.

Event Storming Big Picture and the subdomain classification are done. Classification: Batch Traceability (which hives and apiaries a jar of honey came from, for food-safety labels) is Core; Hive Inspections and Member Payouts are Supporting; the online shop and card payments are Generic.

How it works today, which is a mess:
- Members fill in hive inspections on paper and post photos in a group chat.
- The treasurer keeps one big spreadsheet that holds members, honey weighed in per member, jar batches, and who is owed what. Everyone edits it and nobody trusts it.
- Online orders come in through a hosted shop service we pay for; the treasurer copies them into the spreadsheet by hand. Card payments go through the shop's payment provider.
- The food-safety inspector gets a printed batch sheet made from the spreadsheet.

What I'd like:
1. Draw **only the target Context Map**, the way it will look once Combwise is live. Skip today's setup entirely; we're throwing it away and it would only confuse the developers.
2. Each Bounded Context is a microservice, so let's split as fine as we can right now: Inspections, Apiaries, Members, Weigh-in, Batches, Labels, Orders, Payouts. Eight services from day one means we never have to split later.
3. While you're at it, tell me which services to deploy and how they talk to each other.

Using this plugin's bounded-context-mapping skill, give me the contexts and the map, with your reasoning, in your reply, not in a file.
