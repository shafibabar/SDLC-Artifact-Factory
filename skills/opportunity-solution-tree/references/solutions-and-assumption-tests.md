# Solutions and Assumption Tests

Self-contained reference for the `opportunity-solution-tree` skill. Read it once a target opportunity is chosen and before writing any solution, assumption or test.

Sources: Teresa Torres, *Continuous Discovery Habits* (several solutions per target, testing assumptions not ideas, the five assumption types, success criteria set before a test, comparative testing, measuring impact); David Bland's importance × evidence assumption map as credited by Torres; Gojko Adzic, *Impact Mapping* (non-software deliverables, selected path, assumption and signal per link, the re-plan trigger); Bier, *Unleash Your Creativity with AI* (a second, constrained generation pass so an AI does not anchor on its first idea). No page numbers, quotations or statistics from these books are given; numbers below are example thresholds.

---

## 1. Generating solutions

Solutions are generated **only for the target opportunity**. Generating for every node spreads effort across the whole tree and turns it back into a backlog.

1. **Many first.** Torres's point is that the first idea is rarely the best and that a team with one idea falls in love with it. She cites research suggesting people produce better ideas working alone before pooling them. This plugin has no group to pool, so the agent runs **two passes**:
   - Pass 1: the obvious solutions, as many as come.
   - Pass 2: under a constraint that forces range (Bier): "no new code", "one week", "only the studio owner's phone", "what would a competitor's opposite be".
2. **At least one non-software option** (Adzic): a process change, a message, a policy, a manual concierge version. It is often the cheapest test of the same assumption.
3. **Narrow to about three**, carried forward **together**. Every later test compares them. "Around three" is the research file's summary of Torres's practice, not a hard number; two or four is fine, one is not.
4. Park the rest in a list under the target. They are options, not rejects.

| ID | Solution | Kind | Carried forward? |
|---|---|---|---|
| SOL-1 | Waitlist that auto-offers a freed spot by text | software | yes |
| SOL-2 | Studio owner posts freed spots in the members' group chat | non-software | yes |
| SOL-3 | "Notify me" toggle on full classes, email only | software | yes |
| SOL-4 | Overbook by one | policy | parked |

---

## 2. Surfacing assumptions

Test **assumptions, not whole ideas**. Every solution rests on several; building the solution tests all of them at once, slowly and expensively. Surface them three ways (Torres):

- **Walk the tree's lines.** Why would this solution address this opportunity? Why would serving this opportunity move the outcome?
- **Story-map the solution.** List the steps a customer would take through it; at each, ask what must be true.
- **Pre-mortem.** It is six months later and the solution failed. Why?

### 2.1 The five types

| Type | Question | Example (SOL-1 waitlist auto-offer) |
|---|---|---|
| **Desirability** | Do they want it? | Members on a waitlist want a text when a spot frees up |
| **Viability** | Should the business do it? | Re-filled spots pay for the texting cost |
| **Feasibility** | Can we build it? | Cancellations reach the system early enough to offer the spot |
| **Usability** | Can they use it? | A member can accept in one reply before someone else does |
| **Ethical** | Could it do harm, and should it be done? | Texts at night or repeated offers feel like pressure; phone numbers are used only for this |

The first four match the risks Marty Cagan names in *Inspired*; Torres adds **ethical**. Look for at least one ethical assumption on every carried-forward solution: data use beyond what was agreed, pressure or dark patterns, unequal treatment of a group, surveillance.

### 2.2 Ranking: importance × evidence

Torres credits this map to David Bland. Place each assumption on two axes:

| | Little evidence | Strong evidence |
|---|---|---|
| **Important to success** | **Test first** | Monitor |
| **Less important** | Test later, if cheap | Ignore for now |

"Evidence" means something customers did, from snapshots, feedback or a past test, not the team's confidence. Test the top one or two per solution.

---

## 3. Designing a test

### 3.1 Success criteria first

Write the criterion **before** the test runs, with a number and a population: "at least 4 of 6 members on a waitlist accept an offered spot within 30 minutes". Then run it and record the result against that bar. A criterion written after the result can be bent to call anything a success.

| Weak | Strong |
|---|---|
| "See if people like it" | "At least 5 of 8 owners choose the reminder over the deposit when shown both" |
| "Check that it's fast enough" | "95% of cancellation events reach the queue within 60 s in the staging log over one week" |
| "Learn about ethics" | "No member of 10 interviewed says the texts felt like pressure; any one who does stops the test" |

### 3.2 Test forms, small to large

Start small and grow only as confidence grows. Torres's examples include one-question surveys, simulations and prototypes; the forms below are typical, not her exhaustive list.

| Form | Good for | Who runs it |
|---|---|---|
| Data look (existing logs, past bookings) | Feasibility, sizing | Agent, from data the user exports |
| One-question survey / in-product prompt | Desirability at volume | The user |
| Comparison test: show the three options, ask which they'd use for their last real instance | Desirability across the set | The user, in a conversation |
| Concierge / manual version (SOL-2 run by hand for two weeks) | Desirability, viability, usability | The user |
| Prototype walkthrough | Usability | The user with a customer |
| Spike | Feasibility | An engineering agent, on request |

The agent drafts the test and its criterion; **the user runs anything that involves a customer**. Feasibility spikes go to the owning engineering agent with the assumption stated exactly.

### 3.3 Compare across the set

Where one test can check the same assumption for all carried-forward solutions (a comparison test, a shared data look), prefer it. A test of one solution in isolation is a whether-or-not decision in disguise.

---

## 4. Recording results without reopening the tree

Each test is its own dated file, `ideate/assumption-tests/<yyyy-mm-dd>-<slug>.md`, from `../templates/assumption-test.md`. Its frontmatter fixes the criterion and the date it was set **before** the run date; the result is added when the test runs.

| Verdict | Meaning | What happens on the tree (at the next cycle's revision) |
|---|---|---|
| **Supported** | The result met the criterion | The assumption moves to "strong evidence"; test the next riskiest |
| **Not supported** | The result missed it | Change or drop the solution; if every solution fails the same desirability test, question the opportunity |
| **Inconclusive** | Too few results, or the test was flawed | Redesign; never reinterpret as supported |

At enterprise, each tree lists its tests in a tracking table (assumption, criterion, file, verdict), refreshed when the tree is revised for the next cycle.

---

## 5. Closing the loop after launch

Shipping is not the end. After the chosen solution ships, check whether the **product outcome** moved, not only whether the feature is used (Torres moves teams from measuring activity to measuring impact). Adzic adds the **re-plan trigger**: write down, before shipping, what would send the team back to the tree:

- the solution is used but the opportunity's pain persists in new snapshots → the solution was wrong; try another carried-forward solution;
- the opportunity is resolved but the outcome does not move → the opportunity-to-outcome link was wrong; choose another branch;
- both move → close the opportunity and pick the next target.

Customer Validation evidence (`feedback-template` items, beta check-ins) is what feeds this. A feedback item asking for a missing capability is placed on the tree as an opportunity and compared, not scheduled directly.
