# Mom-Test Question Design for Feedback and Interviews — Full Reference

Reference material for the `feedback-template` skill. Holds the Mom Test principles applied to feedback elicitation, the good-vs-bad question pairs, the compliments/fluff/ideas taxonomy with catch-and-redirect scripts, the advancement/commitment discipline, and the technique for separating a stated request from the real underlying job. The three-rule summary lives in the skill body; this file is loaded when actually designing check-in questions or interpreting raw feedback.

Grounded in Rob Fitzpatrick's *The Mom Test*. The technique is stage- and market-agnostic and applies without modification to this repo's B2B, per-tenant-isolated, compliance-focused first product and its two personas — the **Data Steward** and the **Compliance Officer**. It matters most for `gtm-strategy`'s Stage 1 closed beta: a group of 3–5 pre-selected design partners who already like the product and helped shape it is the single highest-risk place for politeness to masquerade as validation, and at n=3–5 there is no large-sample averaging to dilute one badly-elicited answer.

---

## Why the Discipline Exists

People are reflexively nice, and "good" data is easy to mistake for "nice" data. "This is a great idea," "I'd definitely use that," "you should totally build this" are not signals of anything except that the person did not want the conversation to feel awkward. They are *dangerous* precisely because they are emotionally satisfying to hear — they feel like exactly the validation the team is hoping for, so they reinforce the team's confirmation bias while carrying zero predictive information about whether the person will ever adopt, pay for, or change behavior around the product.

The Mom Test is named for the fact that even your own mother — who loves you — will tell you your idea is good if you ask her badly, because a badly-framed question is really "please tell me my idea is good," not a question about her life. A question either passes all three rules or it produces false-positive data.

---

## The Three Rules

1. **Talk about their life, not your idea.** The conversation is about the participant's world and their actual work, never a pitch or a request to validate the product. The moment you describe the feature — "leading the witness" / pitching — the participant learns what answer would please you and will often supply it. This is a controls-for-bias discipline structurally identical to a blinded study: you cannot get an unbiased read once the subject knows the hoped-for answer. Delay describing the product for as long as possible; treat the urge to explain "here's what we built" as a signal the conversation has stopped being about them.

2. **Ask about specifics in the past, not generics or opinions about the future.** Ranked from best to worst: "what did you do the *last time* this happened" (specific past instance) > "what do you *usually* do" (generic habit) > "what *would* you do if" (future hypothetical). A question answerable only by describing a real, already-happened event cannot be satisfied by an optimistic guess. Questions about a future decision — "would you buy this?", "how much would you pay?", "do you think this is a good idea?" — ask the person to simulate a decision under conditions (no real money, no switching cost, no competing priority) that make the answer unfalsifiable and reliably over-optimistic.

3. **Talk less, listen more.** The facilitator's job is to extract facts, not to explain, defend, or sell. Ask what happened before asking what they think about it. Silence after a question is not a failure — let the participant finish before prompting. When they volunteer a complaint, ask "what would you have expected instead?" rather than proposing a fix; proposing one anchors their answer, and the fix is this plugin's job.

**Keep it casual.** A conversation billed as a formal "meeting to get feedback on our product" primes diplomacy and politeness — the exact posture the Mom Test avoids. Frame it around their world instead: "I'm trying to understand how compliance teams like yours handle audit prep today." This sets expectations before the first real question is asked.

---

## Good-vs-Bad Question Pairs

| Instead of asking… | Ask… | Why |
|---|---|---|
| "The gap report was easy to read, right?" | "Walk me through what you did when you opened the gap report." | The first invites agreement; the second surfaces actual behavior |
| "Did you notice the new classification badge?" | "What did you notice about how assets are shown on the dashboard?" | The first fishes for a specific answer; the second is open |
| "Was the scan fast enough for you?" | "Tell me about the last time you waited on a scan — what were you doing while it ran?" | The first invites a yes/no that hides real friction; the second surfaces the actual experience |
| "You'd want an export button here, wouldn't you?" | "If you needed to share this with your auditor, what would you do next?" | The first plants the answer; the second reveals the real gap or the workaround they already use |
| "Would you use a lineage-tracking feature?" | "What's the last time you needed to trace where an asset's data came from — what did you actually do?" | Converts a future hypothetical into a specific past instance |
| "How much would you pay for automated classification?" | "What are you spending today to keep classifications current, and where does that budget come from?" | A specific, present-tense version of the pricing question |

