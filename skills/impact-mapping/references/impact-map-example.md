# Worked Impact Map — Data Estate & Compliance Platform

A complete, end-to-end Impact Map for this repo's first product: an event-driven
microservices platform that maps a small business's data estate (Google Drive, S3,
and PDF/DOCX/XLSX documents) and surfaces compliance gaps for a SOC 2 MVP. The two
primary personas are the **Data Steward** and the **Compliance Officer**. This example
shows the full WHY → WHO → HOW → WHAT chain, the MVP prune, and how the result feeds
`okr-authoring` and `story-mapping`.

---

## Starting point: the OKR Key Result (WHY)

The map begins from a single Key Result handed down by `product-strategist` /
`okr-authoring`. Note it is an **outcome**, not a feature list:

> **Objective:** New teams reach a "the platform sees my whole estate" moment fast
> enough to trust it before the trial ends.
>
> **Key Result KR-2:** *70% of trial teams connect at least two data sources AND
> surface their first real compliance gap within the first 30 minutes of a session,
> by end of Q3.*

That Key Result is the goal at the root of this map. (KR-1 and KR-3 get their own maps —
one map per Key Result.)

**Why this is a valid goal:** it is measurable (70% / two sources / one gap / 30
minutes), it is an outcome the team cannot achieve alone (trial teams must actually *do*
the connecting and *reach* the gap), and it traces to a named Key Result.

---

## The map

### Actor: Data Steward — *Primary*

The person inside the customer who knows where the data lives and does the connecting.

| Impact (HOW — behavior change) | Candidate Deliverables (WHAT — hypotheses) |
|---|---|
| Connects **all** their storage sources in the first session, instead of stopping after one and drifting away | • Guided onboarding wizard that connects a source in < 5 min<br>• One-click Google Drive OAuth 2.0 connector<br>• One-click S3 connector (IAM role paste)<br>• In-app progress meter showing "2 of 4 sources connected"<br>• Email nudge if only one source connected after 24h |
| Trusts the estate map enough to show a colleague, instead of re-checking it manually against a spreadsheet | • Coverage summary ("we scanned 12,400 files across 3 sources")<br>• "What we could NOT reach" honesty panel |

### Actor: Compliance Officer — *Primary*

The person who has to act on findings and answer to the auditor. (This is "Maya" in the
skill's examples.)

| Impact (HOW — behavior change) | Candidate Deliverables (WHAT — hypotheses) |
|---|---|
| Discovers her first real compliance gap live in the session, instead of waiting for a quarter-end manual review | • First-run scan that surfaces the single highest-severity gap immediately<br>• Gap card with the specific file + control it violates<br>• "Sort by SOC 2 control" gap view |
| Briefs the CISO from live platform data, instead of assembling a stale spreadsheet by hand | • Shareable read-only gap summary link<br>• Export-to-PDF evidence pack |

### Actor: Customer IT / onboarding lead — *Secondary*

Supports the Data Steward when connection needs infra access.

| Impact (HOW — behavior change) | Candidate Deliverables (WHAT) |
|---|---|
| Grants source access without a multi-day ticket cycle | • Copy-paste least-privilege IAM policy for S3<br>• Pre-scoped Google Workspace connector consent screen |

### Actor: IT Security — *Blocker*

Can prevent the goal by refusing or delaying deployment/data-access approval.

| Impact (HOW — remove the blocking behavior) | Candidate Deliverables (WHAT) |
|---|---|
| Approves the data-access request without escalating to a security review, because concerns are pre-answered | • Read-only / least-privilege access model documented up front<br>• "Encryption in Transit + at Rest" one-pager<br>• Physical multi-tenancy statement |

### Actor: Auditor — *Off-stage*

Doesn't use the product but their acceptance is the point of a SOC 2 MVP.

| Impact (HOW) | Candidate Deliverables (WHAT) |
|---|---|
| Accepts the exported evidence without asking for a manual re-pull | • Evidence export with timestamps + source provenance |

---

## The MVP prune

The full map above lists ~18 candidate deliverables. The map is a *menu*, not a
commitment. Pruning to KR-2's MVP:

**Step 1 — rank actors by leverage.** KR-2 is about trial teams *connecting sources* and
*surfacing a gap*. The two primary actors (Data Steward, Compliance Officer) sit directly
on that metric. IT Security is a real blocker but is addressed with documents, not build
work. The auditor is off-stage for *this* Key Result (it's about the 30-minute trial
moment, not audit acceptance) — defer that whole branch.

**Step 2 — rank impacts within the priority actors.** The two load-bearing behavior
changes are "connects all sources in the first session" (Data Steward) and "discovers
first gap live in the session" (Compliance Officer). The "briefs the CISO" and "shows a
colleague" impacts are valuable but not on KR-2's 30-minute path — defer.

**Step 3 — minimum deliverable set for the priority impacts:**

| Selected deliverable | Causes which impact | Priority |
|---|---|---|
| Guided onboarding wizard (< 5 min per source) | Data Steward connects all sources in first session | Must |
| One-click Google Drive OAuth connector | " | Must |
| One-click S3 connector (IAM paste) | " | Must |
| In-app progress meter | " (nudges completion) | Should |
| First-run scan surfacing highest-severity gap | Compliance Officer discovers first gap live | Must |
| Gap card (file + violated control) | " | Must |
| Copy-paste least-privilege IAM policy | IT grants access without a ticket cycle (unblocks the wizard) | Should |
| Least-privilege access one-pager | IT Security approves without escalating | Should |

Everything else — coverage summary, honesty panel, CISO briefing link, PDF evidence
pack, auditor provenance export, "sort by control" view, email nudge — becomes **deferred
backlog**, each already traced to an impact and a goal, so re-prioritizing it for KR-1 or
KR-3 later is nearly free.

**Why the cut is legitimate:** the selected set is the *smallest* group of deliverables
that would plausibly cause the two priority behavior changes for the two priority actors.
If a cheap prototype showed the wizard alone gets teams to connect all sources, the
per-source connectors above the first could themselves be deferred — deliverables are
droppable hypotheses right up until evidence says otherwise.

---

## How this map feeds the rest of the pipeline

- **Back to `okr-authoring`:** the map is a sanity check on the Key Result. If no actor's
  behavior change plausibly moves KR-2's number, the KR was mis-set — the map surfaces
  that *before* any epic is written.
- **Into `epic-definition`:** each *selected* WHAT deliverable becomes a candidate epic
  (e.g., "Guided onboarding wizard" → an epic), carrying its impact as the epic's
  justification.
- **Into `moscow-prioritization`:** the Must/Should marks above are the first pass;
  MoSCoW binning uses the map as the forcing function — a deliverable can only be a
  *Must* if it causes a *Must-move* impact.
- **Into `story-mapping`:** the selected deliverables become activities along the story
  map's backbone. The "connect a source → see coverage → surface a gap" narrative is the
  spine; the MVP cut above is essentially the **walking skeleton** (Patton, crediting
  Cockburn) — the thinnest end-to-end path that actually works, connect-through-to-first-
  gap, however rough. The deferred deliverables become lower release slices under that
  backbone.

The chain is unbroken: KR-2 (goal) → Data Steward / Compliance Officer (actors) →
"connects all sources" / "discovers first gap live" (impacts) → the eight selected
deliverables (MVP) → epics → stories → a story-map walking skeleton. Every leaf traces
to the number the strategy is trying to move.
