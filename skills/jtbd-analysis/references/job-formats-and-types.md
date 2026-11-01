# Job Formats, Job Types and the Job Spec — Reference

Self-contained reference for the `jtbd-analysis` skill. Read it when writing a job statement or a job story, choosing which JTBD school's tool to use, classifying a job, or filling the job spec. Sources: Christensen, Hall, Dillon and Duncan, *Competing Against Luck* (the definition, hire and fire, the job spec, Big and Little Hire, non-consumption); Anthony Ulwick's Outcome-Driven Innovation (the job statement, job types, executor / beneficiary / buyer); Alan Klement, *When Coffee and Kale Compete*, and Intercom (the job story); Bob Moesta and Chris Spiek (the forces of progress); Dan Olsen, *The Lean Product Playbook* (problem space vs solution space). No page numbers or quotations are given; none should be added without the books in hand.

---

## 1. What a job is

A job is **the progress a person is trying to make in a particular circumstance**. Three words carry the weight:

- **Progress**: movement toward a goal, not a task.
- **Circumstance**: who, where, when and "while doing what" at the moment the need arises. Christensen's argument is that the circumstance, not the customer's attributes, causes the purchase. Attributes (age, company size, job title) correlate with purchases; they do not explain them.
- **Hire / fire**: choosing a solution always displaces something. The competitive set is defined by the job, not by the product category.

Three properties make jobs useful:

1. **Stable while solutions churn.** "Be ready to show an auditor where regulated data lives" was a job before software and will outlive this product.
2. **Solution-agnostic.** If the statement names a button, a screen or the product, it is a task or a feature.
3. **Never only functional.** Every job has emotional and social dimensions (§5).

### The altitude test

Ask: *would this job have existed fifty years ago, in some form?* A real job passes. Then ask: *could one button satisfy it?* If yes, it is a task inside a job, so climb one level by asking what the task is *for*.

| Statement | Altitude | Fix |
|---|---|---|
| "Export a CSV of flagged files" | Task | What is the export for? → "assemble evidence an auditor will accept" |
| "Use the reminder queue" | Feature | → "collect overdue client payments without damaging the relationship" |
| "Be a better firm" | Too high: no circumstance, no object | → name the object and the clarifier |

---

## 2. The job statement (Ulwick)

```
[verb] [object of the verb] [contextual clarifier]
```

One line, present tense, solution-free, stable over time. It is the **anchor**: every job story, force and outcome in the artifact sits under one job statement.

| Good | Why |
|---|---|
| Collect overdue client payments without damaging the client relationship | Verb + object + clarifier; no product; true in 1975 |
| Send the office's lunch order complete and on time without chasing anyone | Same shape; the clarifier carries the emotional charge |
| Keep a provably complete record of where regulated data lives across the organisation's systems | Same shape at enterprise |

| Weak | Failure |
|---|---|
| Use an AI tool to chase invoices | Names a solution |
| When an invoice is overdue, I want to… | That is a job story, not a job statement |
| Manage receivables | No clarifier: which circumstance? |

The persona carries this one line (`user-persona`). This artifact refines it, and the persona is updated if the refinement changes it.

---

## 3. The job story (Klement / Intercom)

```
When [situation], I want to [motivation], so I can [expected outcome].
```

