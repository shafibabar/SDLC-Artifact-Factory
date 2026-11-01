# OKR Rules and Grading

Self-contained reference for `okr-authoring`. Read it when you need the detailed tests for an Objective or a Key Result, when setting baselines, and when grading a cycle. Sources: grading, cadence, committed vs aspirational and alignment follow John Doerr's *Measure What Matters* and Christina Wodtke's *Radical Focus* (both summarised in `research/product-strategy-and-gtm/measure-what-matters-doerr.md`); the proximate and one-policy tests follow Richard Rumelt's *Good Strategy / Bad Strategy*; the outcome-only Key Result rule is Marty Cagan's (*Inspired*); the metric tests are Croll and Yoskovitz's (*Lean Analytics*). These are practitioner books, so treat their numbers (0.7, three to five Objectives, quarterly) as calibrated defaults, not findings.

---

## 1. Objective tests

| Test | Pass | Fail |
|---|---|---|
| **Qualitative** | No numbers in it | "Reach 500 users" |
| **Proximate** (Rumelt) | Reachable this cycle with the means at hand; the team knows what to do next | Blue-sky end state: "become the trusted leader" |
| **From the guiding policy** | Traces to a proximate objective the strategy kernel hands on | Invented; or each Objective serves a different policy (dog's dinner) |
| **Not business as usual** (Google) | Would not happen without the OKR | Describes work already under way ("keep the lights on") |
| **Passes "who cares?"** (Google) | Someone outside the team would notice it succeeding | Internal housekeeping |
| **A real choice** | Another direction was genuinely possible (Rumelt: strategy requires choice) | Inevitable work, written down |
| **Labelled** | Committed or aspirational | No type |

Stretch belongs in Key Result targets. The Objective itself is a feasible next position.

---

## 2. Key Result tests

| Test | What it means | Rejected → repaired |
|---|---|---|
| **Outcome, not output** (Cagan) | Measures a behaviour change, never a delivery | "Ship the importer" → "Share of trial firms that see their own overdue clients on day one rises from 10% to 50%" |
| **Measurable, with a number** (Doerr) | A Key Result with no number is not a Key Result | "Improve onboarding" → "Median setup time below 30 min" |
| **Comparative** (Lean Analytics) | Read against a baseline, period or cohort | A bare total with no "from" |
| **A ratio or rate** (Lean Analytics) | A denominator resists gaming | "Signups: 400" → "Trial-to-paid conversion from 8% to 14%" |
| **Understandable** (Lean Analytics) | A non-analyst can remember it and argue about it | A composite score only its author can compute |
| **Changes what you do** (Lean Analytics) | A different value would change a decision | A vanity count that only ever goes up |
| **Independently verifiable** | Read from data, not self-assessment | "The team feels it went well" |
| **Owned** | Exactly one accountable owner | Unowned |
| **Paired** (Grove) | A volume or speed KR has a quality counter-KR or a health metric beside it | "Reminders sent" pushed up while complaints rise unseen |

**The outcome test, as one question:** if the team delivered exactly what the KR names but nothing changed for the customer or the business, could the KR still be marked complete? If yes, it is an output. Rewrite it as the behaviour change it was meant to cause; the original wording becomes an Initiative. Doerr and Grove allowed milestone KRs; the plugin does not, following Cagan, and credits the rule to him.

**Hypothesis framing.** LeMay's "strong opinions, loosely held" stance treats every bet as something evidence could disprove; Rumelt treats the strategy itself the same way. The template's line "We believe [Initiative] will move [KR], and we will know when [signal]" is this plugin's phrasing of that stance, not a quotation.

**North Star vs One Metric That Matters.** The North Star Metric comes from the vision and stays fixed across cycles. Croll and Yoskovitz's One Metric That Matters rotates as the biggest open risk changes. Do not merge them; an OKR set uses the first and may focus a cycle on something like the second.

---

## 3. The honest-baseline rule

1. **Measure, don't guess.** Take the baseline from telemetry, analytics or a prior period. If it cannot exist yet, write `n/a (pre-launch)`; never invent a number.
2. **Live but not yet measured.** If the product is live and the metric simply has not been read yet, write `not yet measured — first reading by <date>` (a date before the first check-in), mark the target provisional, and confirm it once the reading lands. Never leave a bare placeholder, and never guess. Prefer a KR whose baseline already exists when one measures the same change.
3. **A pre-launch target is a first hypothesis.** Grade it honestly; a low grade is calibration data for next cycle.
4. **Never move a baseline mid-cycle** to flatter a grade. Correct a wrong baseline openly in the check-in log.
5. **State the direction** (↑ or ↓) so the grade is unambiguous.

---

## 4. Committed vs aspirational

| | Committed | Aspirational |
|---|---|---|
| Expected grade | 1.0 | About 0.6–0.7 on average across the set |
| Starting confidence | ≥ 90% | About 50% (Wodtke: 5 out of 10) |
| Typical | Certification, contractual delivery date, regulatory deadline, a promise to customers | Adoption, retention, behaviour change not achieved before |
| A grade below target | A failure: write what happened and a recovery plan with a date | Normal; read it for learning |
| Grade consistently 1.0 | As expected | The targets were timid (sandbagging) |

Certifications, contractual deliverables and compliance deadlines are **committed by default**. A pass/fail KR is usually a committed KR without the label: grade it 1.0 if achieved and 0.0 if not, no credit for effort. Where a "binary" hides a spectrum ("3 of 3 design partners live"), express it as a fraction instead.

Google's guidance also names **insufficient KRs for a committed Objective** as a mistake: if all the KRs of a committed Objective could land without the Objective being delivered, add the missing KR.

**Confidence is not the grade.** Confidence is the weekly forecast of hitting the target in full; the grade is the end-of-cycle measurement. A KR at 50% confidence is not "expected to grade 0.5": an aspirational target is set beyond the likely result, so partial progress usually grades well above 0.5.

---

## 5. Grading on 0.0–1.0

Each KR is graded at cycle end from 0.0 to 1.0; the Objective's grade is the average of its KRs (weights, if any, fixed before the cycle starts).

| Band | Meaning for an aspirational KR | Meaning for a committed KR |
|---|---|---|
| 0.7–1.0 green | Delivered; 0.7 is a win | Only 1.0 is delivered; 0.7–0.9 is a miss to explain |
| 0.4–0.6 yellow | Real progress, short of target; the most informative band | A miss: explanation and recovery plan |
| 0.0–0.3 red | The assumption behind the KR was probably wrong | A serious miss: escalate to the user |

**Interpolation (this plugin's convention, not Doerr's).** Doerr presents grading as quick and judgement-based. For a continuous KR the plugin computes `grade = (final − baseline) / (target − baseline)`, clamped to 0.0–1.0, so two sessions grade the same KR the same way. Use judgement only where the metric has no baseline.

**Grading honestly as a solo product owner.** Doerr keeps OKR grades out of pay and ratings, because people lowball targets that feed rewards. A solo product owner has no bonus to game; the risk is self-flattery. Grade from the numbers before rereading the narrative, and write the "what we learned" line before discussing the grade.

---

## 6. Cadence and the check-in

| Rhythm | What happens |
|---|---|
| **Annual (optional, standard and enterprise)** | One or two annual Objectives give the quarterly sets their context and give the roadmap's Next/Later columns something to link to |
| **Quarterly (set)** | Write the set: Objectives from the kernel, typed; KRs with baselines, targets and starting confidence; health metrics; candidate Initiatives |
| **Weekly (check-in)** | Wodtke's four-square: this week's priorities, each KR's confidence, the next few weeks, health metrics green / yellow / red. For a solo product owner, one dated log entry in the artifact: one line per KR (confidence and a note) plus any health metric not green |
| **Quarter-end (grade and retro)** | Grade each KR, average per Objective, record the explanation and recovery plan for any committed miss, one learning line per Objective; revise the kernel first if its review trigger fired |

**Keep KRs fixed; let Initiatives move.** Change a KR mid-cycle only when a foundational assumption breaks, and record why in the log. Doerr allows an OKR to be updated or dropped when it stops making sense; that is a logged decision, not a quiet edit.

---

## 7. Alignment, not cascade

- **Alignment** (Doerr): higher-level OKRs are visible; each team writes its own Objectives and KRs and names the higher Objective each advances. Teams also align **sideways**: list the other teams a KR depends on, and confirm they hold a matching KR or Initiative.
- **Cascade** (to avoid): every level copies and narrows the level above. The tell is a team KR that is the parent's KR with a smaller number. It cannot fail independently and teaches the team nothing about its own lever.
- A large share of team OKRs should come from the teams themselves; Doerr suggests roughly half (treat the figure as approximate).
- **Solo product owner:** product and company OKRs are one set. Say so once in the artifact.

---

## 8. Failure modes

| Failure | Tell | Fix |
|---|---|---|
| Goals as strategy | No kernel above the set | Write the kernel first |
| Dog's dinner | Objectives with no common policy, even three or fewer | Keep only those the one policy implies |
| Blue-sky Objective | An end state with no next step | Next proximate objective |
| Business as usual | Work that would happen anyway | Make it a health metric |
| "Who cares?" | Nobody outside the team would notice | Rewrite around a customer change, or drop |
| Unlabelled type | Committed promise graded like a stretch | Label; grade committed against 1.0 |
| Insufficient KRs (committed) | KRs could all land without the Objective | Add the missing KR |
| Timid aspirational | Aspirational grades cluster at 1.0 | Raise targets; start confidence near 50% |
| Fantasy | Grades cluster near 0.0 | Anchor to a baseline and a plausible Initiative |
| Output KR / roadmap as OKRs | "Launch X", feature-and-date list | Outcome to move; demote to an Initiative |
| Vanity KR | Rises whatever happens | Ratio or rate that changes a decision |
| Missing baseline | Target with no "from" | Measure it, or `n/a (pre-launch)` |
| Cascade | Copied parent KRs | Align by reference |
| Too many OKRs | More than the profile allows | Cut to the Scale table |
| Set and forgotten | No check-in entries after week one | Weekly log |
