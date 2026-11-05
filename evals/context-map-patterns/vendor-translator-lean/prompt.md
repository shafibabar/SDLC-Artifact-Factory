---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Hopwell**, a small app that independent craft breweries use to take wholesale orders from pubs and keep track of the steel kegs they lend out. We're on the **lean** profile. This plugin's agents build and run it; there is no separate engineering team.

The Bounded Contexts are already settled (the subdomain classification was done last week):
- **Wholesale Ordering** (Core): pub accounts, price lists, orders, delivery slots.
- **Keg Tracking** (Supporting): which keg is at which pub, deposits owed.
- **Payments** (Generic): taking card and bank payments for orders.

There are two outside systems:
- **Paylane**, a payment provider. Its API is well documented, versioned, and its model (PaymentIntent, Charge, Refund, Payout) is clean and matches how we think about payments. Paylane will not change anything for us; we're one of thousands of small customers.
- **The brewery's old stock spreadsheet**, exported nightly as a CSV. Columns are renamed whenever someone feels like it, one column mixes "litres" and "firkins", and "batch" sometimes means a brew and sometimes a pallet. Wholesale Ordering needs the stock levels from it.

The design agent's draft Context Map says:
1. Paylane → Payments: **Anticorruption Layer**, "because our rule is that every external API always gets an ACL." The ACL is a `PaylaneTranslator` that maps Paylane's PaymentIntent, Charge, Refund and Payout one-to-one into our own PaymentIntent, Charge, Refund and Payout, with the same field names and the same meanings.
2. Alternatively, a colleague suggests **Customer/Supplier** for Paylane, "since we pay them, so we're their customer."
3. Stock spreadsheet → Wholesale Ordering: **Conformist**, "to keep things lean, just read the columns as they are."

For each of those lines, tell me which relationship pattern you'd actually choose and why, and say what is wrong with the draft, if anything. Use this plugin's context-map-patterns skill, and give me the answer in your reply, not in a file.
