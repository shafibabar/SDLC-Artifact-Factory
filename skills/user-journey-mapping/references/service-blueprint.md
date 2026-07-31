# The Service Blueprint — Extending a Journey Map Below the Line of Visibility

Reference for `user-journey-mapping`. The SKILL.md body draws the map-vs-blueprint
distinction and says *when* to extend a journey map into a blueprint; this file is the
full blueprint mechanics — every lane, all three boundary lines, support processes, how
to source the back-stage lanes without inventing them, and a worked blueprint for the
repo's Compliance Officer persona. Grounded in Stickdorn et al., *This Is Service Design
Doing* (Ch. 3), which draws in turn on Lynn Shostack's 1984 original and the
Bitner/Ostrom/Morgan refinements. The front-stage/back-stage vocabulary is Erving
Goffman's dramaturgical metaphor (1959), adopted by service design deliberately: a
service is a performance, the customer only ever sees the stage.

---

## 1. Why a Blueprint, When a Journey Map Already Exists

A journey map is customer-perspective by design. Its Touchpoints lane records *where the
customer looks* — it never records *what has to succeed, unseen, for that look to show
the right thing*. That is a genuine blind spot, not something the six-lane structure
implicitly covers.

Concretely: the Maya Chen journey's "Analysis" stage touchpoint is "Compliance
Dashboard; Data Asset Detail pages." For that dashboard to show correct numbers, three
things the customer never sees must already have finished — the estate scan of every
connected source, the classification of every discovered asset, and the compliance
evaluation against the chosen framework. The journey map names none of them. A slow or
wrong dashboard reads, on the map, as a *front-stage* problem; the blueprint is what
reveals the real cause sits below the line of visibility.

**A blueprint makes the invisible half of the service visible.** It is a bridge artifact:
it takes the journey map's front-stage rows as-is and adds the operational lanes beneath
them.

---

## 2. The Lanes

A blueprint is read left to right against the **same timeline as the journey map** — the
same stages, the same columns. Stacked vertically, from the customer down to the
infrastructure:

| Lane | Contains | Relation to the journey map |
|---|---|---|
| **Physical Evidence** | What is tangible at each step — a confirmation email, a progress bar, a downloadable report | New (the map has no equivalent) |
| **Customer Actions** | What the customer does — front-stage | Identical to the map's Actions lane |
| **Front-stage Actions** | Visible employee/system actions the customer directly perceives — a screen rendering, a returned result | The system side of a touchpoint |
| **Back-stage Actions** | Employee/system actions that support the front-stage but are **invisible** to the customer | Absent from the map entirely |
| **Support Processes** | Internal systems and infrastructure that enable the back-stage — databases, brokers, third-party APIs, schedulers | Absent from the map entirely |

---

## 3. The Three Boundary Lines

Between the lanes run three horizontal lines. They are the point of the whole artifact —
each one is a decision about what the customer can and cannot perceive.

- **Line of Interaction** — between **Customer Actions** and **Front-stage Actions**.
  Crossed every time the customer and the organisation interact directly (a click that
  hits the system, a report the system returns to the customer).
- **Line of Visibility** — between **Front-stage** and **Back-stage**. *Everything below
  this line is invisible to the customer, by definition.* This is the single most
  load-bearing line: it is the concept a plain journey map has no notation for at all.
  For every front-stage step, the blueprint forces the question **"what below this line
  has to succeed first?"**
- **Line of Internal Interaction** — between **Back-stage Actions** and **Support
  Processes**. Separates people-or-service-facing back-stage work from the
  systems and infrastructure that enable it (e.g. a classification service, back-stage,
  vs. the Postgres/Redpanda/Apache AGE substrate beneath it that is pure support
  process).

```
                         C U S T O M E R
─────────────────────────  Line of Interaction  ─────────────────────────
                    F R O N T - S T A G E   (visible)
──────────────────────────  Line of Visibility  ─────────────────────────
                     B A C K - S T A G E   (invisible)
────────────────────  Line of Internal Interaction  ─────────────────────
                    S U P P O R T   P R O C E S S E S
```

---

## 4. Sourcing the Back-stage Lanes — Ground Them, Never Invent Them

Stickdorn's blueprints are built in cross-functional workshops precisely because *the
people who run the back-stage process are the only ones who reliably know what happens
there.* A designer reconstructing the back-stage alone gets it wrong. This repo has no
workshop room and one engineering agent — so the equivalent discipline is:

> **Source every back-stage and support-process lane from the
> `event-storming-facilitation` output for that domain — never from the agent's own
> inference.**

The Event Storming session (which, per its own quality criteria, required at least one
person with first-hand domain knowledge) has already traced the back-stage
cause-and-effect. Translate its cards into the blueprint's operational lanes:

