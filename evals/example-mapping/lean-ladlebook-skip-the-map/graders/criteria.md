---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It still produces an example map for US-4 despite the lean profile, and says that a small product gets one too: it shows the story, rules, examples under those rules, and open questions.
2. Each rule shown has at least one example with specific data (such as a named student, a price, a date or a number of hours before the class) and a stated outcome; an example that only restates its rule does not count.
3. It does not drop edge cases: it includes at least one boundary or unusual example, such as a cancellation at exactly 48 hours or one minute inside it, and does not limit the map to two happy examples.
4. It records at least one behaviour the request leaves undecided (for example how long a waiting-list offer lasts, what an empty waiting list means, or what happens if the cook cancels the class) as an open question for the product owner, and does not present its own answer as decided. A proposed answer is fine if clearly marked as an assumption or suggestion awaiting confirmation.
5. It does not mark the story ready to build while questions that affect its behaviour remain open; it says what must be answered first. Saying which parts are already clear does not fail this.
6. It states that the map was drafted by the agent from the product owner's statements, with assumptions labelled or separated from what was given; it does not claim that a workshop or a discussion between several people took place.
Fail if any of the 6 is missing.
