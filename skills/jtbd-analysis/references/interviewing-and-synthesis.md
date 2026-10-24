# Interviewing and Synthesis — Reference

Self-contained reference for the `jtbd-analysis` skill. Read it before writing an interview guide or an interview snapshot, or when deciding whom to interview. Sources: Bob Moesta and Chris Spiek's switch interview, as described in the research on *Competing Against Luck*; Teresa Torres, *Continuous Discovery Habits* (story-based interviewing, the interview snapshot, recruiting and the weekly cadence, compare-and-contrast); Rob Fitzpatrick, *The Mom Test* (question discipline); Steve Blank, *The Four Steps to the Epiphany* (earlyvangelists, getting out of the building); Marty Cagan, *Inspired* (problem discovery vs solution discovery); Nikita Bier, *Unleash Your Creativity with AI* (adversarial reframing). Where the plugin adapts a practice to an agent that cannot interview, this file says so; the adaptation is the plugin's, not the author's.

---

## 1. Roles: the user interviews, the agent synthesises

| Step | Who | Output |
|---|---|---|
| Choose whom to talk to | The user, from the agent's screening criteria (§2) | A short recruit list |
| Write the guide | The agent | `ideate/interviews/guides/<yyyy-mm-dd>-<topic>.md` from `../templates/interview-guide.md` |
| Hold the conversation | **The user**, or a design-partner session the user runs. Never the agent | Raw notes (or a transcript) |
| Write the snapshot | The agent, from the user's notes, the same day if possible | `ideate/interviews/snapshots/<yyyy-mm-dd>-<participant>.md` from `../templates/interview-snapshot.md` |
| Revise the analysis | The agent, when snapshots change a job, force or ranking | A new version of `ideate/jtbd-analysis.md` for the user to approve |

Torres's product trio (product manager, designer, engineer) interviews and synthesises together. This plugin has one human and agents reset between phases, so the nearest practice is: the user holds the conversation, `requirements-analyst` writes the guide and the snapshot, and an engineering agent is asked for feasibility notes only when an assumption is tested. Every snapshot says it was synthesised from notes the agent did not witness.

**When nobody can be interviewed yet.** Write the analysis with every item `[assumption]` and a validation question per item. Ask the core-job question twice before settling on a job statement: once straight ("what progress is this person trying to make?") and once as a sceptical customer would answer ("what would someone who thinks this product is pointless say the job really is?"). Bier's point is that a model, unlike a human in an interview, has no ground truth to push back, so it tends to anchor on its first plausible answer. Questions the agent asks *itself* ("what would they do if the product disappeared?") are fine for that synthesis; they must never be asked verbatim to a customer (§4).

---

## 2. Whom to talk to

- **Recent switchers first.** For a switch interview, the best participant changed how they do the job recently enough to remember details: bought a tool, hired a consultant, built a spreadsheet, **or dropped a tool** (firing is as informative as hiring).
- **People who visibly have the problem.** Blank's **earlyvangelist** test, four checkable conditions about a named candidate: (1) already recognises the problem as painful, unprompted; (2) has already spent time or money trying to solve it (the most predictive single signal, since it is a past action); (3) has, or can get, budget; (4) is credible as a reference.
- **Non-consumers too.** Someone with the job who uses nothing explains the non-consumption market; ask about the last time the need turned urgent.
- **One segment at a time.** Recruit across segments and tenant roles on purpose; never let one segment's stories stand for another's.

"Get out of the building" (Blank): no fact about the customer is established until it has been tested against a real customer's behaviour. Team consensus is not evidence.

---

## 3. Two interview types

### 3.1 Story-based interview (Torres): for opportunities

Open with **one** prompt about a specific past instance, scoped to the part of the experience the current outcome touches:

- Broad: "Tell me about the last time you chased an overdue invoice, from the moment you noticed it."
- Narrow: "Tell me about the last reminder you sent that you wish you hadn't."

