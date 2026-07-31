# Flow Notation and Types — Reference

Comprehensive reference for the three UX flow artifacts (task flow, user flow,
wireflow), the ASCII notation this repo uses for all three, decision-point
modeling, loops and back-navigation, and the cross-fragment hand-off notation for
this product's microfrontend architecture.

The `SKILL.md` body summarizes when to pick each type. This file is the full
grammar and the worked diagrams.

---

## 1. The Three Flow Types in Depth

All three are the same underlying idea — a directed graph of screens and actions —
at three levels of branching and fidelity. They are not competing formats; they
are a progression you climb as a job gets more complex.

### 1.1 Task flow — one linear path

A **task flow** is a single, unbranched sequence: one start, a straight run of
steps, one end. Every user who performs the task takes exactly this route. There
are no decision diamonds, because nothing forks. It is the lightest artifact and
the right one for genuinely linear jobs.

Real-practice lineage: the "task flow" vs "user flow" distinction is standard IA/
interaction-design vocabulary — a task flow charts *one* route through a task; a
user flow charts the *branching* set of routes different users or conditions take.

Use a task flow for: log in, rename an asset, accept an invitation, toggle a
setting. Worked example (renaming a data source label):

```
(( Start: Data Source list ))
  → [ Source row ]
  → ( User clicks "Rename" )
  → [ Inline edit field, focused ]
  → ( User types new label, presses Enter )
  → < PATCH /v1/sources/{id} >
  → [ Row shows new label ]
(( End ))
```

If you find yourself wanting to add an `↳` branch to a task flow, that is the
signal to promote it to a user flow — the job forks, and a task flow can no longer
honestly represent it.

### 1.2 User flow — branching paths with decision points

A **user flow** adds decision nodes, alternate paths, loops, and back-navigation.
It represents *every* route through the job, not just one — the happy path plus
each fork created by a permission, a validation result, an API outcome, or a user
choice. This is the workhorse artifact; most real jobs in this product are user
flows because almost every job touches an API call that can fail and a permission
that can be denied.

A user flow's defining feature is the `{decision}` node with **all** its outcomes
enumerated (Section 3). Worked example: Section 5.

### 1.3 Wireflow — user flow annotated with low-fidelity screen sketches

