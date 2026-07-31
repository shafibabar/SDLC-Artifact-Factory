# Narrative Arc, the Big Idea, and Annotation Strategy

This reference expands Lesson 6 of Knaflic's *Storytelling with Data* — the narrative craft that
turns a correct chart into a story someone acts on — plus the integrity rules that keep that
persuasion honest. It is the depth behind the SKILL body's four-part Context → Insight →
Recommendation → Call-to-Action structure.

---

## The Big Idea — the exercise you do before building anything

Knaflic's **Big Idea** exercise forces clarity before a single chart is drawn. The Big Idea is your
whole point expressed as **one complete, opinionated, single sentence** — not a topic, not a subject
line, but a claim with a position in it.

Three tests a valid Big Idea must pass:

1. **It states your unique point of view** — what *you* conclude, not merely the subject area.
2. **It conveys what is at stake** — why the audience should care.
3. **It is one full sentence** — if it needs two, you are carrying two ideas and must split or cut.

| Not a Big Idea (a topic) | A Big Idea (a claim, single sentence) |
|---|---|
| "Extraction confidence" | "PDF extraction confidence has dropped below our manual-review threshold and will erode customer trust within weeks unless we tune the OCR fallback." |
| "Classification coverage this quarter" | "Classification coverage crossed the 90% SOC 2 target for the first time this quarter, so we can now cite automated coverage as audit evidence instead of manual sampling." |

The companion is the **3-minute story**: if you cannot tell someone your point in three minutes with
no slides, you do not yet know what you are communicating, and no chart choice will rescue it. The Big
Idea is the one-sentence distillation of that 3-minute story. Write it at the top of the data story
(the `**Big Idea:**` line in the SKILL Output Format) and reject any chart that does not serve it.

---

## The Narrative Arc in Depth

Knaflic borrows classic dramatic structure. Mapped to a data story:

| Story beat | Data-story part | What it does |
|---|---|---|
| **Setup** | Context | Establishes the plot: what was normal, what the audience already believed, what baseline the finding will be judged against |
| **Rising action / tension** | Insight (build) | The complication — something changed, a gap opened, an expectation broke |
| **Climax** | Insight (the finding) | The single sentence the whole story exists to deliver — your Big Idea, landed |
| **Falling action** | Recommendation | The consequence and the options that follow from the finding |
| **Ending** | Call to action | What happens next — who does what, by when |

**Why tension matters.** A finding with no established "normal" before it has no tension, and tension
is what makes an audience *want* the resolution. "Confidence is 0.74" is inert. "Confidence has held
at 0.91 for a quarter — and last week it fell to 0.74" creates the gap the audience now wants closed.
Always build the baseline before revealing the break.

### Storyboarding

Before building any slide or chart, **storyboard** — sketch the sequence of points on paper or sticky
notes. Storyboarding is cheap to rearrange; built slides are not. It also surfaces whether you have
one story or several competing ones (the latter is the most common cause of a data story that will not
cohere).

---

## Horizontal vs. Vertical Logic

Two independent consistency checks Knaflic applies to a multi-part communication:

- **Horizontal logic** — reading *only the headlines / takeaway titles* across the whole sequence, in
  order, should tell the entire story on their own, with no charts. If the headlines alone do not
  narrate the argument, the argument is hidden in the charts where a skimming audience will miss it.
- **Vertical logic** — *everything on a single view* must support that view's specific headline, and
  nothing extraneous. If a chart or bullet on the slide does not serve the headline, cut it or move it.

For a standalone PDF (e.g. this platform's SOC 2 Evidence Report, read by an auditor with no
narration), horizontal logic is not optional — the section headings *are* the argument, because there
is no presenter to fill the gaps between charts.

---

## Annotation and Takeaway-Title Strategy

The "so what" is Knaflic's refrain: a chart that shows data without stating what to take from it has
not communicated. Every explanatory visual carries its takeaway **on the visual**.

### Takeaway titles

The chart's title is not its subject — it is its **conclusion**.

| Descriptive title (subject) | Takeaway title (conclusion) |
|---|---|
| "Extraction Confidence by Week" | "PDF confidence fell 17 points after a scanned-PDF estate began ingesting" |
| "Classification Coverage, Q2" | "Coverage crossed the 90% SOC 2 target in week 9 and held" |

A takeaway title lets a skimming reader — or an auditor reading a frozen document — land on the point
without decoding the chart. It is also what horizontal logic reads across.

