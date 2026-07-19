---
name: ux-flow-design
description: >
  Teaches how to design user flows — the step-by-step paths a user takes through
  the product to complete a job-to-be-done. Covers flow types (happy path,
  error path, edge case path), flow notation, entry and exit points, decision
  nodes, and the connection between user flows and acceptance criteria. User flows
  are the primary input to the frontend-engineer's screen and component design.
  Produced by the ux-architect agent during the Design phase.
version: 1.1.0
phase: design
owner: ux-architect
created: 2026-06-25
tags: [design, ux, user-flow, happy-path, interaction-design]
---

# UX Flow Design

## Purpose

A user flow is the complete sequence of steps a user takes to accomplish a single job-to-be-done. User flows bridge the gap between the requirements-analyst's Job Stories and the frontend-engineer's screen implementations. They make explicit every decision point, every error state, and every system response — before any screen is designed.

Every Job Story from the Ideate phase maps to at least one user flow. A Job Story with multiple paths maps to multiple flows.

---

## Flow Types

| Type | When to produce | What it covers |
|---|---|---|
| **Happy path flow** | Always — first flow for every job | The ideal sequence with no errors, no branching, no edge cases |
| **Error path flow** | For every validation, network call, and permission check | What happens when something fails; how the user recovers |
| **Edge case flow** | When business rules create unusual but valid scenarios | Empty states, first-time use, single-item lists, maximum limits |
| **Onboarding flow** | For all first-use and account setup scenarios | What a new user experiences before reaching the core product |

---

## Flow Notation

User flows are written as numbered step sequences with branching notation. ASCII diagrams are used for clarity — no diagramming tool required.

### Step types

| Symbol | Meaning |
|---|---|
| `[Screen]` | A screen or page the user sees |
| `(Action)` | An action the user takes |
| `{Decision}` | A system decision point — routes to different paths |
| `<System>` | A system action invisible to the user (API call, validation, etc.) |
| `→` | Flow continues to next step |
| `↳` | Branch — alternative path from the preceding decision |

### Example: Classify a Data Asset (Happy Path)

```
[Data Asset List Screen]
  → (User clicks "Classify" on an asset)
  → [Classification Modal opens]
  → (User selects sensitivity level: Public / Internal / Confidential / Restricted)
  → (User clicks "Save Classification")
  → <System validates: sensitivity level is set>
  → <System calls PATCH /v1/data-assets/{id}/classification>
  → {API response?}
    ↳ 200 OK → [Modal closes] → [Asset row updates with new classification badge]
    ↳ 401 Unauthorized → [Error path: authentication-expired]
    ↳ 403 Forbidden → [Error path: insufficient-permissions]
    ↳ 404 Not Found → [Error path: asset-no-longer-available]
    ↳ 409 Conflict → [Error path: concurrent-classification]
    ↳ 422 Unprocessable → [Inline validation error shown in modal]
    ↳ 500 Server Error → [Error path: system-error]
```

---

## Flow Anatomy

Every flow must define:

### 1. Entry Points
Where does the user start this flow? List all entry points — there may be more than one.

```
Entry points for "Classify Data Asset":
- Data Asset List → "Classify" action button on a row
- Data Asset Detail Screen → "Classify" button in the header
- Bulk Action toolbar → "Classify Selected" (multiple assets)
```

### 2. Preconditions
What must be true before the user can start this flow?

```
Preconditions:
- User is authenticated (valid JWT)
- User has permission: data-assets:classify
- At least one data asset exists in the tenant
```

### 3. Exit Points
How does the flow end? List all terminal states — both successful and failure.

```
Exit points:
- Success: Asset classified; user sees updated list
- Failure: Session expired; user redirected to login
- Abandon: User clicks Cancel; modal closes; no change
```

### 4. Decision Nodes
Every branch in a flow is a decision. Name every decision node and list its possible outcomes.

```
Decision: API response
- 200 → success path
- 401 → session expired path
- 403 → no permission path
- 404 → asset no longer available (deleted since the list loaded, or not visible
        to this tenant — the API deliberately does not distinguish the two)
- 409 → concurrent change path (someone else classified the asset first —
        show the refreshed value and ask the user to confirm or abandon)
- 422 → validation error path (recoverable — user corrects and resubmits)
- 5xx → system error path (unrecoverable — user must retry later)
```

---

## Connecting Flows to Acceptance Criteria

Every branch in a user flow should trace to a Gherkin scenario from the `acceptance-criteria` skill. The flow reveals all the scenarios that need to be written.

