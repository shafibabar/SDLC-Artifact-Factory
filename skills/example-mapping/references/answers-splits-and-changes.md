# Answers, Splits and Changes

Used after an example map exists: rules `R1`, examples `R1.E1`, questions `Q-1` (open, answered, moved), verdict Ready or Not ready.

## Asking

Put each question as one decision: the question, a concrete case that depends on it, why it matters and your recommendation. Send them together, grouped by story, at the point the phase plan's approval mode allows. A question that changes the scope of a Must Have story is raised at once.

## Folding an answer back

1. Only the product owner's reply to that question counts. "Yes, your recommendation" is a reply. Silence, a general "carry on" or an advance permission is not.
2. Set the row to `answered`; write the answer, "product owner" and the date. Keep the row.
3. Change every `assumption (Q-n)` or `unknown (Q-n)` that depended on it: new source `product owner, yyyy-mm-dd (Q-n)`, and a real outcome. If the answer rejects the assumption, rewrite or delete the rule and its examples.
4. Probe the answer: it often creates a new limit or a new question.
5. Update the split check, readiness, `summary` and `version`; validate again.

A partial or ambiguous reply leaves the question open with a sharper wording.

## Splitting and moving

Signals: six or more rules (a rule of thumb), several open questions, rules that serve different users or tenant policies, or one hard case holding the simple one back.

Propose the split with the rules each child takes. Story splitting patterns belong to `user-story-writing`; the usual ones from a map (Cohn): by business-rule variation, by data boundary, simple case before complex, or a spike when nobody can say what is involved. Each child must be a thin slice of user value.

On agreement:
- the new story goes through `user-story-writing` with the next free ID, and gets its own map;
- here, delete the moved rules and examples and set the question to `moved`, naming the new story, "product owner" and the date;
- a question moves only with its case: if this story's behaviour still depends on the answer, it stays open.

A spike's output is a decision. The question stays open until the product owner answers it using that decision.

## Changing an approved map

An agreed example changes only through the same discussion that created it (Pugh). When new information arrives, or the built behaviour differs:

1. Treat the difference as a question, never as a silent correction to match the code.
2. Record the product owner's answer, update the map, bump `version`. Editing an approved artifact returns it to draft until re-approved.
3. Tell `acceptance-criteria` which rules changed, so the criteria drawn from them are revised, and then any feature files.

## Handing off

The next step reads the map by its path, `ideate/example-maps/US-n.md`, and its rule and example IDs. Rule and example IDs are not reused after deletion.

## A session with people

If the product owner wants one: one story at a time, the same four cards, concrete examples rather than rule debates, and disagreements recorded as questions instead of settled by the loudest voice (Adzic's specification workshop is the library's nearest source). Record who took part. A specification leaves the session when it is in business language, each example shows one rule, and those present agree it.