A **wireflow** (Nielsen Norman Group's term for the wireframe + flow hybrid) is a
user flow whose nodes carry rough, low-fidelity screen sketches instead of just a
label. Each `[ screen ]` node is drawn as a small wireframe box showing gross
layout — regions, primary action placement, key content — not pixels, colors, or
final copy. The arrows still carry the flow logic; the sketches carry just enough
layout to review the *transition* between screens.

Reach for a wireflow only when the screen-to-screen transition is itself the risk:
a multi-step wizard where users lose their place, a novel navigation pattern, or a
journey that crosses microfrontend fragment boundaries (Section 4) where two
separately-built remotes must present a continuous experience. For conventional
screens where the branching — not the layout — is what needs review, a wireflow is
wasted fidelity that ages badly the moment layout changes. Keep the sketches
deliberately crude (boxes and labels) so reviewers critique flow, not visual
design that has not happened yet.

### 1.4 Choosing — a decision aid

| Question | If yes | If no |
|---|---|---|
| Does the job ever fork on a decision, permission, or API outcome? | Not a task flow | Task flow is enough |
| Is the risk in *what happens when it forks*? | User flow | — |
| Is the risk in *how screens lay out and transition*? | Wireflow | User flow |
| Does the job cross a fragment boundary? | Lean toward wireflow at the seam | — |

Default path: start as a task flow, promote to a user flow the instant a decision
appears (almost always), and escalate the specific risky stretch — not the whole
flow — to a wireflow only if transitions need review.

---

## 2. Notation Grammar

All three types share one ASCII grammar so Shafi reviews them as plain Markdown
with no diagramming tool (consistent with this repo's `event-storming-facilitation`
and the "reviewable without IDE tooling" rule).

| Symbol | Node kind | Meaning | Example |
|---|---|---|---|
| `(( ))` | Start / end | Terminal point | `(( Start: Estate list ))` |
| `[ ]` | Screen / state | A screen, or a named state of one | `[ Classification modal ]` |
| `< >` | System action | Invisible work the user does not see | `< PATCH /v1/data-assets/{id} >` |
| `{ }` | Decision | A branch point | `{ API response? }` |
| `→` | Action arrow | Flow continues to next node | `[ Modal ] → ( Save )` |
| `↳` | Branch | An alternate path leaving a decision | `↳ 403 → [ Permission-denied ]` |
| `( )` | User action | Something the user does | `( User selects a level )` |
| `⟿ HAND-OFF` | Fragment seam | Control crosses to another remote (Section 4) | `⟿ HAND-OFF → classification remote` |

Conventions:

- **One node per line, one arrow per line** where a branch fans out — never bury
  multiple outcomes on one line, because that is where enumerated outcomes get
  silently dropped.
- **Name every state, not just every screen.** `[ Estate list — empty ]` and
  `[ Estate list — loaded ]` are two nodes, not one, because they are two things
  the `frontend-engineer` builds.
- **System actions are visible in the flow.** Put the API call as a `< >` node so
  its failure modes have somewhere to branch from — a hidden call has no place to
  attach a `{ }` error decision.

---

## 3. Decision-Point Modeling

A `{decision}` node is where a user flow earns its keep. The rule: **every
decision enumerates all outcomes, and every outcome has a destination.** A
decision with one arrow out is a happy path wearing a diamond.

For an API-response decision in this product, the canonical outcome set is:

```
{ API response? }
  ↳ 200 OK          → [ success state ]
  ↳ 401 Unauthorized → [ session-expired path ]
  ↳ 403 Forbidden    → [ permission-denied path ]
  ↳ 404 Not Found    → [ no-longer-available path ]
  ↳ 409 Conflict     → [ concurrent-change path ]
  ↳ 422 Unprocessable→ [ inline validation error ]
  ↳ 5xx Server error → [ system-error path ]
```

Each outcome carries a design obligation (see `references/states-and-edge-cases.md`
for the full recovery specification):

| Outcome | Meaning here | Recovery |
|---|---|---|
| 401 | JWT expired mid-flow | Re-authenticate, then resume where possible |
| 403 | Missing capability (e.g. `data-assets:classify`) | Signpost who can grant it; do not dead-end |
| 404 | Deleted since list loaded, or not visible to tenant (API does not distinguish) | Refresh the list; explain the row is gone |
| 409 | Someone changed it first | Show the refreshed value; ask confirm or abandon |
| 422 | Invalid input | Inline error; user corrects and resubmits (recoverable) |
| 5xx | System fault | Retry-with-backoff; escalate if persistent (unrecoverable by user) |

Non-API decisions (user choices, business-rule branches) follow the same
enumerate-all-outcomes rule — a "Sensitivity level?" decision must list every
level's route if they differ.

---

## 4. Loops, Back-Navigation, and Abandonment

Real flows are not one-way. Model these explicitly:

- **Loops** — a validation-error branch (422) loops back to the same input screen:
  `[ Modal ] → < validate > → { valid? } ↳ no → [ Modal, with inline error ] → ...`
  Draw the loop arrow; do not leave "user tries again" to the reader's imagination.
- **Back-navigation** — for any multi-step flow, state what the Back control does
  at each step: return to the previous step with entered data preserved, or
  discard it. Silent back behavior is a defect in wizards where partial work
  exists.
- **Abandonment** — Cancel, Escape, and browser-back are exit points and must be
  specified like any other exit: what happens to in-progress work? Every flow
  states this once. "Cancel discards the draft classification; the asset row is
  unchanged" is a complete abandon spec; leaving it to the implementer is not.

---

## 5. Cross-Fragment Hand-Off Notation

This product's frontend is a microfrontend: a **shell** hosting independently
deployable **remotes** (fragments). A user flow routinely spans more than one
remote, and each remote is a separate deploy pipeline. The single most common
place a cross-fragment flow silently breaks is the seam where control passes from
one remote to another, because three things must be handed across it:

1. **Shared state** — the selected estate / asset context the next remote needs.
2. **Deep-link URL** — the route the shell owns, so refresh and back work.
3. **Permission context** — the capabilities the next remote must re-check
   (never trust the previous remote's UI-level gating).

Mark every such crossing with an explicit **hand-off node** — `⟿ HAND-OFF → <remote>`
— and annotate what crosses. An unmarked seam is a defect: the flow reads as one
app while two separately-deployed remotes must actually agree on a contract there.

Worked cross-remote example — a Data Steward moving from browsing an estate to
classifying an asset to viewing compliance, across three remotes hosted by the
shell:

```
(( Start: shell — global nav ))
  → [ estate-browser remote: Estate tree ]
  → ( User opens an asset )
  → [ estate-browser remote: Asset detail ]
  → ( User clicks "Classify" )
  ⟿ HAND-OFF → classification remote
       carries: { tenantId, assetId }  (shared state)
       deep-link: /classify/{assetId}  (shell-owned route)
       re-checks: data-assets:classify  (permission context)
  → [ classification remote: Classify modal ]
  → ( User sets level, saves )
  → < PATCH /v1/data-assets/{assetId}/classification >
  → { API response? }  (enumerate outcomes per Section 3)
  ↳ 200 → [ classification remote: saved ]
        → ( User clicks "View compliance impact" )
        ⟿ HAND-OFF → compliance remote
             carries: { tenantId, assetId, newLevel }
             deep-link: /compliance/asset/{assetId}
             re-checks: compliance:read
        → [ compliance remote: Gap view for this asset ]
        (( End ))
  ↳ 403 → [ classification remote: permission-denied ]  (see states reference)
```

Notes on the seam:

- The hand-off is where a wireflow (Section 1.3) most earns its cost — sketching
  the last screen of the source remote next to the first screen of the target
  remote is how you catch a jarring visual or context discontinuity two teams
  would otherwise ship independently.
- Each remote **re-checks** permission server-side; the flow must show the target
  remote's own `{ permission? }` decision, not assume the source remote's gating
  carried across. A flow that hides the classify action in the estate-browser
  remote but never specifies the 403 path inside the classification remote is the
  "client-side permission guessing" anti-pattern.
- If shared state does not survive the seam (e.g. a hard navigation drops it), the
  target remote lands in its own empty/error state — which must exist in the
  screen/state inventory for that remote.

---

## 6. Traceability

Every branch a flow reveals should map to a Gherkin scenario in `acceptance-criteria`.
The flow is the discovery instrument: if a `{decision}` outcome has no scenario,
the flow has found a gap in the acceptance criteria — write the scenario. If a
scenario has no branch, either the flow is incomplete or the scenario is dead.
The two artifacts validate each other; a gap on either side is a defect in one.
