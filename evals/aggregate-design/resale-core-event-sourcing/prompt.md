---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Resalo**, a fan-to-fan ticket resale marketplace. We're on the **enterprise** profile: several teams, millions of listings a season, and a consumer-protection regulator watching us.

The subdomain classification is done, and **Listings** is our Core subdomain (its own Bounded Context). The draft has three Aggregates in it:
- **Listing**: one seat (or a block of seats) for one event, with an asking price and a status (draft, live, sold, withdrawn). Sellers change prices often. Resale is capped at 110% of face value. When a buyer complains, the regulator can ask us to show the exact asking price, and whether the cap was met, for a given listing at any past minute, and they have fined other platforms whose answer came from logs that didn't match.
- **SellerProfile**: display name, short bio, avatar, and a response-time badge.
- **PayoutPreference**: which bank account a seller's money goes to, and whether payouts are weekly or per sale.

The architect's proposal:
1. "Listings is Core, and Core deserves the best patterns, so we event-source all three Aggregates: Listing, SellerProfile and PayoutPreference."
2. "Every event in every Aggregate's stream gets published to the broker so other contexts can subscribe, including the fine-grained ones like `ListingDraftAutosaved` and `PriceInputValidated`."
3. "When an event's shape changes, we do what we already do for our integration events: publish a v2, run v1 and v2 side by side for a release, then delete v1."

Tell me which of these Aggregates, if any, should be event-sourced and why, and what you would change about points 2 and 3. Use this plugin's aggregate-design skill, and give me the answer in your reply, not in a file.