| Flow branch | Gherkin scenario |
|---|---|
| Happy path: classification saved | `Scenario: Successfully classify a data asset` |
| Error path: 401 | `Scenario: Session expires during classification` |
| Error path: 403 | `Scenario: User without classify permission attempts classification` |
| Error path: 422 | `Scenario: Invalid sensitivity level submitted` |
| Edge case: bulk classify | `Scenario: Classify multiple assets simultaneously` |

If a flow branch has no corresponding Gherkin scenario, write the scenario — the flow has identified a gap in the acceptance criteria.

---

## Empty States and First-Use Flows

Every list screen, dashboard, and data view needs an empty state flow. Empty states are not error states — they are valid states with distinct UX requirements.

```
[Data Asset List — Empty State]
  → User has no data assets yet
  → [Empty state screen: illustration + headline + CTA]
     Headline: "No data assets found"
     Body: "Connect a data source to start mapping your data estate."
     CTA: "Connect a source" → [Connect Source flow]
```

Rules for empty states:
- Never show a blank screen — always show a message and a next action
- The CTA must lead somewhere actionable
- Empty state copy uses plain language — no technical jargon

---

## Flow Inventory

Before designing individual screens, produce a complete flow inventory. The flow inventory lists every job-to-be-done and the flows required to support it.

| Job Story ID | Job description | Flows required |
|---|---|---|
| JS-001 | Scan a data source | happy-path, source-unavailable, auth-error, partial-scan |
| JS-002 | Classify a data asset | happy-path, no-permission, session-expired, validation-error, bulk-classify |
| JS-003 | View a compliance gap report | happy-path, no-reports-yet, report-generating |

The flow inventory is complete when every Job Story from the requirements-analyst's output has at least one flow.

---

## Handoff to Frontend Engineer

The UX flow design handoff package contains:
- Flow inventory (all jobs mapped to flows)
- Individual flow diagrams (ASCII notation) for every flow
- Entry/exit/precondition documentation per flow
- Empty state specifications
- Acceptance criteria gap list (flows that revealed missing scenarios)

The frontend-engineer uses these flows as the authoritative spec for which screens to build, in what order, and what each screen must handle.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All Job Stories covered | Every JS-NNN maps to at least one flow | Job Stories with no corresponding flow |
| All branches documented | Every decision node shows all outcomes | Decision nodes with "happy path only" |
| Error paths present | Every API call has at least an error path | Flows that assume all API calls succeed |
| Empty states covered | Every list or collection view has an empty state flow | Screens with no empty state specification |
| Acceptance criteria mapped | Every flow branch maps to a Gherkin scenario | Branches with no corresponding scenario |
| Entry points complete | All ways to enter a flow are listed | Single entry point assumed without checking |
| Abandon paths defined | Every flow states what Cancel/Escape/back does to in-progress work | Abandonment behaviour left to the implementer |

---

## Anti-Patterns

- **Happy-path-only flows.** A flow whose every API call succeeds. Real usage hits expired sessions, missing permissions, deleted records, and concurrent edits — a flow without those branches is a storyboard, not a spec.
- **Errors that dead-end.** An error state with no recovery action. Every error path ends in one of three things: a retry, a corrective action, or a clearly signposted exit. "Something went wrong" with no next step is a flow design failure, not a copywriting one.
- **Undefined abandonment.** No statement of what Cancel, Escape, or the browser back button does mid-flow — especially in multi-step wizards where partial work exists. Abandon is an exit point and must be specified like one.
- **Screens before flows.** Designing the Classification Modal's layout before the flow reveals it needs a conflict state, a permission-denied state, and a not-found state. Flows determine what screens must handle; screens designed first get retrofitted badly.
- **Decision nodes hidden in prose.** "The system handles errors appropriately" instead of an enumerated decision node. If the outcomes are not listed, the frontend-engineer will discover them in production.
- **Flows without Gherkin traceability.** Branches that map to no scenario, and scenarios that map to no branch. The two artifacts validate each other; a gap on either side is a defect in one of them.
- **Treating empty as error.** Routing a new tenant's empty Data Asset list to an error screen. Empty is a valid, expected state with its own flow — a first-use moment, not a failure.
- **Client-side permission guessing.** A flow that hides the Classify action based on UI-cached role data but never specifies the 403 path. The UI may pre-emptively hide actions, but the flow must still define what happens when the API says no.

---

## Output Format

```markdown
---
name: ux-flow-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: ux-architect
---

# UX Flow Design

## Flow Inventory
| Job Story ID | Job description | Flows |
|---|---|---|

## Flow: [Flow Name]

**Entry points:** [list]
**Preconditions:** [list]
**Exit points:** [list]

[ASCII flow diagram]

### Decision nodes
| Decision | Outcomes |
|---|---|

### Acceptance criteria mapping
| Branch | Gherkin scenario |
|---|---|
```
