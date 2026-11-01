# Desired Outcomes and Ranking — Reference

Self-contained reference for the `jtbd-analysis` skill. Read it before writing desired-outcome statements or ranking anything. Sources: Anthony Ulwick's Outcome-Driven Innovation (job map, outcome syntax, the opportunity algorithm, segmenting by unmet outcomes), as summarised in the research file on *Competing Against Luck*; Dan Olsen, *The Lean Product Playbook* (the importance-versus-satisfaction framing, the segment caveat); Teresa Torres, *Continuous Discovery Habits* (compare-and-contrast decisions). No figures from these books are quoted; the numbers below are example data.

---

## 1. The rule: rank outcomes within a job, never whole jobs

A job is the stable thing you design for; it is not "more or less served". What is under- or over-served is the set of **desired outcomes**: the customer's own success measures for getting the job done. Ulwick's opportunity algorithm is defined on outcomes. A row like this is a category error:

| Job | Importance | Satisfaction | Opportunity |
|---|---|---|---|
| J-1 Collect overdue payments without damaging the relationship | 9 | 3 | 15 ✗ |

The fix is to decompose J-1 into outcomes and rank those (§2–§4). The Core Jobs section of the artifact carries no score column; where a summary is wanted, it names the job's **highest-opportunity outcome**.

---

## 2. Desired-outcome statements

```
[direction] + [metric] + [object of control] + [contextual clarifier]
```

- **Direction**: minimize or increase (almost always minimize: time, likelihood, effort).
- **Metric**: time, likelihood, number, effort.
- **Object of control**: the thing whose state the customer cares about.
- **Clarifier**: the circumstance.

| Good | Weak, and why |
|---|---|
| Minimize the time it takes to prepare the week's payment reminders | "Faster reminders": no metric, no object |
| Minimize the likelihood that a reminder reaches a client who has already paid | "Accurate data": a product quality, not the customer's measure |
| Minimize the likelihood that a client the partner manages personally is chased without the partner knowing | "Partner approval workflow": a solution |
| Minimize the time it takes to confirm that a newly connected source is fully classified | "Classification dashboard": a solution |

Outcomes are solution-free like the job statement. Gather them from snapshots: every "the hardest part was…", "I had to check…", "we got burned when…" in a story is an outcome in disguise.

**How many.** Standard: three to eight outcomes per core job, the ones the evidence actually surfaced. Enterprise: outcomes per step of the job map (§3). Full ODI often finds on the order of a hundred per job, from a survey programme this plugin's products rarely have; do not pad to look thorough.

---

## 3. The job map (enterprise)

Ulwick's universal eight steps structure the outcomes so none of the job is skipped:

| Step | Question for the job | Example outcome (data-estate job) |
|---|---|---|
| 1. Define | What must be planned or decided first? | Minimize the time it takes to decide which systems are in scope for this audit |
| 2. Locate | What inputs must be gathered? | Minimize the likelihood that a storage location is missed from the inventory |
| 3. Prepare | What must be set up? | Minimize the effort to connect a new source without a change request |
| 4. Confirm | What must be checked before execution? | Minimize the time it takes to confirm that a newly connected source is fully classified |
| 5. Execute | The core of the job | Minimize the likelihood that regulated data is misclassified as non-regulated |
| 6. Monitor | What must be watched while it runs? | Minimize the time between a new regulated file appearing and someone knowing |
| 7. Modify | What must be adjusted? | Minimize the effort to correct a wrong classification so it stays corrected |
| 8. Conclude | What finishes the job? | Minimize the time it takes to hand an auditor evidence they accept |

At standard, skip the map; write the outcomes the snapshots surfaced and note which step each belongs to if it helps.

---

## 4. Choosing the ranking method by sample size

### 4.1 A handful of design partners: compare and contrast (default)

At three to five design partners there is no average to speak of: one polite rating moves the result. Torres's alternative is to stop making **"whether or not" decisions** (should we do X?) and make **compare-and-contrast** decisions (which of these siblings is best?). Compare the outcomes **under one job**, side by side, through a few lenses:

