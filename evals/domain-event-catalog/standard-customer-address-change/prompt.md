---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Leafbox**, a subscription service that ships a box of houseplants to customers every month. We're on the **standard** profile, and this plugin's agents build and run it. The Customer Accounts context owns the customer's delivery address. Three other Bounded Contexts care when it changes: Shipping (routes the next box), Billing (sales tax depends on the region) and Marketing (sends local nursery offers).

Customers change their address from a settings screen that saves the whole profile. The design agent's draft entry for the domain event catalog says:

1. Event name: `CustomerUpdated`, raised every time the profile form is saved, whatever changed.
2. To make sure the others act, Customer Accounts also publishes `RecalculateTaxRegion` to Billing and `SendNewNeighbourhoodOffer` to Marketing, so each context knows exactly what to do.
3. When we later change the payload in a way that breaks consumers, we'll publish `CustomerUpdated.v2` next to it.

Please give me the catalog entry for "a customer's address changed": what the event (or events) should be called, what the other contexts should do with it, and what you would change in the draft. Use this plugin's domain-event-catalog skill, and give me the answer in your reply, not in a file.