| Event Storming card | Blueprint lane | Translation rule |
|---|---|---|
| **Actor** | Back-stage Actions (if internal) | Plain-language name; keep the DDD term in parentheses |
| **Command** | Back-stage Actions | "the system starts the scan (`ScanEstate` command)" |
| **Aggregate** | Back-stage Actions | The thing acted on; note if it is *entirely* back-stage (no front-stage projection) |
| **Policy** | Back-stage Actions | "whenever a scan completes, classification is triggered" |
| **Domain Event** | Back-stage Actions (as a milestone) | The unseen "done" signal a front-stage step waits on |
| **External System** | Support Processes | Google Drive, S3 — with their rate/permission constraints noted |

Translate DDD vocabulary into plain operational language *above* the line notation,
keeping the precise domain term as a parenthetical for traceability, so Shafi can read
the blueprint without domain-modelling literacy while the link back to the model stays
intact.

If a front-stage step has **no discoverable back-stage Aggregate or Command to back
it**, that is not a blueprint gap — it is an upstream domain gap, and the correct move
is to escalate it to the `domain-modeler`, not to invent a plausible back-stage.

---

## 5. Microfrontend Note

This repo's front-stage is a shell plus independently-deployable remotes. Two
consequences for the blueprint:

- The **Front-stage Actions** lane crosses remote boundaries within a single journey.
  Mark which remote owns each front-stage step; a hand-off *between* remotes (the shell
  routing from the sources remote to the reports remote) is itself a front-stage seam
  where a Moment of Truth often lands.
- A back-stage Bounded Context frequently has **no remote at all** (a classification
  engine with no UI). That is expected: it sits below the line of visibility and has no
  place in the front-stage lane or in the `information-architecture` — the blueprint is
  where its existence is recorded, not the IA.

---

## 6. Worked Blueprint — Compliance Officer Requests an Audit-Ready Report

**Persona:** Maya Chen, Compliance Officer.
**Journey stage blueprinted:** "Reporting" — Maya generates and exports an audit-ready
compliance gap report. This stage was chosen because its emotion-curve entry is a
Moment of Truth ("will the auditor accept this format?") and its back-stage is thick.

```
STAGE:  Reporting — "generate the audit-ready gap report"
════════════════════════════════════════════════════════════════════════════
Physical      | Generate-Report form  | progress spinner   | downloadable PDF/XLSX
 Evidence     |                       |                    | + "ready" email
────────────────────────────────────────────────────────────────────────────
CUSTOMER      | selects framework      | waits              | downloads report;
 Actions      | (SOC 2), clicks        |                    | shares with auditor
              | "Generate"             |                    |
═══════════════════════  Line of Interaction  ══════════════════════════════
FRONT-STAGE   | Reports remote renders | shell shows        | Reports remote
 Actions      | the form, validates    | live status        | serves the file +
              | selection              |                    | fires "ready" toast
──────────────────────  Line of Visibility  ════════════════════════════════
BACK-STAGE    | report service accepts | evaluation service | rendering service
 Actions      | request (`RequestGap-  | computes gaps vs   | composes PDF/XLSX
 (invisible)  | Report` command)       | SOC 2 controls     | (`RenderReport`);
              |                        | (`EvaluateGaps`    | emits ReportReady
              |                        | policy, on every   | domain event
              |                        | ScanCompleted)     |
════════════════  Line of Internal Interaction  ════════════════════════════
SUPPORT       | Postgres (asset +      | classification     | object store for
 Processes    | classification read    | labels from        | generated files;
              | model, via pgx)        | Apache AGE lineage  | Redpanda carries
              |                        | graph; Redpanda     | ReportReady;
              |                        | scan events         | email provider
════════════════════════════════════════════════════════════════════════════
```

**What the blueprint reveals that the journey map hid.** On the journey map, Maya's only
visible Reporting friction is "will the auditor accept this format?" — a front-stage
formatting concern. The blueprint shows the report's *correctness* depends on a chain of
unseen steps: the gap evaluation can only be as current as the last completed estate
scan, and the classification labels it reads come from the Apache AGE lineage graph. If
a source's scan stalled back-stage, Maya's report is silently incomplete — a front-stage
Moment of Truth ("the auditor rejected our report") whose true cause sits two lanes
below the line of visibility, invisible to the journey map and to Maya alike.

**Downstream consequences.** Each back-stage dependency the blueprint surfaces becomes a
flow branch `ux-flow-design` must handle (a "scan still running — report may be
incomplete" state) and an operational-readiness question for Design: can the back-stage
report pipeline run repeatedly, under load, without hand-holding? That is a distinct
release-readiness question from "does the UI work," and the blueprint is what makes it
askable.

---

## 7. When Not to Blueprint

Blueprint only where the front-stage/back-stage gap is large — an estate scan, a
classification pass, a compliance evaluation. A CRUD-like journey (editing a display
name) has a thin, uninteresting back-stage and does not earn the artifact. Use the
journey map's emotion-curve valleys as the signal for which journeys get a blueprint
pass; drawing one for every journey uniformly is the over-application the technique
specifically warns against.
