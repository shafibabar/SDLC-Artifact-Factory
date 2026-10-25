---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Ideate on the **standard** profile for **Shelfstack**, special-order software for independent bookshops. Our approved artifacts:

- **Impact map (ideate/impact-map.md):** goal KR-1.1 "share of customer special orders in the customer's hands within 7 days, 45% → 80% by 2027-06-30". Selected path: bookseller → orders from the supplier the same day instead of batching special orders into a weekly order → OPP-1.2 "I forget which customer asked for what until Friday" → **SOL-1** a special-order queue that groups the day's customer requests by supplier, ready to send; **SOL-2** a fixed 4 pm ordering slot on the staff rota (a working practice, no software); **SOL-3** an automatic text to the customer when their book arrives, with a hold-until date. Signal: median days from request to supplier order. Options (not selected): SOL-4 direct supplier API ordering; a customer-facing web order form.
- **JTBD analysis (ideate/jtbd-analysis.md):** J-1 "get a customer the book they asked for before they buy it elsewhere" (bookseller, P-1) with JS-1.1 "When a customer asks for a book we don't stock, I want to note it once, so it gets ordered without me remembering" and JS-1.2 "When the order arrives, I want the customer to know straight away, so the book doesn't sit on the hold shelf"; J-2 "get a book the shop doesn't have without chasing it" (customer, P-2) with JS-2.1 "When I've asked the shop for a book, I want to hear when it's in, so I can collect it on my way past".
- **Functional requirements (ideate/requirements.md):** UR-1 (SOL-1: FR-1.1 record a request with customer and title, FR-1.2 group the day's requests by supplier, FR-1.3 mark a supplier order as sent); UR-2 (SOL-3: FR-2.1 text the customer on arrival, FR-2.2 release the hold after the hold-until date); TR-1 import open requests from the paper notebook. Assumptions: ASM-1 booksellers will record every request at the till (test T-1, not yet run).

Using this plugin's epic-definition skill, write the epic list artifact (in your reply, not to a file). Use whatever priority labels you think best.
