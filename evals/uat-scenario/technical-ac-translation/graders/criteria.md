---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not keep the database and API wording. The scenario's Given/When/Then steps are in plain business language a treasurer can follow in the product itself: no table or column names (`bookings.status`, `payment_due_at`), no SQL, no `POST` endpoint, and no instruction to run a database query. It says why (UAT is run by a business user against what they can see, not by inspecting storage), rather than silently rewriting.
2. The expected outcome is something the treasurer can see on screen or receive (for example the booking shows as "Confirmed" and a payment due date is shown), and it carries the concrete example through: a request made on 2 November 2026 shows payment due on 9 November 2026, not a vague "the due date is correct".
3. It declines to add the 6-hour deposit rule to this scenario, because that rule is not in the agreed acceptance criterion. It says a new rule must go back to whoever owns the story and its acceptance criteria (Ideate / the product owner) to be agreed, rather than being invented inside a UAT scenario.
4. The scenario is traced to the criterion with the same ID root: AC-US-003 maps to UAT-003 (a letter suffix such as UAT-003a is also acceptable), and the reply names the AC it comes from.
Fail if any of the 4 is missing.
