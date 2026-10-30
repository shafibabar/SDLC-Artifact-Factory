# Persona Synthesis and the Persona Lifecycle

Self-contained reference for the `user-persona` skill. Part 1 is the procedure that turns interview notes, or hypotheses when there are none, into personas: behavioural variables, patterns, the merge and gap check, and type designation. Part 2 is the lifecycle that keeps a persona set honest after it is approved: how it is used, reviewed, reopened and retired. Read Part 1 whenever there are interview notes or more than two roles; read Part 2 when setting `review-by:`, handling a change request, or writing an enterprise persona set.

Sources: Alan Cooper, Robert Reimann, David Cronin and Christopher Noessel, *About Face* (behavioural variables, persona types); John Pruitt and Tamara Adlin, *The Persona Lifecycle* (factoids, skeletons, foundation documents, the persona-weighted feature matrix, retirement); Mike Cohn, *User Stories Applied* (role brainstorming); Dan Olsen, *The Lean Product Playbook* (needs scored per segment, not pooled).

---

## Part 1 — Synthesis: from evidence to personas

Skipping straight from "pull the ICP" to "fill the fields" is how personas become job titles with adjectives. The behavioural-variable step is what makes a persona **checkable**: a reviewer can see which people stand behind which pattern.

### Step 0 — List the roles

Take the buying committee roles from the stakeholder map (§2). Where there is no committee (a lean internal tool, a consumer app), use Cohn's **role brainstorming**: list every distinct way someone interacts with the system, merge near-duplicates, and order the survivors along an axis that changes behaviour (frequent ↔ occasional, novice ↔ expert, inside ↔ outside the company). Roles are the starting point, not the personas: one role can hold two personas, and one persona can span two roles.

### Step 1 — Identify behavioural variables

For each role, write five to ten variables as **two-ended ranges** under *About Face*'s five headings:

| Heading | Asks | Example range |
|---|---|---|
| Activities | What they do, how often, how much | Processes 2 returns a week ↔ 60 a day |
| Attitudes | How they think about the domain and the technology | Trusts automated output ↔ verifies every result by hand |
| Aptitudes | Training, ability to learn | Needs a printed checklist ↔ learns a tool by exploring |
| Motivations | Why they do it | Avoid a mistake in front of the boss ↔ clear the queue fast |
| Skills | Domain and technical capability | Knows every supplier's returns policy ↔ none |

### Step 2 — Map each person onto each range

Place each interviewee on every range. Relative position matters more than measurement. With no interviewees, place **hypothesised** positions, mark the table `[assumption]`, and it becomes the **persona hypothesis**: which kinds of user you expect, which variables separate them, and therefore whom the user should recruit first.

### Step 3 — Find patterns

People who sit together on several variables form a candidate persona. The pattern must make sense: the clustered variables should explain each other (high volume, distrust of automation and fear of refund mistakes go together). Pruitt and Adlin's version of the same step is bottom-up: extract **factoids** (one fact, one source each), cluster them by affinity, write a short **skeleton** per cluster, then grow the chosen skeletons into full personas.

### Step 4 — Check for completeness and redundancy

- Two candidates in the same place on most variables, sharing goals and job, are **one persona**, however different their ages, titles or companies. Merge them and say why.
- A person who fits no pattern, or a range with nobody at one end, means a **missing persona** or missing research: flag it, do not invent a filler.

### Step 5 — Fill the fields and tag sources

Fill each field from the pattern (field rules: `persona-fields-and-grounding.md`). Every attribute carries a source tag naming the interviewees it came from, or `[assumption]`.

### Step 6 — Designate types

One **primary per interface**: for each surface (a mobile picker, an approval queue, an admin console, an evidence export), the persona whose needs no other design would meet. If two personas both claim one surface, choose one and demote the other to secondary. Then add a **customer** persona where the buyer is not the user, **served** personas where the product acts on people who never use it, and one **negative** persona. If more than about three primaries emerge, the scope is too broad: raise it with the user.

### Worked mini-table (returns-processing app, five interviews the user held)

| Variable | INT-1 lead, 34 | INT-2 ops manager, 51 | INT-3 packer, part-time | INT-4 owner | INT-5 seasonal temp |
|---|---|---|---|---|---|
| Returns handled: few a week ↔ dozens a day | dozens | dozens | few | none | few |
| Trust in auto-refund: lets it run ↔ checks every one | checks | checks | — | lets it run under £100 | — |
| Needs a checklist ↔ explores | explores | explores | checklist | — | checklist |
| Motivation: clear the queue ↔ avoid a mistake | clear the queue | clear the queue | avoid a mistake | protect margin | avoid a mistake |

Patterns: {INT-1, INT-2} one persona (different titles and ages, same behaviour: merged) → **primary** of the returns queue. {INT-3, INT-5} one persona → **secondary** (the same queue, plus a guided mode). INT-4 approves refunds above a limit and never touches the queue → **customer** persona. Shoppers who send items back never use the tool and are affected by refund speed → **served**.

---

## Part 2 — The persona lifecycle

Pruitt and Adlin's central finding is that personas fail more often because they are made and then ignored than because they are made badly. Their five phases, scaled to this plugin:

| Phase | In this plugin |
|---|---|
| Family planning | Decide the profile and the inputs; write the persona hypothesis (Step 2 with no interviewees) |
| Conception and gestation | Factoids → skeletons → personas (Part 1); at enterprise, a **foundation** section listing the factoids behind each persona |
| Birth and maturation | Present the set to the user for review; keep the names stable so stories, journeys and reviews can use them |
| Adulthood | Use them: story roles, one journey per primary × high-value job, and at enterprise the persona-weighted feature matrix |
| Lifetime achievement and retirement | Review on the `review-by:` date and on every reopen trigger; reuse on the next product only where the population is the same; retire when the evidence moves on |

### The persona-weighted feature matrix (enterprise)

Features (or epics) × personas. Each persona carries a weight (the primaries highest; served personas can carry weight for a protecting feature); each cell scores the feature's value to that persona (0–3). The weighted sum per feature is an **input** to `moscow-prioritization`, never the decision itself. It keeps needs scored per persona instead of pooled into one average, which is Olsen's warning about blended segments. Skip it at lean; optional at standard.

| Feature | Office manager (primary, ×3) | Managing partner (customer, ×2) | Clients (served, ×1) | Weighted |
|---|---|---|---|---|
| Approve-before-send queue | 3 | 1 | 2 | 13 |

### Reopen triggers

Each is a change request back to `requirements-analyst`, recorded in the artifact's version log:

- A journey map (`ux-architect`) finds a job no persona covers, or a reviewer names a missing persona: usually a secondary, supplemental or served persona the type list should have caught.
- A design-partner session contradicts an attribute: correct or delete it, and retag; never defend an assumption against evidence.
- The GTM adds a segment or tenant type, or a beachhead changes.
- The `review-by:` date passes.

### Retirement

A persona that no longer matches the evidence, the product or the market is marked `Status: retired · <date> · <reason>` and kept, so stories and journeys that cite it can be traced. Its stories are re-pointed to the persona that replaces it. Silent deletion leaves orphaned story roles and hides why the design changed.

### Upgrading grounding

Grounding is tracked **per attribute**. When the user returns from a design-partner session, retag the attributes the notes support, correct those they contradict, leave the rest `[assumption]`, and recompute the MIXED count. Only when every load-bearing attribute is interview-tagged does the agent *propose* RESEARCH; the user confirms it at review.
