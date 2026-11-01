# Outcomes and Opportunities — the Root and the Opportunity Space

Self-contained reference for the `opportunity-solution-tree` skill. Read §1 before writing the root, §2–§3 before placing any opportunity, and §4 before proposing a target opportunity.

Sources: Teresa Torres, *Continuous Discovery Habits* (outcome typology, the tree, opportunity framing, experience maps, compare-and-contrast prioritisation); Gojko Adzic, *Impact Mapping* (carrying a goal's measurement fields, zone of control vs sphere of influence); Clayton Christensen et al., *Competing Against Luck*, with Ulwick's Outcome-Driven Innovation (jobs and desired-outcome statements, kept distinct from opportunities). No page numbers, quotations or statistics from these books are given; quoted phrases below are illustrative customer lines.

---

## 1. The root: one desired outcome, and what kind it is

### 1.1 Three kinds of metric (Torres)

| Kind | What it measures | Who moves it | How fast it responds | Example |
|---|---|---|---|---|
| **Business outcome** | The business's progress | Many teams, the market, pricing, sales | Lags by months | Monthly recurring revenue; 12-month logo retention; cost to serve |
| **Product outcome** | A change in what customers **do** in the product that the team believes drives a business outcome | This team, directly | Weeks | Share of new studios that publish a class schedule in their first week; share of cancelled class spots re-filled |
| **Traction metric** | Use of one specific feature | Whoever ships the feature | Days | Number of clicks on the export button; weekly users of the waitlist screen |

Torres recommends giving a team a **product outcome**. It is close enough to steer by and far enough from any one feature to leave the solution open. She also treats the outcome as **negotiated** between leader and team, not handed down. In this plugin that negotiation happens in `okr-authoring`; this skill only checks what came out of it.

### 1.2 Reclassifying a Key Result

| The KR as written | Kind | What to put at the root |
|---|---|---|
| "Grow MRR from $40k to $60k" | Business outcome | Ask: which customer behaviour do we believe drives MRR? E.g. "Raise the share of trial studios that take their first paid booking within 14 days from 18% to 30%". Record the belief linking the two as an assumption (`viability`) |
| "Reduce churn to 3% a month" | Business outcome | E.g. "Raise the share of active accounts that run at least one weekly report from 40% to 60%", if the snapshots show churned customers stopped doing so |
| "40% of users use the new calendar sync" | Traction metric | Ask what calendar sync was for. If it was "patients stop missing appointments", root the tree at "Raise attended appointments as a share of booked from 82% to 90%" and put calendar sync back as one candidate solution |
| "Ship the onboarding redesign by Q3" | An output, not a metric | Send it back to `okr-authoring`: it is an initiative |
| "Find out which activation behaviour predicts paid conversion" | A **learning goal** | Allowed at the root while the right product outcome is unknown; the tree's first tests are about the metric itself. Restate it as a performance goal once found |

If the KR is a business outcome and **nobody can say which product outcome drives it**, do not guess one silently. Present two or three candidate product outcomes, each with the evidence for it, and ask the user to choose (and the OKR owner to confirm).

### 1.3 Carrying the measurement

Copy from the linked KR, field by field (Adzic borrows this discipline from Tom Gilb): **metric** (what is measured), **meter** (how it is measured), **baseline**, **target**, **deadline**, and an optional **constraint** (a level that must not fall). If the KR lacks a field, write `not set in KR` and flag it; never invent a number.

### 1.4 Why a product outcome fits Adzic's picture too

Adzic and Evans separate a team's **zone of control** (what it ships) from its **sphere of influence** (how people behave). A traction metric sits almost inside the zone of control: ship the feature, push its usage. A business outcome sits far out, beyond the sphere of influence. A product outcome sits in the sphere of influence: the team can make it more likely but cannot guarantee it, which is exactly what discovery is for.

### 1.5 Name clash: desired outcome vs desired-outcome statement

| Term | Owner | What it is | Example |
|---|---|---|---|
| **Desired outcome** (Torres) | This skill | The tree's root: a product metric for the team | "Raise re-filled cancelled spots from 20% to 50%" |
| **Desired-outcome statement** (Ulwick) | `jtbd-analysis` | A customer's success measure within one job: direction + metric + object + clarifier | "Minimize the time it takes to fill a cancelled spot before the class starts" |

A desired-outcome statement can tell you that an opportunity matters (customer factors, §4). It never replaces the root, and a tree whose root reads "Minimize the time it takes to…" has confused the two.

---

## 2. Framing opportunities

### 2.1 What an opportunity is

A customer **need, pain point or desire**, written from the customer's point of view, that **more than one solution could address**. Torres keeps the opportunity space and the solution space strictly apart: the tree's value comes from choosing among opportunities before choosing among solutions.

| Neighbouring idea | How it differs |
|---|---|
| **Job** (Christensen; job statement in `jtbd-analysis`) | Higher and stable: the progress sought. Opportunities are the specific needs and pains met while doing the job. A job statement can head a branch; it is not itself a leaf |
| **Desired-outcome statement** (Ulwick) | A measurable success criterion within a job. Can evidence how important an opportunity is |
| **Impact** (`impact-mapping`) | An actor's behaviour change that moves the goal. The opportunity explains **why** the actor does not already behave that way |
| **Feature request** | A solution. Recover the need behind it |

### 2.2 Rewriting solutions in disguise

Apply the test "could more than one solution address it?". If not, ask what the request is for and move up one level.

| Heard | Problem | Opportunity |
|---|---|---|
| "I wish there was a Slack integration" | One solution | "I miss booking requests when I'm not at my desk" |
| "Add a dashboard" | One solution | "I can't tell at a glance which classes are under-filled this week" |
| "Text reminders please" | One solution | "Patients forget appointments booked weeks ahead" |
| "It should be faster" | Vague, no moment | "Confirming tomorrow's list takes my whole lunch break" |
| "Better reporting" | A category, not a need | Split into the specific moments the reports were wanted for |

Keep the rewritten line in the customer's words where possible, and keep the original request in the evidence column: it is still evidence.

### 2.3 Customer's voice

Write "I…" or "We…" lines a customer could have said, taken from snapshots' **opportunities heard** and feedback items' **underlying need**. Avoid team language ("users lack visibility into fill rate"): it hides whose need it is and drifts toward a solution.

---

## 3. Structuring the space

### 3.1 The top level: steps of the experience

Torres recommends drawing an **experience map**: the steps of the customer's experience as the team currently understands it, drawn before interviews fill it in. Its steps become the tree's top-level branches. In this plugin, snapshots tag each opportunity with the experience step it belongs to (`jtbd-analysis` interview snapshot), so the steps usually already exist; the agent lists them in order and checks them with the user.

Example (a class-booking app for a small pottery studio): *Discover a class → Book → Prepare → Attend → Cancel or miss → Rebook*.

A job statement or the steps of the job map (`jtbd-analysis`) may also head the branches when the experience is the job's process. Whether Torres herself frames the top level as jobs is not something the research file confirms, so call it this plugin's option, not her rule.

### 3.2 Nesting

- A child is a more specific version of its parent: a narrower moment, a sub-group of customers, a cause.
- Each opportunity has **exactly one parent**. If it seems to fit two, it is usually two opportunities.
- Keep splitting until a node is small enough that a team could address it in a few weeks; that depth is where the target is chosen.
- IDs follow the nesting: `OPP-2` (a step), `OPP-2.1`, `OPP-2.1.3`.

### 3.3 Merging new evidence

Each new snapshot or feedback item:

1. Read its opportunities heard (or underlying need).
2. **If one matches an existing node**, add the citation and raise the independent-story count. Two mentions in one conversation are one story.
3. **If it is new**, place it under the right parent, or create a parent when several new ones cluster.
4. **If it contradicts** a node (the customer has no such pain), record that too: evidence against an opportunity matters as much as evidence for it.
5. Restructure when a pattern appears. Restructuring is a revision of the tree for the user to approve, not a silent edit.

### 3.4 Segments and tenant roles (enterprise)

Tag each opportunity with the segment or tenant role it was heard from. Two segments may share a step but not a need; a need heard only from enterprise shippers never borrows story counts from SMB carriers. Compare siblings within a segment, or say explicitly which segment the target serves.

---

## 4. Prioritising: compare and contrast, one level at a time

### 4.1 The rule

Torres warns against **whether-or-not** decisions ("should we work on X?") and favours **compare-and-contrast** decisions ("which of these is best for the outcome?"). For opportunities:

1. Compare the **top-level siblings** and choose one branch.
2. Within it, compare **its children** and choose one.
3. Repeat until the chosen node is small enough to work on: that is the **target opportunity**.

Never put every node in one ranked list: a parent and its own child are not alternatives, and a flat list hides the structure the tree exists to show.

### 4.2 The four lenses

| Lens | Question | Evidence to use |
|---|---|---|
| **Opportunity sizing** | How many customers does it affect, and how often? | Independent-story counts; frequency in the stories; feedback-log counts |
| **Market factors** | Is it table stakes (we lose without it) or a differentiator? | `competitive-analysis`, what gets fired (`jtbd-analysis`) |
| **Company factors** | Does it fit the strategy and our strengths? | Strategy kernel's guiding policy, the vision |
| **Customer factors** | How important is it to the customer, and how badly served today? | The strongest event in the stories; related desired-outcome statements |

The comparison is **qualitative**. At a handful of conversations any 1–5 rating is labelled "directional (n = k)". The exact four-lens list is the research file's best reconstruction of Torres; treat it as a working checklist, not a quotation.

### 4.3 Worked comparison (illustrative)

Outcome: raise re-filled cancelled class spots from 20% to 50% (pottery studio, five snapshots, eleven feedback items).

| Sibling (under OPP-5 "Cancel or miss") | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-5.1 "I find out a spot opened only if I happen to check" | 4 of 5 stories, weekly | Table stakes for bigger studios' apps | Fits "fill every wheel" policy | Strong: two missed spots they wanted | **Target** |
| OPP-5.2 "Cancelling feels awkward, so I just don't show up" | 2 of 5 | Not addressed by anyone | Fits | Medium: guilt, not loss | Next cycle |
| OPP-5.3 "I can't cancel late without losing my fee" | 1 of 5 | Policy, not product | Pricing decision | Low | Park; route to pricing |

**Target opportunity:** OPP-5.1, because it is the most-heard and best-evidenced, and serving it moves the outcome directly. Reversible: revisit after the first test.

### 4.4 A two-way door

Torres treats the choice as reversible and warns against over-analysis: the tree is revisited every cycle. State the reason in one or two sentences and move to solutions.
