# Story-Splitting Patterns

Self-contained reference for `user-story-writing`, the single home of the story-level splitting catalogue in this plugin. Read it before splitting any story, and whenever a story fails INVEST's **Small** or **Estimable**. Splitting an *epic into epics* (by outcome, user class, deliverable, tenant, or new capability vs transition) is `epic-definition`'s job; it points here once an epic is being turned into stories.

**Sources.** Mike Cohn, *User Stories Applied*: workflow step, business-rule variation, data boundary, CRUD operation, deferring performance or robustness, spikes, and simple vs complex. **SPIDR** (Spike, Paths, Interfaces, Data, Rules) is Cohn's later Mountain Goat Software material, not *User Stories Applied*; credit it that way. "Verb before noun" is this plugin's house rule.

---

## The golden rule: every child is an end-to-end slice

Each child story must still be **Independent, Valuable and Testable on its own**: a thin slice through every layer the behaviour needs (screen, logic, storage, message), which a named user can see working. Splitting by architectural layer ("the database story, then the API story, then the UI story") breaks this: no layer delivers value alone, and none can be accepted by a user. Those are **tasks** inside a story.

A naming note: this kind of cut is often called a "vertical slice" through the architecture. That is different from the story map's **vertical-slice MVP** anti-pattern (`story-mapping`), which means finishing one activity of the journey while the rest waits. Both rules point the same way: thin and end to end.

---

## The patterns

### Verb before noun (house rule)
When the want joins actions ("connect, configure and monitor a source"), split by the verb first: *connect*, *configure*, *monitor*. Only then ask whether any one of them needs a finer data or rule split. Decomposing the compound action first usually yields stories that are each clearly valuable.

### Workflow step (Cohn)
A multi-step process becomes one story per step the user can see: "review and approve a change" → *see the pending change* · *comment on it* · *approve or reject it*. Each step is independently demonstrable. If a step is only meaningful with the next, keep them together.

### Business-rule variation (Cohn; SPIDR Rules)
When behaviour differs by business rule, tier or policy, write one story per rule instead of conditional logic inside one story: "apply the loan rules" → *a loan is due after 7 days (BR-1)* · *a member 7+ days overdue cannot borrow (BR-2)* · *a steward extends once (BR-1)*. In a multi-tenant product, **per-tenant policy** is a rules split: one story for the rule mechanism with the first tenant's policy, then a story per genuinely different policy, never a story per tenant that repeats the same behaviour.

### Data boundary (Cohn; SPIDR Data)
One story per data type, source or format the behaviour handles: "import bookings" → *from the practice's CSV export* · *from a paper diary checklist*. Ship the most common source first.

### CRUD operation (Cohn)
When a story bundles create, read, update and delete for one entity, split each operation into its own story, not just "read vs write": "manage retention policies" → *create* · *view* · *edit* · *delete*. Create and read usually deliver value first; update and delete often wait, and sometimes a workaround (delete and re-create) covers them for a release.

### Paths: happy path first (SPIDR Paths)
The success path is the first story; each alternate or error path is its own follow-on: *patient confirms or cancels by reply* first, then *front desk sees replies that were not understood*, then *a reply after the cut-off*. This is usually the single most effective shrink.

### Interfaces (SPIDR Interfaces)
When the same capability is reached through several interfaces (web, phone, an API) or by several user classes with different views (officer, applicant, public), one interface or class proves the capability and each other becomes a story. Access for **disfavoured user classes** (another tenant's staff, an anonymous visitor) is a story of its own, at the step where they would meet the data.

### Simple then complex; defer performance and robustness (Cohn)
Ship the common case, defer the rare or hard one, even if a stakeholder asked for the hard version by default: *scan a folder* before *scan 1M+ files and resume after a failure*. A quality target (time, volume, uptime) is not split out as a story: it is an NFR the later story cites.

### Spike (Cohn; SPIDR Spike)
When nobody can say what a story involves (an unfamiliar external system, an unknown data shape), carve out a **spike**: one named question, a bounded investigation, and an output that is a decision note, not shippable software. Write it as `US-n Spike: <question>` with the story it unblocks; the blocked story notes "waits on US-n". Agents have no time boxes in days, so bound the spike by its question and its output.

---

## Choosing a pattern

| The story is too big because… | Reach for |
|---|---|
| It joins several verbs | Verb before noun |
| It is a multi-step workflow | Workflow step |
| It enforces several rules, tiers or tenant policies | Business-rule variation |
| It handles many data types or sources | Data boundary |
| It does all of CRUD on one entity | CRUD operation |
| It has a happy path plus error paths | Paths, happy path first |
| Several interfaces or user classes reach it | Interfaces |
| The hard or large case blocks the common case | Simple then complex |
| Nobody can say what it involves | Spike |

Most oversized stories admit several valid splits. **Prefer the split whose children are each independently valuable.** A split that produces a child no user cares about (a pure infrastructure slice) is the wrong split; try another pattern.

---

## Bad splits

| Bad split | Why | Instead |
|---|---|---|
| By layer: UI / API / database | Nothing a user can accept | End-to-end slices by path, rule or data |
| By service or team | The layer split at service scale | By outcome or rule; teams follow Design's Bounded Contexts |
| By tenant, when tenants behave identically | Duplicate stories that differ only by name | One story; split only where policy or data differs |
| "Part 1 / part 2" of the same behaviour | Neither half is testable alone | Find the path or rule that divides it |
| Happy path in one story, all "edge cases" in another | The second is a grab-bag of unrelated paths | One story per path |
| A spike that ships code | A spike's output is knowledge | Decision note; the follow-on story ships |

After a split, re-run INVEST on every child, trace each to the same epic, UR and job story as the parent (or the narrower FR it now carries), and keep the parent title only as the epic's story title if the epic list used it.