### Annotations

Annotations put the words where the eye already is. Use them to:

- **Name the cause at the point it happened** — a short label with a marker on the exact data point
  ("new customer's scanned-PDF estate begins ingesting"), so the viewer sees the step change is tied
  to a cause, not gradual drift.
- **Draw the reference line** the story is about — the manual-review threshold, the SLA, the target —
  faint, labeled, so the reader sees the crossing without hunting.
- **State the number in words** next to the point it describes, replacing a legend or a mental
  subtraction the reader would otherwise have to do.

Keep annotations sparse. Every annotation competes with the others for the attention the accent color
is trying to direct; two well-placed labels beat six.

---

## Integrity: Persuading Honestly (fixes in full)

Knaflic's craft makes a story *land*; it does not make it *true*. A story that persuades through
distortion is a defect regardless of intent — a truncated axis chosen "because it looked cleaner"
still misleads about magnitude. Check every story against all seven before presenting:

| Manipulation pattern | What it does | Fix |
|---|---|---|
| **Truncated y-axis** | Starts the axis above zero, exaggerating a small change | Start bar-chart axes at zero. For a line where zero is genuinely uninformative (a metric that only ranges 0.90–0.99), label the axis start explicitly and say so in narration |
| **Cherry-picked window** | Picks the start/end date that flatters the conclusion | Show enough history to reveal whether this window is representative; state why the window was chosen |
| **Denominator hiding** | Presents a count with no base ("500 gaps closed!" out of how many?) | Pair every count with its rate or total whenever the total changes the interpretation |
| **Cause implied from correlation** | Two lines move together, presented as cause and effect with no mechanism | State the mechanism, or explicitly flag "correlated, cause not established" |
| **Silent aggregation hiding a bad segment** | An improving average masks one severely worsening subgroup | Show the breakdown, not just the aggregate, whenever a subgroup could plausibly diverge (the disaggregation check from `analytics-requirements`) |
| **Precision theater** | "94.37%" from a tiny sample, implying rigor the data lacks | Round to the precision the sample supports; state the sample size |
| **Favorable comparison period** | Compares against the worst prior period to flatter the present | Use a consistent, pre-agreed comparison (same period last cycle), not the most flattering one available |

None of these require intent to be harmful. The check applies regardless of motive, and it applies to
the honest-but-careless case as much as the manipulative one. Run it as the last step before any data
story is presented or handed over.

---

## Adapting a live technique to a spec-written artifact

Knaflic assumes a human presenter iterating for a live audience — she can show a draft to a colleague,
watch where their eyes land, and revise. This repo's Data-phase artifacts have no such loop: a data
story is written once and read later by an unknown viewer, sometimes a frozen PDF an auditor opens
with no narration. The adaptation is to convert her live, feedback-driven judgment into **fixed
structural rules applied at authoring time**:

| Live technique (book) | Spec-written rule (this repo) |
|---|---|
| "Show a draft and watch where their eyes go" | Apply the accent-color / single-emphasis rule uniformly; do not rely on live gaze feedback |
| "Iterate the decluttering for this chart" | Run the fixed decluttering checklist on every visual, justify anything kept |
| "Narrate the takeaway aloud" | Write the takeaway into the title and an on-chart annotation, since no narrator will be present |
| "Read the room and adjust tone" | Fix the audience/decision/action in the front matter so tone is decided before drafting |

The practical consequence: the takeaway title and annotations are **mandatory on the page**, not
optional aids a presenter can supply verbally. If a viewer could reach the wrong conclusion when no one
is in the room to correct them, the story is not finished.

---

## A worked annotation pass

Take a line of PDF extraction confidence that steps down in one week. A bare chart shows the step; it
does not explain it. The annotation pass adds exactly what a narrator would have said:

1. **Reference line** — draw the 0.85 manual-review threshold, faint, labeled, so the reader sees the
   line the story is about without hunting for it.
2. **Cause label at the point** — a marker on the week the drop began, labeled "new scanned-PDF-heavy
   estate begins ingesting," so the step reads as a caused event, not random drift.
3. **Takeaway title** — replace "Extraction Confidence by Week" with "PDF confidence fell below the
   manual-review threshold when a scanned-PDF estate began ingesting."

Three additions, no more. A fourth annotation would start competing with the accent color for the
attention the first three already direct. Sparse and placed-where-the-eye-is beats comprehensive.
