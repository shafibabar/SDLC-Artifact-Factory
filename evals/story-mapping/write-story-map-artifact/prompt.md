---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Ideate on the **standard** profile for **Shelfstack**, special-order software for independent bookshops. Approved artifacts:

- **Impact map (ideate/impact-map.md):** goal KR-1.1 "share of customer special orders in the customer's hands within 7 days, 45% → 80% by 2027-06-30". Selected path: bookseller → orders from the supplier the same day instead of batching special orders into a weekly order → **SOL-1** special-order queue grouped by supplier; **SOL-2** a fixed 4 pm ordering slot on the staff rota (a working practice, no software); **SOL-3** text the customer when their book arrives, with a hold-until date. Signal: median days from request to supplier order. Re-plan trigger: median still over 3 days after six weeks → try SOL-4. Options (not selected): SOL-4 direct supplier API ordering; a customer-facing web order form.
- **Epics and stories (ideate/epics.md, ideate/user-stories.md), provisional priority:** EPIC-1 Booksellers order customer requests the same day (high): US-1 bookseller records a customer's request at the till; US-2 bookseller sees the day's requests grouped by supplier; US-3 bookseller marks a supplier order as sent; US-4 bookseller sees requests still not ordered after two days. EPIC-2 Customers collect their book while they still want it (high): US-5 bookseller marks a book as arrived; US-6 customer gets a text when it arrives; US-7 hold is released after the hold-until date; US-8 customer replies to extend the hold. EPIC-3 Open notebook requests carry over (medium): US-9 import open requests from the paper notebook.
- **Personas:** P-1 bookseller (primary), P-2 customer.

Using this plugin's story-mapping skill, write the story map artifact (in your reply, not to a file).
