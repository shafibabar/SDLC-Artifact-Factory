# Persona Fields, Grounding and What to Leave Out

Self-contained reference for the `user-persona` skill. It defines every persona field, the design decision each one drives, and the question that would ground it in an interview; then the grounding rules (provenance label, source tags, validation questions, who interviews) and the leave-out list. Read it when filling a field, labelling grounding, or writing the validation questions.

Sources: Alan Cooper, *The Inmates Are Running the Asylum* and Cooper, Reimann, Cronin and Noessel, *About Face* (goal-directed personas, end / experience / life goals, persona types); John Pruitt and Tamara Adlin, *The Persona Lifecycle* (sourced factoids, assumption personas); Clayton Christensen et al., *Competing Against Luck* (forces of progress, the job/persona boundary); Rob Fitzpatrick, *The Mom Test* (elicitation); Ram Srinivasan, *Simple Data* (trust in automated decisions); Martina Lauchengco, *Loved* (persona-specific messaging).

---

## 1. The header lines every persona carries

| Line | Holds | Rule |
|---|---|---|
| **Type** | Primary · Secondary · Supplemental · Customer · Served · Negative | Exactly one. A primary also names its **Interface** (the surface it is the design target for); no two primaries share an interface |
| **Grounding** | The provenance label (section 3) | Never blank. Agent-written with no interview notes → PROTO |
| **Status** | active · retired (with the reason and date) | A retired persona stays in the artifact |
| **Role and context** | The role this person holds and the company (or life) context they sit in, consistent with the ICP | Context, not identity: two people with the same title can be two personas (one trusts automation, one does not), and one persona can span several titles |

## 2. The fields, what each drives, and how it would be grounded

Every field carries a source tag (section 4). The elicitation question is for the **user** to ask a real person; the agent turns it into a validation question when the field is an assumption.

### Behavioural variables (the distinguishing ranges)
- **Holds:** the three to five two-ended ranges on which this persona sits apart from the others, with its position ("verifies every reminder ↔ lets them send": far left).
- **Drives:** why this is a separate persona at all; which interviewee pattern stands behind it.
- **Grounded by:** placing interviewees on the ranges (procedure: `synthesis-and-lifecycle.md`).

### End goals
- **Holds:** what the person wants to get done, solution-free.
- **Drives:** functional requirements and the job statement.
- **Elicitation:** "What were you trying to get done the last time this came up? What happened?"

### Experience goals
- **Holds:** how they want to feel while doing it: in control, not stupid, not exposed in front of a client or an auditor.
- **Drives:** usability NFRs and onboarding constraints ("must never make her feel the tool knows her data better than she does"). An adoption barrier is usually a violated experience goal.
- **Elicitation:** "What was the worst part of the last time? How did that land with you?"

### Life goals
- **Holds:** who they want to be beyond the product, including what gets them recognised.
- **Drives:** messaging (`gtm-strategy`), long-term loyalty. Rarely a feature. One line or omitted for a B2B tool.
- **Elicitation:** "How is your work judged? What did your last review focus on?"

### Current approach (habit)
- **Holds:** how they get the end goal done today without the product: the workaround, spreadsheet, consultant or "nobody does it until the auditor asks" (non-consumption).
- **Drives:** the switching story. This is the **habit** force and names what gets fired. The most load-bearing context field.
- **Elicitation:** "Walk me through the last time you did this. What did you actually use?"

### Primary frustration (and up to two secondary)
- **Holds:** the costliest pain in the current approach.
- **Drives:** the motivation in the job; what the value proposition must relieve.
- **Elicitation:** "What was the most annoying or expensive part of that last time? What did it cost you?"

### Trigger (push)
- **Holds:** the event that ends passive looking: the struggling moment.
- **Drives:** the situation in the job stories (`jtbd-analysis`); demand timing for the GTM.
- **Elicitation:** best reconstructed as a timeline in a switch interview ("What happened right before you started looking?"), not asked as a direct "what would make you look?".

### Adoption barrier (anxiety)
- **Holds:** the most likely reason they abandon after trying: the **anxiety** force.
- **Drives:** what the first session must never require; onboarding constraints.
- **Elicitation:** "What made the last tool you dropped not stick?"

### Trust in automated output
- **Holds:** for a product that drafts, classifies, matches or decides for this person: must they see the reasoning and verify before acting, or will they accept output once it has proven reliable a few times? What erodes that trust?
- **Drives:** explainability requirements (reason and evidence beside every automated result, a correct-this control). A trust barrier is fixed with transparency; a usability barrier with less friction. Do not confuse them.
- **Elicitation:** "Last time a tool made a call for you, what did you check before you acted on it?"

