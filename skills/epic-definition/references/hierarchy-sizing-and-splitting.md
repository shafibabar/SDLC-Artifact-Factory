# Hierarchy, Sizing and Splitting Epics

Self-contained reference for `epic-definition`. Read it when deciding whether a piece of work is a theme, an epic, a story or a task; when an epic has more than 10 stories, a component name or more than one Bounded Context; and before writing an epic's decomposition. It does not teach story-level splitting patterns: those live in `user-story-writing`.

Grounded in Mike Cohn, *User Stories Applied* (epic as an unsplit story, themes, splitting); Jeff Patton with Peter Economy, *User Story Mapping* (backbone, walking skeleton); and the DSDM Agile Project Framework (priority decomposition).

---

## 1. The four levels

| Level | Definition in this plugin | Size | Acceptance criteria | Where the idea comes from |
|---|---|---|---|---|
| **Theme** | The roadmap Theme: a customer problem, in the customer's words, that a roadmap row names (`roadmap-authoring`). Epics are grouped under it when a roadmap exists | A roadmap horizon or more | None; the roadmap owns it | Cohn uses "theme" as a light grouping above stories and epics for release reporting. This plugin reuses the roadmap's Theme instead of inventing a second grouping label |
| **Epic** | One coherent outcome for a user class, needing 3–10 stories | S / M / L by story count | 3–5 high-level conditions, each with a concrete example | Cohn: a story too big to plan yet. The hypothesis, traces, four-risk line and Bounded Context are this plugin's additions |
| **Story** | One user-visible behaviour an agent can build and verify against its own acceptance criteria | One build-and-verify unit | Given/When/Then from the example map (`acceptance-criteria`) | Cohn and Bill Wake's INVEST, owned by `user-story-writing` |
| **Task** | A technical step inside a story | Part of a story | None | General agile practice |

**Patton's bridge.** A story map has activities, then **backbone tasks**, then stories. Patton's vocabulary has no "epic"; his backbone tasks are the pre-decomposition form of one. So epics become backbone candidates on the story map, and their story titles become the body beneath them. The **walking skeleton** (the thinnest end-to-end path across the whole backbone, a term Patton credits to Alistair Cockburn) is decided on the map by `story-mapping`, never on the epic list.

**Cohn's divergence, stated plainly.** Cohn's epic carries no hypothesis, no OKR link and no Bounded Context. This plugin adds them because the epic is the last artifact that holds the *why* next to the *what*. When writing about epics, do not attribute the hypothesis or traces to Cohn.

---

## 2. Size for an agent-built product

The pipeline has no sprints and no person-week estimates: agents build the product. "Too big for one sprint" and "finishable in a quarter" therefore have no input here. Size is read from the decomposition instead, which an agent can count and `moscow-prioritization` can use as a relative weight.

| Signal | Verdict | Action |
|---|---|---|
| One user-visible behaviour; one set of acceptance criteria can confirm it | **Story** | Write it with `user-story-writing`; no epic |
| One outcome; 3–4 story titles | **Epic, size S** | Define it |
| One outcome; 5–7 story titles | **Epic, size M** | Define it |
| One outcome; 8–10 story titles | **Epic, size L** | Define it; check whether two outcomes are hiding inside |
| More than 10 story titles | **Too big** | Split into epics (section 3) |
| Exactly one story | **Not an epic** | Promote the story; no epic wrapper |
| "Done" is indistinguishable from the whole product | **The everything epic** | Split by outcome until each can fail on its own |
| A story cannot be sized until something is investigated | **+spike** | Add a spike story title and mark the size, e.g. "M +spike" |
| The outcome touches two or more Bounded Contexts | **Architectural concern** | Split by outcome first, then flag what still crosses (section 4) |

The size is relative and structural. Never convert it to person-weeks, story points or days. If `moscow-prioritization` reports a Must share by weight at enterprise scale, it maps S/M/L to weights itself and labels the figure as approximate.

---

## 3. Splitting an epic into epics

Split when an epic is over 10 stories, has two outcomes in its title ("and"), or is the everything epic. Each resulting epic must be able to **succeed or fail on its own**: if one half's hypothesis can only be judged once the other ships, they are one epic.

| Split by | Use when | Example |
|---|---|---|
| **Outcome** | The title joins two results | "Patients confirm or cancel, and slots are refilled" → "front desk knows who is still coming" + "a freed slot is refilled from the waitlist" |
| **User class** | Two user classes reach the outcome differently | Applicant sees the checklist; validation officer sees what was already checked |
| **Selected deliverable** | One epic was carrying two deliverables from the map | SOL-1 and SOL-2 each get their own epic |
| **Tenant or segment** | Each tenant or segment has its own go-live, data or rules | One transition epic per council moving off a legacy system |
| **New capability vs transition** | Migration, parallel run, training or decommission is bundled with the new behaviour | "Officers see the validation report" + "council A's open cases continue without loss" |

**Never split by technical layer** (frontend / backend / database) **or by service.** "One epic per microservice" is the layer-cake split at a larger scale: each piece delivers nothing a user can observe, and none has a hypothesis that could fail.

---

## 4. The cross-context epic

An epic whose outcome needs two or more Bounded Contexts (tenant onboarding that touches identity, billing and the data plane, for example) is a design signal, not a filing problem.

1. **Split by outcome first.** Ask what the user class gets from each part: "staff of a new tenant can sign in and see only their tenant", "the tenant is billed from its first day", "the tenant's existing records are available on day one". Each outcome usually lands mostly in one context.
2. **Name one primary context per resulting epic.**
3. **Flag what still crosses.** Record, in the epic list's cross-context table, which epics still need more than one context and why. The domain-modeler decides in Design whether that means a missing context, a Context Map relationship or an Anti-Corruption Layer. The requirements-analyst identifies candidates; it never defines Bounded Contexts.

Do not "fix" a cross-context epic by splitting it per context. That hides the coupling the domain-modeler needs to see.

---

## 5. From epic to story titles

At epic time, write **titles only**, outcome-named, in the order the user meets them (left to right on the future story map). Use `user-story-writing`'s splitting patterns to find them: workflow step, business rule, data variation, paths, interfaces, CRUD, defer the hard part, spike. SPIDR (Spike, Paths, Interfaces, Data, Rules) is Mike Cohn's later Mountain Goat Software material, not *User Stories Applied*; cite it that way if at all.

Rules that hold at this level:

- Every title is a user-visible outcome. "Build the estate endpoint" or "add the cases table" is a task.
- Each user requirement the epic carries is covered by at least one title. Note the UR-n beside the title when it is not obvious.
- Do not mark which titles are the walking skeleton or which are Must: `story-mapping` and `moscow-prioritization` decide that. DSDM's rule applies later: when an epic's priority is finalised as Must, its stories are judged one by one, and some will be Should or Could.
- Do not write story bodies or Given/When/Then.