**The rewrite rule:** replace every "would you…" / "do you think…" / "how much would you pay…" in a check-in guide with its past-tense, specific-instance equivalent *before* the conversation, not after diagnosing the answer as useless.

**Ask the question you're afraid to hear.** If there is a question you are avoiding because you suspect the honest answer deflates the roadmap — "Is this actually a priority for you this quarter?", "What have you budgeted for solving this?", "Who has to approve a purchase like this?" — that avoidance is itself the signal that you already suspect bad news, and it is exactly the question you most need to ask.

---

## The Three Types of Bad Data

Fitzpatrick's taxonomy of responses that feel like validation but carry no predictive signal. Each has a distinct signature and a distinct fix.

| Type | Signature | Fix |
|---|---|---|
| **Compliments** | "I love it," "that's really cool," "nice work" — praise offered to be polite, unconnected to any behavior | Do not fish for them. When one lands, deflect it into a real question rather than logging it as data |
| **Fluff** | "I usually…", "I always…", "I'd definitely…" — generic or future-tense claims phrased as fact but describing an imagined average or future, not one real event | Press for a specific instance: "When's the last time that actually happened?" |
| **Ideas** | "You should build a dashboard for this" — an unsolicited feature/solution suggestion | Do not log verbatim as a requirement. Dig for the motivating problem behind it |

**Catch-and-redirect scripts:**

- Compliment lands: "Glad it's resonating — can you walk me through the last time this specific problem came up for you?" (converts applause into a specific-instance answer).
- Idea lands: "What's the problem you're picturing that dashboard solving?" — record the underlying problem statement, not the proposed solution.

The **ideas** fix is the same discipline as the skill body's "separate the stated request from the real job," and it is what fills the **Underlying need** field in the capture template (`references/feedback-capture-and-triage.md`). It feeds `jtbd-analysis` a real job rather than a solution-shaped one: a customer's proposed feature is evidence of a pain they are trying to solve, never a validated spec. Logging the raw request as a requirement is exactly the contamination `jtbd-analysis`'s "solution-shaped jobs" anti-pattern exists to catch — but catching it at the moment of capture prevents the bad data from entering the pipeline at all, rather than filtering it out downstream.

---

## Separating a Stated Request from the Real Job

A worked interpretation, from stated request to underlying job:

| A design partner says… | Do not record… | Record the underlying job… |
|---|---|---|
| "You should add a bulk-export button." | "Feature: bulk-export button" | "When an auditor asks for evidence, the Compliance Officer needs to hand over many assets' classifications at once, not one at a time." |
| "Can the dashboard have a dark mode?" | "Feature: dark mode" | "The Data Steward reviews the catalog for long stretches and the current contrast causes eye strain." (probe: is this a real, specific pain, or a compliment-adjacent nice-to-have?) |
| "I wish it integrated with our ticketing system." | "Feature: ticketing integration" | "When a Restricted asset is found, the Compliance Officer currently re-keys it into a separate ticketing tool by hand." |

The right-hand column is what a triage step can interpret, a `jtbd-analysis` step can turn into a job story, and a `product-strategist` roadmap decision can weigh. The left-hand column, logged raw, silently converts a customer's guess into a Must Have.

---

## Real Validation Is a Commitment, Not Enthusiasm

A conversation that ends in compliments has produced nothing measurable. A conversation that ends in **advancement** — a concrete, costly next step — has produced a self-interested signal that is much harder to fake out of politeness:

- a specific follow-up meeting placed on their calendar,
- a warm introduction to a named stakeholder (their boss, a peer team, a buyer),
- real access (a walkthrough of their current spreadsheet workaround, their audit-prep calendar for a pilot),
- a deposit or a signed pilot with a defined start date.

Always be asking for some form of advancement by the end of a substantive check-in. Treat a conversation that produces neither useful facts nor an advancement as inconclusive — it taught you very little, however pleasant it felt. Advancement is the commitment counterpart to a positive signal in the feedback log: a positive signal is retained evidence that a flow works; an advancement is evidence that the partner will actually keep showing up.

---

## Choosing Who to Talk To

