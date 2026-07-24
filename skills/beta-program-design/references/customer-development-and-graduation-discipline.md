# Customer Development and Graduation Discipline

Deeper content behind three of `SKILL.md`'s pointers: the concrete screening technique behind the Participant Selection table's two Blank-derived rows, the diagnostic framework for choosing extend/remediate/pivot, and two process checks — outside-the-building and sign-off repeatability — that keep this skill's evidence honest. Grounded in `research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md` (Steve Blank's Customer Development methodology).

## Earlyvangelist Screening Checklist

Blank's **earlyvangelist** is a more demanding, more precisely checkable replacement for a generic "early adopter" — four conditions, screened against a specific named candidate, not inferred from a psychographic type:

1. **Already-recognized pain.** The candidate already understands they have this problem — it doesn't need to be explained or sold to them.
2. **Prior self-funded effort.** The candidate has already spent their own time, money, or organizational capital trying to solve the problem themselves — a manual workaround, a spreadsheet, a hired consultant, an internally-built stopgap. This is direct, concrete evidence the pain is real rather than merely acknowledged. Record what they were already doing before the product existed as part of the participant record, not just their ICP-fit rationale — a named fact, not an impression.
3. **Budget, or access to it.** The candidate has (or can obtain) the authority or resources to actually adopt a solution, not just enthusiasm for the idea.
4. **Reference-credible.** The candidate is visible or credible enough within their own organization or market to serve as a reference once they've adopted the product — this is the criterion behind the Participant Selection table's "credible reference for stage-expansion" row.

All four conditions are procedural and checkable against a specific named person — a screening test a requirements-analyst can actually run, not a personality profile to guess at.

**Distinct from Moore's early adopter, not a restatement of it.** `research/product-strategy-and-gtm/crossing-the-chasm-moore.md`'s early adopter ("visionary") is defined *psychographically* — someone who wants a revolutionary strategic advantage and will tolerate being first, defined by what they want and how much risk they'll accept. Blank's earlyvangelist is defined *procedurally* — four checkable facts about a named candidate, independent of their psychological motivation. In practice the two populations overlap heavily, but they answer different questions: Moore's framework decides *which market segment* to attack first (the beachhead — `gtm-strategy`'s job); Blank's framework screens *which specific named person* within an already-chosen segment is actually a good beta/design-partner candidate — this skill's Participant Selection job specifically.

## Pivot Decision Framework

When a stage fails its graduation bar, name which hypothesis is suspect *before* deciding whether to extend, remediate, or pivot:

| Suspect hypothesis | What's actually wrong | Correct response |
|---|---|---|
| **Segment** | The participant profile itself doesn't fit — even a representative-seeming design partner turns out not to match the real ICP | Pivot: revisit Participant Selection, recruit a different cohort |
| **Problem** | The participants don't actually have the pain the program assumed they had | Pivot: revisit the problem hypothesis this release slice was built to solve |
| **Solution** | The pain is real, but this particular release doesn't solve it | Pivot: revisit the solution design, not just this beta stage's execution |
| **Process** | The product and problem-fit are both sound, but the sales/onboarding roadmap doesn't repeat across participants | Pivot on process, or — if the underlying hypothesis is otherwise confirmed — remediate the specific onboarding gap and extend |

"Extend" and "remediate" both assume the underlying hypothesis is sound and simply needs more time, more participant coverage, or a scoped fix. "Pivot" is the correct response only when the evidence gathered so far actually points at one specific hypothesis being wrong — not a verdict on the program's failure, and not a reason to simply repeat the same test with more effort. A stage that keeps extending against evidence that already points at a wrong hypothesis is buying time it cannot use productively.

## Outside-the-Building Check

Before declaring a stage's qualitative graduation bar met, run this explicit check: was the "usable for its intended purpose" affirmation obtained by asking the named participant contact to describe specific, observed behavior and friction — past-tense, specific-instance, in the style `feedback-template`'s own anti-leading-question guidance already requires for structured check-ins — or was it an internal team consensus, a demo the team ran and liked, or a leading question the participant politely agreed with?

Blank's discipline underneath this check: no fact about a customer exists until it has been tested against that customer's real behavior outside the team's own head. A qualitative bar met by internal conviction rather than externally observed behavior has not actually been tested outside the building, regardless of how confidently it's recorded in the graduation record. This is the same underlying discipline the Mom Test operationalizes at the level of a single conversation — Blank names the organizational-process-level version (a team can collectively fool itself as easily as one person can be led by a compliment); the anti-leading-question guidance in `feedback-template` supplies the conversational mechanics for not fooling yourself once you're actually having the conversation.

## Repeatability Check for Sign-Off Evidence

When compiling closed-beta evidence for `acceptance-sign-off`, add a check distinct from the per-participant usability affirmation: did onboarding this participant use the same documented steps as the previous one, with the same effort and support level — or did each participant require bespoke, founder-led hand-holding?

This matters because Blank's actual Customer Validation test is not "does the product work for these customers" — it is repeatability: proving a documented, repeatable process converts a *new* prospect, using people other than the one who built the relationship, before real money is spent scaling demand generation. Three participants who each affirm "yes, it works" after three different ad hoc onboarding paths is Customer-Discovery-grade evidence (confirms product/problem fit) — it is not yet Customer-Validation-grade evidence (a repeatable process). A closed beta that only re-confirms design partners like the product, without checking whether the process that got them there would work identically for a fourth participant nobody has hand-held, has not actually completed this stage's real test.
