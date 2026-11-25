# Finding Rules, Examples and Edges

Used while drawing an example map: rules (`R1`), examples (`R1.E1`: Happy, Negative or Edge) and questions (`Q-1`).

## Where rules come from

| Source | Becomes |
|---|---|
| The story's seed example | The first example; ask what must be true for it to be right |
| Business rules (BR-n) | A rule that cites the BR-n. Do not change its meaning; a conflicting example is a question |
| Functional fit criteria (who acts, the input, the observable result, how many) | Rules and examples citing the requirement ID |
| NFR specification | Not a rule. Cite the NFR ID with the story; a missing target is a question |
| Domain stories | Each variant story is a candidate example (Hofer and Schwentner) |
| Nothing | `assumption (Q-n)` plus the question |

A rule found with no example is a signal: if no concrete example can be produced, the story is not understood well enough (Pugh).

## From examples to a rule

1. Write one specific case: "Maya cancels her Saturday 14:00 booking on Thursday at 10:00".
2. Write its outcome.
3. Change one thing and ask whether the outcome changes: the time, the person, the amount, the state, the order of events.
4. After two or three cases, word the rule so that it explains all of them.
5. A case the wording cannot explain is a new rule or a question.

Change one thing at a time. An example that varies three things shows nothing about any of them.

## Edge categories

Consider each; add an example where it applies to this story, a question where the behaviour is unknown, and skip it where it cannot happen.

| Category | Ask |
|---|---|
| Permission | Who must not be able to do this, and what do they see? |
| Empty | What happens before there is any data? |
| Limit | Just under, exactly on, just over: amounts, counts, dates, time zones |
| Volume | The largest case the business expects |
| Concurrency | Two people, or the same person twice, at once |
| Repeat and order | The same request again; events arriving late or out of order |
| Dependency down | A payment, message or other outside service is unavailable |
| Tenant isolation | Only for a multi-tenant product: another tenant's user tries the same thing |

## Wording

Declarative: what is true for the business, not how someone clicks or which endpoint is called (Pugh; Adzic).

| Weak | Concrete |
|---|---|
| "A member can cancel in time" | "Booking Sat 14:00, cancelled Thu 13:59 → fee refunded in full" |
| "Click Cancel, then Confirm" | "Maya cancels the booking" |
| "The system handles a failed refund" | "The refund of £40 is rejected by the bank → the booking stays cancelled and the treasurer sees '£40 refund failed'" |

The last row asserts behaviour, so it needs a source or a question.

## Pruning

Keep the smallest set that pins the rule down (Adzic). For each example ask: if it were deleted, could a wrong implementation now pass? If not, delete it. Several rows differing only in a value that changes nothing are one example. A pile of near-identical rows often means two rules are mixed; separate them.

Pruning never removes the last Happy or Negative example of a rule, or the story's last Edge example.

## Examples without rules

A list of cases with no rule leaves the developer to infer it. Group every example under the rule it shows; one that fits none exposes a missing rule or a question.
