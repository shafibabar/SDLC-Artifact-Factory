# Mom Test Question Design

The detail behind `SKILL.md` § 3–4: why the discipline exists, good-vs-bad question pairs, the three kinds of bad data with redirect scripts, commitment, and how a stated request becomes an underlying need. Grounded in Fitzpatrick (*The Mom Test*) and Torres (*Continuous Discovery Habits*). The examples use several products on purpose; nothing here belongs to one product.

## Why It Matters Most in a Small Beta

People are kind. "This is great", "I'd definitely use that" and "you should build this" mean only that the speaker did not want the conversation to feel awkward. They are dangerous because they are exactly what the team hopes to hear. Even your mother will say your idea is good if you ask badly, because a badly framed question really asks "please tell me my idea is good".

A closed beta is the easiest place to fool yourself: three to five warm, polite design partners who helped shape the product, and no large sample to dilute one badly asked question. The discipline is stricter there, not looser.

## The Three Rules

1. **Talk about their life, not your idea.** The moment you describe the feature, the participant learns which answer would please you, and often supplies it. Delay showing the product as long as possible. Torres makes the same point: showing a concept turns an interview into an opinion poll.
2. **Ask about specifics in the past.** Best to worst: "what did you do the last time this happened" (a specific instance) > "what do you usually do" (a generic habit) > "what would you do if" (a hypothetical). A question that can only be answered by describing a real event cannot be satisfied by an optimistic guess.
3. **Talk less, listen more.** Ask what happened before asking what they think. Let silence sit. When they complain, ask what they did next, not whether your fix would help; proposing a fix anchors the answer.

**Keep it casual.** "A meeting to get feedback on our product" primes politeness. "I'd like to hear how month-end went" invites facts.

## Story-Based Prompts (Torres)

Open with one story prompt, scoped to the part of the work the release touches, then excavate:

- "Tell me about the last time you [did the job]." — then "What happened first?", "Who else was involved?", "What was hardest?", "What did you do next?"
- When the answer drifts to "we usually…", bring it back: "Thinking of that last time specifically, what happened?"

The story, not the participant's summary of it, is what goes in a feedback item's Context field.

## Good-vs-Bad Question Pairs

| Instead of… | Ask… | Why |
|---|---|---|
| "The report was easy to read, right?" | "Walk me through what you did when you opened the report last week." | The first invites agreement; the second surfaces behaviour |
| "Did you notice the new status badge?" | "What did you notice on the order screen?" | The first fishes for one answer |
| "Was the sync fast enough?" | "Tell me about the last time you waited for a sync. What were you doing meanwhile?" | A yes/no hides real friction |
| "You'd want an export button here, wouldn't you?" | "When you last needed to share this with someone, what did you do?" | The first plants the answer; the second shows the real gap or workaround |
| "Would you use auto-scheduling for call-outs?" | "Tell me about the last emergency call-out. Who decided which crew went, and how?" | A hypothetical becomes a past instance |
| "How much would you pay for it?" | "What do you spend on this problem today, and whose budget is it?" | A present-tense version of the pricing question |
| "On a scale of 1–10, how happy are you?" | "What did you use it for this week, and where did you stop and do something else?" | A score is an opinion; the stop is a fact |

**Rewrite before the call:** every "would you…", "do you think…" and "how much would you pay…" becomes its past-tense or present-tense equivalent.

**Ask the question you would rather not.** "Is this a priority this quarter?", "What have you budgeted?", "Who approves this?" If you are avoiding a question because the honest answer might hurt, that is the question to ask.

## The Three Kinds of Bad Data

| Type | Sounds like | Fix |
|---|---|---|
| **Compliments** | "Love it", "really cool" | Don't fish for them. Deflect: "Glad it's working — when did you last use it, and what for?" Log nothing unless behaviour follows |
| **Fluff** | "I always…", "I'd definitely…" | Press for an instance: "When did that last happen?" |
| **Ideas** | "You should add a dashboard" | Dig for the problem: "What would the dashboard let you do that you can't now? When did you last need that?" |

A **positive signal** in the log is behaviour ("ran Saturday's orders through it; no spreadsheet"), never a compliment.

## From Stated Request to Underlying Need

Torres's **opportunity** is a customer need, pain or desire written from the customer's point of view, at a level where more than one solution could meet it. That is what the item's Underlying need field holds.

| They say… | Don't record… | Record the need (and the moment) |
|---|---|---|
| "Add a dashboard." | "Feature: dashboard" | "On Monday morning, I need to see which standing orders changed since last week without opening each one." (weekly planning) |
| "Can it integrate with our ticketing tool?" | "Feature: ticketing integration" | "When an issue is found, I re-key it into another tool by hand and sometimes forget." (hand-off) |
| "We need dark mode." | "Feature: dark mode" | Probe first: is there a real, recent pain (long review sessions, eye strain), or is it a compliment-adjacent nice-to-have? |

The right-hand column can be compared on `opportunity-solution-tree`, turned into a job story by `jtbd-analysis`, and prioritised. The left-hand column, logged raw, quietly turns a customer's guess into a Must.

## Commitment, Not Enthusiasm

A conversation that ends in compliments produced nothing measurable. One that ends in **advancement** produced a costly, self-interested signal:

- the next session on their calendar;
- an introduction to a named colleague, buyer or peer team;
- real access: their current spreadsheet, their data, a session watching them work;
- a deposit or a signed pilot with a start date.

Ask for one at the end of every check-in, and record the commitment, or its absence, in the log. A pleasant call with no facts and no advancement taught you little.

## Synthesis Questions Are Not Interview Questions

"What would they do if the product disappeared?" is a fine question for the analyst's own write-up. Asked aloud to a participant, it is a hypothetical. Ask instead: "Before you used this, what did you do the last time it came up?" Keep synthesis phrasing for the write-up.

## Two Safeguards, in Sequence

The Mom Test guards the **input**: contaminated data is never collected. `jtbd-analysis`'s "Backwards JTBD" check guards the **conclusion**: a job story reverse-engineered to justify a decided feature. Fixing one does not fix the other.

## Failure Modes to Catch in Yourself

| Failure | Looks like | The tell |
|---|---|---|
| Pitching before probing | Opening with "here's what we built" | Their answers bend toward pleasing you |
| Fishing for compliments | "Pretty slick, right?" | You feel good and wrote down nothing usable |
| Fluff as fact | "I always export weekly" logged as a requirement | No instance was named |
| Ideas as specs | A request copied into the backlog | The Underlying need field is empty |
| Skipping the scary question | Priority and budget never come up | Everyone is enthusiastic; nobody committed |
| Ending on applause | "This is great, keep me posted" | No next step |