| Lens | Question | Evidence |
|---|---|---|
| Sizing | How many of the participants raised it, and how often does it bite? | Count of snapshots naming it; frequency in the stories |
| Customer importance | How much did it hurt when it went wrong? | The strength of the specific event (lost client, audit finding, an evening lost) |
| How badly it is served | What do they do today, and does it work? | What gets fired; workarounds described |
| Market factors | Is it table stakes, or would serving it set the product apart? | `competitive-analysis` |
| Company factors | Does it fit the strategy kernel and what the team is good at? | `strategy-kernel` |

Pick one **target outcome** per job and record the reasoning in a sentence. The choice is reversible: the next snapshots can change it. If the user collected 1–10 ratings in those conversations, they may appear in the table, labelled **directional (n = 5)**, never as an ODI result, and never as the only reason for the ranking.

Example (Ledgerline, J-1, five design partners):

| Outcome | Sizing | Importance (strongest event) | Served today | Rank |
|---|---|---|---|---|
| O-1.2 Minimize the likelihood a reminder reaches a client who has already paid | 4 of 5 | DP-4: an apology call to a long-standing client | Badly: payments land in the bank feed a day before the spreadsheet | **1 (target)** |
| O-1.1 Minimize the time to prepare the week's reminders | 5 of 5 | Friday evenings lost, but no client harm | Poorly: hand-written | 2 |
| O-1.3 Minimize the likelihood a partner's own client is chased without the partner knowing | 2 of 5 | DP-2: a partner's angry call | Adequately: she asks the partners by email | 3 |

### 4.2 A sample that supports a survey: the opportunity score

When a survey reaches enough respondents **in each segment** for an average to mean something (dozens, not a handful), score each outcome:

- **Importance**: how important is this outcome to you? (1–10)
- **Satisfaction**: how satisfied are you with how well it is met today? (1–10)

```
Opportunity = Importance + max(Importance − Satisfaction, 0)
```

| Reading | Meaning |
|---|---|
| High importance, low satisfaction | **Underserved**: the opportunity |
| High importance, high satisfaction | Well served; table stakes, not a differentiator |
| Low importance, high satisfaction | **Overserved**: a place to simplify or charge less |
| Low importance | Low opportunity whatever the satisfaction |

Use the mean of each rating per segment. The script `../scripts/check-jtbd-analysis.py` recomputes every score row in the artifact.

### 4.3 Rank per segment: the blended-average trap

Olsen's caveat: needs and satisfaction differ by segment, and a blended average hides it. Ulwick goes further and segments the market **by unmet outcomes**, not by demographics. Example (enterprise data-estate platform, illustrative survey; banks n = 61, SMB n = 151):

| Outcome | Banks (I / S → Opp) | SMB (I / S → Opp) | Blended, weighted by n (I / S → Opp) |
|---|---|---|---|
| Minimize the time to confirm a new source is fully classified | 9.1 / 3.2 → **15.0** | 5.0 / 4.6 → 5.4 | 6.2 / 4.2 → 8.2 |
| Minimize the time to answer a customer security questionnaire with evidence | 4.8 / 6.0 → 4.8 | 8.6 / 2.9 → **14.3** | 7.5 / 3.8 → 11.2 |

Blended, the banks' top outcome drops to 8.2 and ranks below the SMB one, because SMB respondents outnumber banks; per segment, each is its own segment's top opportunity. Which one to pursue first is a segment decision for the strategy, not something the blended number can settle. Always rank per segment (per tenant type, at enterprise) and say which segment each target serves.

---

## 5. What the ranking feeds

- The target outcome per job feeds `impact-mapping` (which behaviour change to pursue) and `moscow-prioritization` (needs scored per persona and segment, not pooled).
- Ranked outcomes per segment feed the Value Proposition Canvas in `business-model-canvas`, which cites them by ID and never re-ranks them.
- Overserved outcomes are inputs to `gtm-strategy` packaging: something a cheaper tier can leave out.
