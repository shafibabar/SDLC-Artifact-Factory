# JTBD Customer-Discovery Interviewing — Reference

The interviewing technique that surfaces **real** jobs rather than imagined ones. Grounded
in Rob Fitzpatrick's *The Mom Test* (customer-discovery question discipline), with
supporting screening criteria from Steve Blank's Customer Development (*The Four Steps to
the Epiphany* / *The Startup Owner's Manual*). Companion to
`references/job-statements-and-dimensions.md`, which covers what to record once you have
trustworthy data; this file covers **how to run the conversation that produces it**.

The problem this reference solves: a requirements-analyst can write a perfectly-formatted
job story about a job that no real customer actually has, or one whose "evidence" is a
design partner being polite. Both look identical to a valid analysis on the page. The Mom
Test is the discipline that keeps that contaminated data out of the input in the first
place.

---

## 1. The Mom Test — Three Rules

Named for the observation that even your own mother will lie to you (to protect your
feelings) if you ask her badly. "Do you think my app idea is good?" gets a yes from anyone
who likes you — it is really the question "please tell me my idea is good," not a question
about their life. A question is **Mom-Test-compliant** only if it passes all three rules:

| # | Rule | What it means in practice |
|---|---|---|
| 1 | **Talk about their life, not your idea** | The conversation is about the customer's world and problems, never a pitch or a request to validate yours |
| 2 | **Ask about specifics in the past, not generics or the future** | "What did you do the *last time*…" beats "what do you *usually* do" beats "what *would* you do if…" |
| 3 | **Talk less, listen more** | Your job is to extract facts, not to explain, defend, or sell |

A question that fails any one rule produces data that *feels* like validation but carries no
predictive signal. Run every planned question through the three-rule filter **before** the
conversation, and rewrite the ones that fail — don't diagnose them as bad afterward.

---

## 2. The Three Types of Bad Data: Compliments, Fluff, and Ideas

The core failure mode is not that customers lie maliciously — it is that ordinary politeness
generates false positives that feel exactly like product validation, and feel *emotionally
satisfying* to hear, which is precisely what makes them dangerous. Fitzpatrick names three
types of bad data — **compliments, fluff, and ideas** — each with a distinct signature and a
distinct fix.

| Bad-data type | Signature | Why it's worthless | The fix |
|---|---|---|---|
| **Compliments** | "I love it," "that's really cool," "nice work" | Praise offered to be polite; unconnected to any behaviour | Don't fish for them; deflect back to a real question: "Glad it resonates — walk me through the last time this problem actually came up" |
| **Fluff** | "I usually…", "I always…", "I would…" | Generic or future-tense claims describing an imagined average, not one real event | Press for a specific instance: "When's the last time that happened?" |
| **Ideas** | "You know what you should build…" | A proposed solution is evidence of a pain, not a validated spec | Receive it, then dig for the motivating problem: "What made you think of that — what's the problem you're picturing it solving?" |

The **ideas** fix is the direct upstream partner of this skill's "solution-shaped jobs"
anti-pattern: recording the underlying problem instead of the raw feature request stops the
data reaching the analysis already contaminated. An unsolicited "build me a dashboard"
logged verbatim as a requirement is how backwards JTBD begins.

---

## 3. Good Questions vs Bad Questions

Every good question can be answered by describing something that **already happened**. Every
bad question asks the person to simulate a future decision under conditions (no real money,
no switching cost, no competing priority) that make the answer unfalsifiable and reliably
over-optimistic.

| Bad question (rewrite it) | Mom-Test rewrite |
|---|---|
| "Would you use a tool that scanned your estate for compliance gaps?" | "Walk me through the last time you needed to know your compliance gaps — what did you actually do?" |
| "How much would you pay for this?" | "What are you spending today to deal with this, and where does that budget come from?" |
| "Do you think this is a good idea?" | "What have you already tried to solve this? Why didn't that work?" |
| "Would you find continuous monitoring valuable?" | "When was the last time something ungoverned surprised you? What happened next?" |
| "What features would you want?" | "What's the hardest part of your current compliance-prep process?" |

Canonical good follow-ups, reusable across conversations: "Talk me through the last time
that happened." · "What have you already tried?" · "Why didn't that work?" · "What else have
you tried?" · "Where does the money for that currently come from?" · "Who else should I be
talking to about this?"

---

## 4. Leading the Witness

The moment you describe your product, the dynamics change: the customer now knows what answer
would please you and (per §2) will often supply it. Delay or avoid describing the product for
as long as possible in a discovery conversation. Treat any early urge to explain "here's what
we're building" as a signal the conversation has stopped being about the customer's life and
become a pitch. This is not secrecy — it is a controls-for-bias discipline, structurally
identical to a blinded study: you cannot get an unbiased read once the subject knows the
hypothesis. Steve Blank names the organizational-scale version of the same discipline: **"get
out of the building"** — no fact about the customer is established until it has been tested
against a real customer's real behaviour, never internal-team consensus.

