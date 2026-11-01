# Messaging and Launch — Reference

Self-contained. Read this when writing the Reframe and the message house, choosing proof points, tailoring messages to buying-group roles, setting launch-stage exit criteria, or deciding whether a win/loss outcome should reopen the positioning. Sources: Matthew Dixon and Brent Adamson, *The Challenger Sale*, and Adamson, Dixon et al., *The Challenger Customer* (reframe, unteaching, Mobilizers); Matthew Luhn, *The Best Story Wins* (the customer as hero); Karen Dietz and Lori Silverman, *Business Storytelling For Dummies* (customer stories as proof); Martina Lauchengco, *Loved* (message house, enablement, positioning refresh); Rob Fitzpatrick, *The Mom Test* (evidence from conversations); Steve Blank, *The Four Steps to the Epiphany* (plan vs execution).

---

## 1. The Reframe (Challenger)

Buyers arrive with a picture of their problem already formed, often from generic content or a competitor. Content that agrees with that picture changes nothing. *The Challenger Sale* calls the alternative **commercial teaching**: an insight about a cost, risk or opportunity the customer has underestimated, which leads naturally, but not obviously, to something only this supplier does well. *The Challenger Customer* adds **unteaching**: disrupt the existing mental model before teaching a new one.

Write one Reframe line **above** the message house. Test it:

| Test | Passes when |
|---|---|
| It is about the customer's world | It states something about their cost, risk or habit, not about the product |
| It is news to the ICP | A typical ICP buyer would not already say it unprompted |
| It leads to a unique strength | The strength it points at is one of the competitive analysis's real and valued differentiation points |
| No alternative could claim it | If a competitor or the spreadsheet could deliver the same answer, it is education, not a reframe |

The paraphrased sequence from *The Challenger Sale*: start from the customer's known challenges, reframe them, show the cost of the current way with evidence, make it personal to the role, describe a new way of working, and only then the product. In a self-serve product with no sales team, that sequence lives in the content, the trial's first screens and the docs, because that is where the buyer learns.

## 2. The message house (Lauchengco)

| Layer | Holds | Audience |
|---|---|---|
| Reframe | The insight that unteaches (above) | Every audience, first |
| Headline | Why to care, in 5–10 words | Everyone |
| Value proposition | 2–3 sentences: benefit and difference | Buyers and evaluators |
| Proof points | 3–5 claims, each verifiable today or by launch | Evaluators, security and finance reviewers |

**The customer is the hero (Luhn).** In the value proposition and the proof points, the customer is the protagonist with a want and an obstacle; the product is what helps them win. "Your office manager sees every overdue client the first afternoon" casts the customer; "Ledgerline's AI engine automates collections" casts the product. Luhn's logline discipline (protagonist, want, stakes in one sentence) applies to the headline and value proposition only; the ICP, channel, pricing and metric sections are decision tables, not stories.

**Proof-point types.**
- **Factual**: a measurable, checkable claim ("history imported the same day from the two most common bookkeeping tools"). "The best AR tool" is not a proof point.
- **Customer story** (Dietz and Silverman): a named customer, a specific before and after, a confirmed outcome. Allowed only once a real design partner or customer exists and has agreed to be named. Never invent an illustrative story; an invented story breaks the same honesty rule as an invented statistic.

**Tailor by role.** The buying group's roles weigh different things. Choose which proof points lead for each role, using what each reads and how each decides; do not serve one undifferentiated house. At enterprise scale this becomes a **consensus kit**: one page per buying-group role with its concern, the answer and the proof, so the Mobilizer can win colleagues over.

**Consistency.** The same committed claims appear on every revenue-facing surface (trial onboarding copy, README, FAQ, sales deck). Add 3–5 objection-handling responses keyed to the competitive analysis's alternatives ("why not just keep the spreadsheet?").

## 3. Positioning refresh trigger (Lauchengco)

Positioning is a living hypothesis. Re-examine the positioning statement and the message house:
- at every launch-stage transition (Stage 1 → 2, Stage 2 → 3), and
- whenever an outcome in the competitive analysis's **win/loss log** contradicts a differentiation point the positioning relies on.

The win/loss log lives in the `competitive-analysis` artifact; this trigger reads it and never keeps a second log. A loss to "the spreadsheet and a consultant" because the differentiator didn't land, or a no-decision outcome where the buying group never agreed on the problem, forces a refresh. A refresh may change the message only, the category, or the beachhead; a change to the beachhead or the advantage relied on is also evidence for the strategy kernel's review trigger.

## 4. Launch sequencing

| Stage | Goal | Audience | Typical length |
|---|---|---|---|
| 1. Closed beta / design partners | Validate ICP, core value, onboarding, WTP | 3–5 pre-selected ICP customers | 4–8 weeks |
| 2. Soft launch / limited availability | Validate the motion, the price and the message | ICP outreach, limited inbound, no broad announcement | 6–12 weeks |
| 3. General availability | Scale acquisition | Full channel activation | Ongoing |

Lengths are planning defaults, not rules; **exit criteria** decide when a stage ends.

**Stage 1 is a plan; the beta is its execution (Blank).** The GTM is written in Strategy, before any Customer Discovery-style work has run. Stage 1 is the plan for the closed beta that `beta-program-design` later runs in Customer Validation. Do not mistake the naming overlap for a sequencing defect, and do not duplicate the beta program's recruitment and feedback design here.

**Stage 1 exit criteria include:**
- ICP confirmed and core value delivered, **on Mom-Test evidence**: the conversations behind those claims were about the partners' own past behaviour and specifics, not their opinion of the pitch; and they ended in commitments (time, a reference, money, a signed pilot), not compliments. Five design partners saying "we'd definitely use this" confirms nothing. Fitzpatrick's warning is literal here: a small, warm, pre-selected group who helped shape the product is exactly who will be polite.
- Onboarding completed without hands-on help in the last deployments.
- A **WTP range per segment** recorded from the design-partner conversations, labelled stated or committed (see `./pricing.md`).
- The **Mobilizer hypothesis** confirmed or replaced in the design-partner accounts: who actually carried the decision. Beware the **Friend** (Challenger profile): accessible, enthusiastic, answers every email, and cannot move the organisation. Test with an insight: does this person ask what it means for the company and take it to colleagues?

**Stage 2 exit criteria include:** a repeatable acquisition motion (a new prospect converts through the same steps without founder heroics); price accepted inside the stated range without structural discounting; trials or deals lost to no decision counted, with the reason.

**Stage 3 entry** holds only when Stage 2's criteria hold over a sustained window the artifact states. GA is not the chasm test: run the chasm diagnostic in `./positioning-and-segments.md` before scaling to a new segment.

### Launch is also a three-audience process (Lauchengco)

Separate from the three market stages, every launch has three audiences, each with its own readiness gate:
1. **Internal**: can the differentiator be explained, unprompted, in one paragraph consistent with the message house?
2. **Revenue-facing** (sales, partners, the trial itself): do the approved proof points appear verbatim in onboarding copy, README and FAQ?
3. **External**: the market-facing announcement.

A launch can pass all three market stages and still fail because the trial flow was never equipped with the message.