The format came out of Intercom (Paul Adams's team); Alan Klement became its best-known advocate and refined it. It replaces the user story's persona-led "As a…" with a situation-led "When…", because the same person has different jobs in different situations.

| Clause | Holds | Test |
|---|---|---|
| **When** | A real triggering situation | A moment in the person's life or work, never "when I use the app" |
| **I want to** | The motivation | Intent, not a UI action or product output; more than one solution could satisfy it |
| **so I can** | The expected outcome | The person's progress, not the product's benefit |

**One story per situation, under one job statement.** Cover the situations that matter: usually the **trigger** (the struggling moment that starts the search), the **routine** case and the **high-stakes** case where failure costs most. More stories only where a situation changes the design.

**The motivation-leakage check.** Rewrite any motivation that names a product output:

| Leaky | Rewritten |
|---|---|
| I want to see a current, prioritised list of compliance gaps | I want to know which gaps could fail the review before the reviewer finds them |
| I want an automatic reminder sent | I want the client to be reminded before the debt sours, without me writing it |
| I want a dashboard of who ordered | I want to know who still hasn't chosen before the cut-off |

The first column is solution space; the second is problem space (Olsen's split). Only the second survives a different solution.

**One motivation per story.** "Scan, classify and report…" fuses three motivations into one blurred capability. Split.

**Job story vs user story.** A job story says why and when; a user story says what the product does, for which persona (`user-story-writing`). Job stories come first and every user story traces to one.

---

## 4. The schools, and which tool to use when

| School | Unit of analysis | Core artifact | Best when | Weak when |
|---|---|---|---|---|
| Christensen / Moesta | The circumstance and the switch | Job spec, forces table, switch timeline | Finding *why* people switch and what really competes; early discovery, non-consumption | You need a ranked, quantified backlog |
| Ulwick (ODI) | Measurable outcomes along a job's process | Job statement, job map, desired-outcome statements, opportunity scores | A known job, enough customers to survey, many improvements to choose between | Few customers; new-category or emotional-progress jobs |
| Klement / Intercom | The situation that triggers a motivation | Job stories | Carrying a job into design and backlog input that stays situation-led | Used alone: drifts to feature-level stories with no anchoring job |

They are layers, not rivals, and this skill uses them in order: the **switch interview** finds which job and which forces matter; the **job statement** names the stable job and its **outcomes** measure it; **job stories** carry its situations into design. The schools disagree publicly about what a job *is* (Ulwick: a functional process to measure; Klement: progress toward a better self). This skill takes no side in that dispute and credits each technique to the person most associated with it.

---

## 5. Job types and the people around a job (Ulwick)

| Job type | Definition | Design implication |
|---|---|---|
| **Core functional job** | The main progress sought | Solve it exceptionally well first |
| **Related job** | An adjacent job the same executor does | Expansion, later |
| **Emotional job: personal** | How the executor wants to feel, or avoid feeling | A dimension of the core job, not a backlog item |
| **Emotional job: social** | How the executor wants to be seen | Likewise |
| **Consumption-chain job** | Buy, install, set up, learn, maintain, upgrade, dispose of the product itself | **Onboarding requirements**; usually under-designed |
| **Financial job of the purchase decision-maker** | What the buyer must justify: cost, risk, return | Pricing, trial and proof; feeds `gtm-strategy` |

| Role | Who | Example |
|---|---|---|
| **Job executor** | Does the job | The office manager working the overdue list |
| **Job beneficiary** | The job is done for them | The managing partner who wants cash in; an auditor who receives evidence |
| **Buyer** | Pays | The managing partner; a bank's CISO team |

When executor and buyer differ, write the buyer's **financial job** as its own job statement. The personas are the same people (`user-persona` primary and customer types); the job says why each of them hires.

### The three dimensions

| Dimension | Question | Example |
|---|---|---|
| **Functional** | What practical progress? | Get the week's reminders out |
| **Emotional** | What feeling sought or avoided? | Never be surprised by something sent in the firm's name |
| **Social** | How do they want to be seen? | The person who keeps cash flowing |

A product that serves only the functional dimension competes on price. Where the emotional or social dimension decides the purchase (fear of an audit finding, standing with the board), say so.

---

## 6. The job spec: obstacles and experiences

*Competing Against Luck* describes a job fully as a **job spec**: the dimensions, plus the **obstacles** in the way of progress, what the customer must **give up** to switch, and the **experiences of buying and using** a product that would satisfy it. The book argues winning products **integrate around the job**: they deliver the right experience at each point of purchase and use, sometimes through things that are not the core product.

| Job spec element | Question | Becomes |
|---|---|---|
| Obstacles | What stops progress today? | Requirements and onboarding steps |
| Trade-offs | What must they give up to switch (data, habit, a relationship)? | Migration and import requirements |
| Purchase experience | What must buying feel like (a trial on their own data, a security review passed)? | Trial and procurement requirements |
| Use experience | What must first use and the ordinary Tuesday feel like? | Time-to-first-value and Little Hire requirements |

---

## 7. Hire and fire, Big Hire and Little Hire, non-consumption

**What gets fired.** For each core job, list what the customer used before: nothing, a manual workaround, a spreadsheet, a consultant, an adjacent tool, a bundled feature they switched off. Hand that list to `competitive-analysis` and `gtm-strategy`; it is the real competitive set, and it should match the competitive alternatives `competitive-analysis` lists (JTBD explains why those alternatives are the right comparison).

**Non-consumption.** Often the largest market is people with the job who use **no** solution, because what exists is too costly, complex or inaccessible for their circumstance. Frame those jobs around the moment the need turns urgent ("the auditor asks", "the big customer sends a questionnaire"), not around a steady-state workflow.

**Big Hire vs Little Hire.** The **Big Hire** is the purchase decision; a **Little Hire** is each moment the product is actually used. Write one line for each, per core job. The Little Hire line usually becomes an onboarding or time-to-first-value requirement: a product that wins the Big Hire and no Little Hires becomes shelfware.

---

## 8. Forces of progress

Four forces decide whether a switch happens (Moesta and Spiek; in *Competing Against Luck*):

| Force | Direction | What it is | Design lever |
|---|---|---|---|
| **Push** of the situation | For change | The pain of the struggling moment | Name the cost of the struggling moment in messaging |
| **Pull** of the new solution | For change | The appeal of the better state | Features and outcomes: the only force most teams work on |
| **Anxiety** of the new solution | Against | Fear the new thing fails, costs or embarrasses | Trust, spot-checks, reversibility, evidence of accuracy |
| **Habit** of the present | Against | Comfort with the incumbent, however bad | Import the old spreadsheet, mirror the familiar workflow first |

A switch happens only when push and pull outweigh anxiety and habit. Fill the table from switch interviews, one row per force, each cell quoting a specific event and citing its snapshot. Persona fields map to forces: **Trigger ≈ push**, **Current approach ≈ habit** (and what gets fired), **Adoption barrier ≈ anxiety**; pull lives here because a persona stays solution-free.

---

## 9. Drift: how organisations lose the job

*Competing Against Luck* warns that the job is vivid at founding and fades into dashboards as a company grows: teams chase sales that serve other jobs and collect the data that confirms the existing plan. In an artifact this shows as **backwards JTBD**: job stories written to justify an already-decided feature. The tell is that every implied capability matches the roadmap exactly. Two safeguards work at different times: question discipline keeps bad data out of the conversation (`./interviewing-and-synthesis.md`), and this post-hoc check catches bad conclusions afterwards. Apply both.