### Time to first value
- **Holds:** how fast they must see value before they revert. Christensen's **Big Hire** (the purchase) is not the **Little Hire** (each use); time to first value is about the first Little Hire.
- **Drives:** a first-run usability NFR.
- **Elicitation:** inferred from their described patience with the current workaround.

### Decision style and information sources (customer and secondary personas mainly)
- **Holds:** how they decide to adopt (wants proof on their own data, trusts peers' references, waits for others) as a position on a range, not a fixed category; where they learn about tools.
- **Drives:** which proof points the GTM leads with for this audience (Lauchengco, *Loved*) and the channel choice. Not the daily interface.
- **Elicitation:** "Last time you brought in a new tool, what convinced you? Where did you first hear of it?"

### Job statement (the link out)
- **Holds:** one line, `[verb] [object] [clarifier]`, solution-free (Ulwick's syntax, as taught in `jtbd-analysis`): "Get paid for billed work without chasing clients by hand."
- **Drives:** the entire job-story set `jtbd-analysis` writes against this persona.
- **At lean only**, where `jtbd-analysis` is skipped, add one or two job stories ("When … I want to … so I can …") and a one-line forces summary (push · pull · habit · anxiety).

Supplemental, served and negative personas carry only the header lines, role and context, and the one or two attributes that justify them (what the product does to a served persona; why a negative persona is excluded).

## 3. The provenance label

| Label | Exact form | Allowed when |
|---|---|---|
| PROTO | `PROTO — assumption-based · written by requirements-analyst (AI) from <inputs> · no user research` | Always allowed. The default for agent-written personas |
| MIXED | `MIXED — <n> of <m> load-bearing attributes interview-grounded` | The user supplied notes from interviews they (or a design-partner session) held, and those notes support n attributes |
| RESEARCH | `RESEARCH — interview-grounded` | Every load-bearing attribute is interview-tagged **and** the user confirmed the upgrade at review. The agent never applies it on its own authority |

`<inputs>` names the real sources: "the problem statement, the ICP and stakeholder map §2", "the user's description of their office". The frontmatter repeats the artifact-level picture: `grounding: proto | mixed | research`, `authored-by:`, `evidence: none | second-hand: … | interviews: …`.

**Who interviews.** The agent cannot hold an interview. The user, or a design-partner session the user runs, is the interviewer. The agent writes the guide (the validation questions and the recruiting hint) and synthesises the notes it is given.

## 4. Source tags

Each attribute line ends in one tag, Pruitt and Adlin's factoid in miniature:

| Tag | Meaning |
|---|---|
| `[DP-2 · 2026-11-03]`, `[INT-4]` | An interview the user held; the reference points at the notes |
| `[support tickets]`, `[stakeholder map §2]`, `[ICP]`, `[problem statement]`, `[user's description]` | Second-hand evidence |
| `[assumption]` | The agent's inference with nothing behind it |

Only notes that report a **specific past event** ground an attribute. Fitzpatrick's three kinds of bad data ground nothing, even when they came from a real interview:

| Bad data | Sounds like | Fix |
|---|---|---|
| Compliment | "Great idea, I'd definitely use that" | Ask about the last time the problem happened |
| Fluff | "I usually…", "I would…" | Press for the last actual occurrence |
| Idea | "You should build a dashboard" | Ask what problem that would solve, and when it last bit |

At three to five design partners there is no sample to average a bad answer away: one politeness-driven answer can define a persona.

## 5. Validation questions

Every PROTO or MIXED persona ends with a table: for each load-bearing `[assumption]`, the question that would test it and the answer that would mean the persona is wrong.

| Attribute | Ask (a specific past event) | Wrong if |
|---|---|---|
| Current approach: a shared spreadsheet | "Show me what you used to send last Friday's order." | They used the restaurant's own app |

Add one line on **whom to recruit first**: the people whose positions on the behavioural variables would split or merge the hypothesised personas.

## 6. What to leave out

| Leave out | Why |
|---|---|
| Age, gender, hometown, marital status, hobbies | Do not predict behaviour; goals, forces and variables do |
| A photo, stock image or generated face | Encodes a stereotype and makes an assumption look like a real person. Cooper and Pruitt-Adlin recommend an image; this skill deliberately departs from them for agent-written personas |
| Invented quotes | A fabricated quote reads as evidence. Quote only interview notes, with the tag |
| Aspirational traits ("a visionary data leader") | Marketing language; model who they are |
| Salary, tenure, reporting lines | Noise, unless they gate a buying decision (then they belong to the customer persona, with the reason) |

Keep the first name: a named persona is what defeats the elastic user. Keep firmographic or life facts that drive a requirement (company size, regulatory exposure, works one-handed on a ward) and name the requirement they drive.