---

## 5. Ask the Questions You're Afraid to Hear

If there's a question you're avoiding because you fear the answer will deflate the idea —
"Is this actually a priority for you right now?", "What have you budgeted for solving this?",
"Who has to approve a purchase like this?" — that avoidance is itself a signal you already
suspect the honest answer is bad news, and it is precisely the question you most need to ask.
Before scheduling a conversation, write down the question you are most afraid to ask and make
sure it's on the list. If it never gets asked across a whole batch of conversations, treat
that omission as a finding in its own right.

Also keep the framing **casual**. A conversation billed as a formal "meeting to get feedback
on our product" primes diplomacy and politeness — the exact posture the Mom Test avoids. "I'm
trying to understand how teams like yours currently handle audit prep" produces more candid,
past-tense answers.

---

## 6. Validation Is a Commitment, Not Enthusiasm

A conversation that ends in compliments has produced nothing measurable. A conversation that
ends in a concrete, costly next step has produced a self-interested signal that is hard to
fake out of politeness. **Advancement** — not applause — is the unit of validation.

| Weak (applause) | Strong (advancement / commitment) |
|---|---|
| "This looks great, keep me posted" | A specific follow-up meeting on their calendar |
| "I'd definitely use this" | A warm introduction to their CISO or a peer team |
| "Very interesting" | Real access: a walkthrough of their current spreadsheet, a pilot with a start date, a deposit |

Always ask for some form of advancement by the end of a substantive conversation, scaled to
the stage. Treat a conversation that produces neither useful facts nor an advancement as
inconclusive — not as validation by omission.

---

## 7. Choosing Who to Talk To: Screening for Earlyvangelists

Not every willing conversation is equally valuable. Favour people who visibly, urgently have
the problem. Steve Blank's **earlyvangelist** test defines a qualified early customer by four
*checkable* conditions (not a psychographic type) — run it against a specific named candidate:

| # | Condition | How you check it |
|---|---|---|
| 1 | **Already recognises the problem as painful** | They describe the pain unprompted — you don't have to explain it to them |
| 2 | **Has already spent their own time/money trying to solve it** | A spreadsheet, a manual workaround, a consultant, a competing tool already in use |
| 3 | **Has, or can get, budget** | There is a real path to money, not just interest |
| 4 | **Is credible enough to be a reference** | Their eventual endorsement would de-risk the product for the next customer |

Condition 2 is the most predictive single signal: **prior self-funded effort** is itself a
Mom-Test-compliant data point (a specific past action) that beats any stated opinion about
how important the problem "sounds." Screen by evidence of prior effort, not by role-title fit
alone — role and company fit describe who *should* care; prior effort is evidence they
actually *do*. Record each design partner's existing workaround as a concrete selection fact.

---

## 8. The Interview Question Bank (this product)

Reusable opening set for a design-partner discovery conversation, all Mom-Test-compliant:

1. "Walk me through the last time you had to prepare for a compliance review or audit — what
   did you actually do, step by step?"
2. "What was the most painful or time-consuming part of that?"
3. "How do you know today which of your files hold personal or regulated data?" → "When did
   you last get that wrong, and what happened?"
4. "What have you already tried to make this easier? Why didn't it stick?"
5. "Where does the budget for compliance tooling or consultants currently come from?"
6. "The last time something ungoverned surprised you — a folder, a data leak, an audit
   finding — walk me through it."
7. (Afraid-to-ask) "Is fixing this actually a priority for you this quarter? Who signs off on
   spending to solve it?"
8. (Advancement) "Could I sit with you while you do your next compliance check?" / "Who else
   on your team should I talk to?"

---

## 9. How JTBD Output Feeds Downstream Skills

Trustworthy data gathered this way flows into two skills specifically:

**`user-persona`** — the persona's *goals* come from the core job; *primary frustration* from
the push force and the painful step in question 2; the persona's *trigger* ("what event makes
them start looking for a solution") from the specific-instance answer to question 6, **not**
from a hypothetical "what would make you look." Mom-Test discipline tightens the persona's
"groundedness" bar from "traceable to a research input" to "traceable to a research input a
compliment could not have produced."

**`user-story-writing`** — each job story's *implied capability* becomes the "so that" a user
story serves; the situation and outcome constrain the acceptance criteria so a story can't
drift into a feature nobody's job needs.

**Sequencing note.** Two safeguards operate at different times and neither replaces the other:
the Mom Test prevents bad data from being *collected* (in-the-moment question discipline); the
"backwards JTBD" anti-pattern catches bad *conclusions* after collection (a post-hoc integrity
check). Fixing one does not address the other — apply both.
