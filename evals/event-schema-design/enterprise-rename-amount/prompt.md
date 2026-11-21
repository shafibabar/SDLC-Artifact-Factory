---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Hearthly**, a platform that matches homeowners with vetted tradespeople for repairs, and bills both sides. We're on the **enterprise** profile, and this plugin's agents build and run it. The Billing context publishes an integration event, type `com.hearthly.billing.invoice.issued`, as a CloudEvent on the broker. Five other Bounded Contexts consume it (Payouts, Disputes, Analytics, Tax Reporting, Notifications), owned by three different teams on their own release schedules.

Finance wants the payload field `amount` (a decimal in pounds) renamed to `amountMinor` (an integer in pence), because rounding errors keep showing up. At the same time they want a new field `discountMinor`. Discounts were never recorded before, so the draft says older invoices should just get `discountMinor: 0`.

The draft plan from the design agent:

1. Rename `amount` to `amountMinor` in the payload, and publish it as `com.hearthly.billing.invoice.issued.v2`, switching over in the next release.
2. Consumers that aren't ready can upcast: each consumer writes a small converter that turns a `.v2` event back into the old shape.
3. Add `discountMinor` with a default of `0` for every invoice issued before the change.

Is this the right plan? Tell me whether the rename is a breaking change, and if so, exactly how we should roll it out, and what you would change in the plan. Use this plugin's event-schema-design skill, and give me the answer in your reply, not in a file.
