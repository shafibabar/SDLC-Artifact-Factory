# The Requirement Shell, Fit Criteria and the Baseline

Self-contained. This file covers how each requirement in a functional requirements document (FRD) is written: its fields, its fit criterion, its provisional priority, and what happens to it after approval. Read it before writing the first functional requirement, and whenever a fit criterion will not come.

## The shell

Suzanne and James Robertson's Volere method (*Mastering the Requirements Process*) gives every atomic requirement a fixed set of fields, the "snow card". Karl Wiegers and Joy Beatty (*Software Requirements*) list the characteristics each requirement must have: complete, correct, feasible, necessary, prioritised, unambiguous and verifiable. The FRD's shell combines them, scaled by profile.

| Field | Standard | Enterprise | Rule |
|---|---|---|---|
| ID | yes | yes | UR-n for user requirements; FR-n.m under UR-n; BR, CON, IF, DR, TR for the other types |
| Statement | yes | yes | One behaviour; user's or system's point of view, one style per document |
| Rationale | on the UR | on the UR, and on any FR whose reason differs | Why it exists: the impact and job story it serves |
| Traces to | on the UR | on the UR | Selected-path deliverable + job statement → job story (+ KR). With no impact map at standard: the KR + job story |
| Fit criterion | yes | yes | Below |
| Verify by | yes | yes | Acceptance test, integration test, usability test, review, inspection |
| Rules / NFRs | yes | yes | BR-n implemented; quality concern handed to `nfr-specification` |
| Priority (provisional) | high / medium / low | value, penalty (1–9) and the resulting high / medium / low | Below |
| Status | — | yes | proposed, approved, implemented, verified, deferred, rejected |
| Conflicts | when any | yes | Other requirement IDs it clashes with |

## Fit criteria

In Volere every requirement, functional ones included, gets a **fit criterion**: a measurable statement of what a solution must do to satisfy it, precise enough that a tester can say pass or fail. The Robertsons' test: if you cannot write one, the requirement is not yet understood. Do not put it in a requirements table with "pending" or "TBD" in its fit-criterion cell: keep it on the TBD list (the question, and the requirement it would become) until the answer arrives. The criterion comes from the rationale, so "quick" becomes "quick enough for what?".

A good functional fit criterion names:

1. **who or what** acts (a member, the nightly job, a clinic in a given state);
2. **the input or situation** (a reply of "C", a loan 15 days old, a file of 10,000 rows);
3. **the observable result** (status shows confirmed, the loan is refused with the reason, the import report lists every rejected row);
4. **how much or how many** (for all 50 seeded replies, for each of the five rule cases, zero orphaned records).

| Weak ("Test:") | Fit criterion |
|---|---|
| "Integration test: reminders work" | "For 100 seeded appointments booked 3+ days ahead, exactly one reminder is queued per appointment for 24 h before its start; cancelled appointments get none." |
| "User can export data" | "An owner exports the last 12 months of loans to CSV; the file's row count equals the loans shown on screen for that period, and every row has member, item, out and back dates." |
| "Usability test: easy to connect" | Not functional. Ease and time are quality attributes: hand "time to connect, unaided" to `nfr-specification`. The FR is "An admin can connect a source by granting read-only access, without contacting support", with fit criterion "the connection succeeds with read-only credentials and is refused, with the reason shown, for credentials that can write." |

**Fit criterion vs quality attribute.** A fit criterion may count things and name results. If it needs a response time, a throughput, an uptime or a satisfaction score to pass, the number belongs to a quality attribute. Write the FR's functional fit criterion and add the concern to the quality-attribute hand-off list ("FR-2.1: confirmation must register quickly enough for a patient replying on the bus"). `nfr-specification` turns it into a measurable target scaled to the profile.

**Fit criteria become acceptance criteria.** Later, `acceptance-criteria` turns each fit criterion into Given/When/Then scenarios for the stories that carry the FR. Wiegers and Beatty recommend writing a quick conceptual test from each high-priority requirement before review: if no test can be written, the requirement goes back for rework.

## The ambiguity sweep

Wiegers and Beatty list words that make a requirement ambiguous. Search every draft for them and replace each with a number and a condition, or move it to the TBD list:

> fast, quick, quickly, user-friendly, easy, intuitive, flexible, robust, seamless, support(s), minimise, maximise, efficient, as appropriate, as needed, etc., and/or, should, may, approximately, several, large, small.

"Should" and "may" leave it unclear whether the behaviour is required. Use "must" throughout and let the provisional priority carry importance.

## Provisional priority

Priority set in the FRD is **provisional**. `moscow-prioritization` runs last in Ideate and finalises it on the stories; the FRD never writes Must, Should, Could or Won't. Wiegers and Beatty treat prioritisation as repeated, not one-time: a rough ranking early, refined as cost and risk become clear.

- **Standard:** high / medium / low, from the traced source: how much the requirement moves the impact (value) and what happens without it (penalty, the Hathaways' necessity test as a number).
- **Enterprise:** score value and penalty 1–9 from the traced source; cost and risk are left blank until epics are sized. The high / medium / low label follows from value + penalty. Add the Volere satisfaction and dissatisfaction notes where design partners have said what they would think if it were missing.

Every priority cell reads "high (provisional)" or similar, and the document says once: "Priorities are provisional and are finalised by `moscow-prioritization`."

## The waiting room

Volere's **waiting room** is a named section for requirements found but not wanted now: preferences that failed the necessity test, deliverables that are options on the impact map, ideas for a later cycle. Each entry has a reason and, where relevant, the condition that would bring it back. Nothing found is silently dropped. MoSCoW's Won't list draws from it.

## TBD list

Wiegers and Beatty mark unknowns "TBD" rather than hiding them. Every TBD has an ID, the question, the requirement it blocks, who can answer it and by when. The FRD is not approved with a TBD blocking a high-priority requirement unless the user accepts that explicitly.

## Traceability

- **Backward** (standard and enterprise): each UR → its deliverable, job statement → job story, KR; each FR → its UR; each BR → its source. A traceability table lists the selected-path deliverables and job stories with the URs that serve them, so an uncovered one is visible.
- **Forward** (enterprise): FR → story → acceptance criteria → test. The columns exist from the start and are filled as later artifacts are written; the Quality phase audit reads them.

## Baseline and change control

When the user approves the FRD it becomes the **requirements baseline** for the release. The plugin's approve-and-reopen mechanism already works this way: editing an approved artifact sends it back to draft until it is approved again. A change after approval is a **change request**: the analyst writes an impact note (which URs, FRs, NFRs, stories, acceptance criteria and tests it touches) and the user decides. At enterprise the FRD carries a change log: version, date, change, reason, impact, decided by.

A change that challenges positioning or the ideal customer profile goes to product-strategist; any other new or changed requirement stays with requirements-analyst.