Not every willing conversation is equally valuable. Favor participants who visibly, urgently have the problem — evidenced by prior self-funded effort to solve it themselves: a spreadsheet, a manual classification workaround, a consultant engaged, a competing tool trialled. Prior effort is itself a Mom-Test-compliant data point (a specific past action) and is far more predictive than a stated opinion that the problem "sounds important." For this repo, `user-persona`'s "Current approach" and "Trigger" attributes are exactly this kind of past-facing evidence, and `gtm-strategy`'s Stage 1 design partners are already selected for having helped shape requirements — so screen the *quality of their evidence*, not just their role-title fit.

---

## Verbatim Question vs. Analyst's Synthesis Question

A subtle but load-bearing distinction: the same phrasing can be sound as the analyst's *own* internal synthesis prompt and unsound as a question asked *out loud to a real customer*. `jtbd-analysis`'s core-job prompts — "What would change for them if this product didn't exist?", "If the product disappeared tomorrow, what would they do instead?" — are perfectly good as the requirements-analyst's own reasoning once real conversation data is in hand. But asked literally to a Compliance Officer in a check-in, they are exactly the counterfactual/hypothetical shape Rule 2 flags: the person can only speculate.

The rule: when eliciting raw input directly from a person, use the past-tense, specific-instance form —

| Analyst's synthesis question (internal) | Verbatim check-in question (to the person) |
|---|---|
| "What would they do if the product disappeared?" | "Before you started using this, what did you actually do the last time you needed it?" |
| "What progress are they trying to make?" | "Walk me through the last audit you prepared for — what took the most time?" |
| "What is their current approach?" | "Show me the spreadsheet you use for this today — how did the last entry get in there?" |

Keep the synthesis phrasing for your own write-up; never let it become the words spoken to the participant.

---

## Two Sequential Safeguards, Not One

The Mom Test and `jtbd-analysis`'s "Backwards JTBD" anti-pattern are **sequential safeguards, not the same safeguard** — do not treat fixing one as having addressed the other:

- **Mom Test discipline** is an *in-the-moment* question technique. It prevents contaminated data from being *collected* in the first place — a compliment or a hypothetical answer never enters the record.
- **Backwards JTBD** is a *post-hoc integrity check on the written-up analysis*. It catches a job story that was reverse-engineered to justify an already-decided feature — a contaminated *conclusion*, after collection.

One guards the input; the other guards the output. A feedback process needs both: clean elicitation upstream, and a conclusion check downstream.

---

## A Worked Check-In Guide (Stage 1 Design Partner)

A short, Mom-Test-compliant guide for a `beta-program-design` check-in with a Compliance Officer, in order — casual framing first, the scary question included, an advancement ask at the end:

1. *(framing, not a question)* "I'm just trying to understand how your team handles audit prep right now — no demo today, I mostly want to hear about your world."
2. "Walk me through the last audit you had to get ready for. Where did it start?"
3. "What was the most annoying part of pulling that together?"
4. "The last time an asset turned out to be misclassified — what actually happened, and what did you do about it?"
5. "What have you already tried to make this easier? Why didn't that stick?"
6. *(the scary one)* "Is fixing this actually a priority for you this quarter, or is it a someday thing? What's ahead of it?"
7. *(advancement)* "Could we grab 30 minutes next week for me to watch you run through a real classification review? And is there anyone else on your side I should be hearing from?"

Note that nothing in this guide describes the product's features. Every question can be answered by describing something that already happened, the priority question is asked outright rather than avoided, and the conversation ends on a concrete next step rather than a compliment.

---

## Quick Reference — Failure Modes to Catch in Yourself

| Failure mode | What it looks like | The tell |
|---|---|---|
| Pitching before probing | Opening with "so here's what we built…" | The participant's next answer is shaped around pleasing you |
| Fishing for compliments | "Pretty slick, right?" | You feel good after the call but wrote down nothing you can act on |
| Accepting fluff as fact | "I always export these weekly" logged as a requirement | No specific instance was ever named |
| Logging ideas as specs | A feature request copied straight into the backlog | The **Underlying need** field is empty |
| Skipping the scary question | Priority, budget, and approval never come up across a whole batch | Every partner sounds enthusiastic and none has committed anything |
| Ending on applause | The call closes with "this is great, keep me posted" | There is no advancement — no next meeting, intro, or access |

At this repo's n=3–5 closed-beta scale, any one of these failures corrupts a full third-to-fifth of the evidence base, with no large-sample averaging to dilute it — which is why the discipline is stricter here, not looser, than it would be in a high-traffic consumer product with hundreds of respondents.
