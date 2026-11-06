# Example 1 — Lean: Commands in the Domain Model, Not a Catalog

Self-contained. **Splashdown** books swimming lessons for a single pool, at the **lean** profile: one deployable, contexts **Lessons** and **Families**. The phase plan skips `command-catalog` at lean, so the Commands go in the Commands table of `aggregate-design`'s `design/domain-model.md`, under the same naming, validation and idempotency rules.

## Input

> **User:** "We need `SaveBooking` (create or edit, with a `status` field for booked, cancelled, moved) and `SaveFamily`. Put the checks in the booking form so bad bookings never reach the server."

## Working it

- **Which intents?** `SaveBooking` with a status field hides three intents with different rules:
  - `BookLesson`: the class has a free place and the child's level matches;
  - `CancelBooking`: allowed up to 24 hours before the lesson, so the place can be offered again;
  - `MoveToAnotherClass`: the new class has a place and the same level.

  `SaveFamily` turned out to be only `ChangeContactDetails`; nothing else changes a family.
- **Checks in the form:** partly declined. The form may check shape (a child is chosen, a class is chosen) for a fast answer. The rules ("class has a free place", "24 hours before") stay in the Class and Booking models, because the pool's front-desk screen books lessons too and would skip a check that lives only in the form.
- **Retries:** a parent on poor mobile signal taps Book twice. The form sends one request ID per tap-to-book, kept across retries, and a repeat returns the first answer. Without it, the child takes two places.
- **Already in effect:** cancelling a cancelled booking succeeds and records nothing; the parent's goal is met.

## Output: the Commands section of `design/domain-model.md`

| Context | Command | Guard | Handled by | Idempotency |
|---|---|---|---|---|
| Lessons | BookLesson | class has a free place; child's level matches the class | Class | request ID kept across retries; a repeat returns the first answer |
| Lessons | CancelBooking | at least 24 hours before the lesson; already cancelled → succeed, record nothing | Booking | request ID; a repeat returns the first answer |
| Lessons | MoveToAnotherClass | new class has a place and the same level | Booking (the new class's place is checked first, as a reference) | request ID; a repeat returns the first answer |
| Families | ChangeContactDetails | a phone number or an email remains | Family | natural: same details again changes nothing |

## Why this is right

- The status field became three intents, each with a guard a parent would recognise.
- "Checks in the form only" was declined with its reason: the front desk is a second way in.
- Lean is shorter, but each Command still names its guard, its target and its retry rule.