Then **excavate** the story: what happened first, then what, who else was involved, what was hardest, what did you do next. When the participant generalises ("I usually…"), redirect gently to the instance: "And that last time, what happened?" Interviews are for discovering needs, **not for testing solutions**: showing a concept turns the conversation back into an opinion poll (Torres; Cagan's split between discovering the problem and testing a solution).

### 3.2 Switch interview (Moesta and Spiek): for forces

Reconstruct the timeline of one recent switch, documentary-style. Stage names vary between Moesta's talks and books; these are the ones this plugin uses:

| Stage | Ask for | Feeds |
|---|---|---|
| **First thought** (the struggling moment) | When did you first think "there has to be a better way"? What had just happened, where were you, who was there? | Push; the job story's When |
| **Passive looking** | Before you went looking, what did you notice or hear about? | Pull |
| **Event** that started active looking | What happened that made you actually start looking? | Push; the trigger |
| **Active looking** | What did you look at, try, ask about? What did you rule out, and why? | Competitive set; anxiety |
| **Event** that made you decide | What made you decide then, not a month later? | Push, deadline |
| **Deciding** | What nearly stopped you? Who else had a say? What did you have to give up? | Anxiety, habit, trade-offs, the buyer's financial job |
| **Purchase / first use** | What happened the first day? When did you know it was working, or not? | Purchase and use experiences, Big Hire |
| **Ongoing use** (or firing) | What brings you back on an ordinary week? Or why did you stop? | Little Hire |

Probe every stage for **concrete details**: the day, the place, the people, what had just happened, what they tried first, how it felt. Fill the forces table only from what the participant actually described.

---

## 4. Question discipline (Fitzpatrick, *The Mom Test*)

Three rules; a question that breaks any of them produces data that feels like validation and predicts nothing:

1. **Talk about their life, not your idea.** No pitch, no "what do you think of…".
2. **Ask about specifics in the past, not generics or the future.** "What did you do last time" beats "what do you usually do", which beats "what would you do if".
3. **Talk less, listen more.**

| Bad question | Rewrite |
|---|---|
| "Would you use a tool that does X?" | "Walk me through the last time you needed X. What did you actually do?" |
| "How much would you pay for this?" | "What are you spending on this today, in time or money, and whose budget is it?" |
| "Do you think this is a good idea?" | "What have you already tried? Why didn't it stick?" |
| "What features would you want?" | "What was the hardest part of the last time?" |
| "What would you do if the tool disappeared?" | "Before you had it, what did you do? When did you last do it that way?" |

**Bad data to discard in the snapshot**, and what to record instead:

| Type | Signature | Record instead |
|---|---|---|
| Compliments | "Love it", "great idea" | Nothing; the conversation should have steered back to their life |
| Fluff | "I usually…", "I would…" | Only the specific instance, if it was recovered |
| Ideas | "You should build a dashboard" | The problem behind it: "what would the dashboard let you do?" |

**Ask the question you are afraid to hear** ("Is this a priority this quarter? Who signed off the last spend on it?") and put it in the guide. It obeys rule 2 like every other question: "if it went back to paper tomorrow, what would go wrong?" is a hypothetical; "when did paper last let you down?" is not. **End with a request for advancement**: another meeting, an introduction, a look at their real spreadsheet, a pilot date. A conversation that ends in compliments and no commitment is inconclusive, not validation. Keep the framing casual ("I'm trying to understand how firms like yours handle overdue invoices"), not "a meeting to get feedback on our product".

---

## 5. The interview snapshot

One page per conversation, written after it (Torres). The field list below is this plugin's version; Torres's own includes the participant, quick context facts, a memorable quote, the story as an experience-map sketch, the opportunities heard and insights that fit nowhere yet. This version adds the forces, what was fired, advancement and discarded bad data, so a snapshot feeds this skill directly.

| Field | Rule |
|---|---|
| ID, date, participant (pseudonymous ID), interviewer | The interviewer is a person (the user or a design partner), never the agent |
| Synthesised by | "requirements-analyst (AI), from the interviewer's notes; the agent did not witness the conversation" |
| Quick facts | Two to five facts that set context (segment, role, size, current tools) |
| Memorable quote | Only if it is verbatim in the notes; otherwise "none recorded" |
| The story | The specific instance, as a short timeline (switch stages, or the story's steps) |
| Forces heard | Push, pull, anxiety, habit, each from a described event; "not heard" is allowed |
| What was fired | What they used before, including nothing |
| Opportunities heard | Needs, pains and desires **in the customer's voice**, each answerable by more than one solution, tagged with the step of the experience it belongs to |
| Unplaced insights | What does not fit yet |
| Advancement | The commitment obtained, or "none" |
| Discarded | Compliments, fluff and ideas, with the problem recovered behind each idea |

The **opportunities heard** are written so a later opportunity-mapping step can place them with no rewording: customer voice, solution-free, tagged to a step.

---

## 6. The weekly loop, and why snapshots are separate files

Torres's continuous discovery is **weekly touchpoints with customers, by the team building the product, in pursuit of a desired outcome**. Her practical claim is that teams stop because recruiting is a chore, so **automate recruiting**: an in-product prompt asking customers for a short conversation, design partners who keep a standing slot, introductions from customer-facing colleagues. For a solo product owner this is a one-time setup task; put it on the beta or launch plan, not on willpower.

The plugin gates phases and sends an approved artifact back to draft whenever it is edited. Weekly interviews would therefore reopen the approved JTBD analysis every week if evidence were appended to it. So:

- **Each conversation is a new dated snapshot file.** Adding one creates a new evidence file and touches nothing approved.
- **The analysis cites snapshots by file name** (`[2026-10-14-dp-4]`) and is revised only when evidence changes a job, a force or a ranking. The revision is a deliberate new version for the user to approve.
- **Customer Validation feeds the same loop.** Beta and post-launch conversations produce snapshots too; `feedback-template` items with an underlying need are the same kind of evidence.
