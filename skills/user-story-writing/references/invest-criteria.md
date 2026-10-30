# INVEST Criteria — In Depth

Self-contained reference for `user-story-writing`. Read it when a story is borderline on any INVEST letter, when reviewing someone else's stories, and before writing stories when no personas exist yet (role brainstorming, at the end).

INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable) was coined by Bill Wake and made the central quality rubric of Mike Cohn's *User Stories Applied*. The format (`As a / I want / so that`) is necessary but not sufficient: two stories with identical structure can differ enormously in quality. INVEST is what separates them.

Two letters are adapted for this plugin, where AI agents build the product and there are no sprints, story points or person-week estimates: **Small** and **Estimable** are judged by structure and by examples, never by time.

---

## I — Independent

**Means.** The story can be built and delivered without waiting for another in-flight story. Independence is scheduling freedom.

**Test.** "If this were built next, before its siblings, would it be blocked?" Watch for hidden ordering: a story that assumes data another story creates, or a screen another story builds.

**Fix.**
- **Reorder and record it.** If the dependency is real, note it on the story ("ordering: after US-8, which creates loans") so planning respects it. Do not hide it inside the card.
- **Re-split.** Often the coupling comes from a layer split. Cut each story as a thin end-to-end slice instead, so each delivers something on its own.

Perfect independence is not always possible; minimise coupling, and never pretend it is absent.

## N — Negotiable

**Means.** The story states a need, not a chosen solution; the "how" stays open for the conversation. Cohn calls this the letter most often lost: a story is a placeholder for a requirement, not the requirement itself.

**Test.** "Does the card dictate an implementation?" Words like *endpoint*, *dropdown*, *PATCH*, *table*, *modal*, *webhook* or a vendor name are the signal.

**Fix.** Rewrite as the need. A genuine constraint (a contract mandates the council's own sign-in, a regulator mandates retention) is cited as a constraint (CON-n, BR-n) beside the card, not written as the design.

## V — Valuable

**Means.** A named user, or the paying customer, is observably better off. "Refactor the auth module" is work, not a story.

**Test — the "so what?" test** (this plugin's house rule). Ask "so what?" of the benefit until it names a change in the user's world:
- "so that I can export the report" → *so what?* → "so that I can hand the auditor evidence without rebuilding it by hand". Now it is valuable.
- "so that the system stores the data" → *so what?* → no user-facing answer. Not a story.

**Fix.** With no user-facing value, escalate rather than write it. It may be a task inside a valuable story (put it there), or an enabler (track it as such, never disguised as a story).

## E — Estimable

**Means.** Its size can be judged at all. Not precisely: there are no estimates in this pipeline. Inability to judge it signals one of two things: it is too **vague**, or too **large**.

**Test.** Ken Pugh (*Lean-Agile Acceptance Test-Driven Development*): a story is not understood well enough to size until at least one concrete example of it working can be written. Try to write the **seed example**: names, numbers, the outcome. If none will come, the story fails E.

**Fix.**
- **Too vague** → clarify the need with the user, or carve out a **spike**: a bounded investigation answering one named question, whose output is a decision note, not software. The original story becomes estimable once the spike lands.
- **Too large** → split it (`story-splitting-patterns.md`).

## S — Small

**Means.** One user-visible behaviour that an agent can build and verify against its own acceptance criteria in one pass. Cohn's "epic" is simply a story too big for that; in this plugin an epic is a richer construct (`epic-definition`), but the test for a story is the same.

**Signals it is too big.**
- The want joins verbs ("connect, configure and monitor"), or the title has "and".
- More than about five to seven distinct conditions of satisfaction appear when you list them.
- It serves several personas or user classes in different ways.
- It must honour several business rules, data sources or interfaces at once.
- It carries both the common case and a hard case (very large volumes, recovery after failure).

**Fix.** Split before writing it down (`story-splitting-patterns.md`). Do not leave an oversized story "to be split during build".

## T — Testable

**Means.** Done-ness is objectively checkable. "The dashboard should be intuitive" is not testable; "a steward finds every overdue loan on the Friday list without scrolling past a returned one" is.

**Test.** "Could at least one concrete example pass or fail unambiguously?" Quality words (*better*, *faster*, *seamless*, *intuitive*) with no condition are the tell. A number that is really a quality target (a response time, an uptime) belongs to `nfr-specification`; the story cites the NFR ID.

**Fix.** Write the seed example. If none can be written, the need is not understood: return to the conversation. The full criteria are written later in `acceptance-criteria`, from the example map. Testable and Estimable reinforce each other.

---

## The Fail-and-Fix Summary

| Fails | Symptom | Fix |
|---|---|---|
| Independent | "US-A must land first" | Record the ordering, or re-split into end-to-end slices |
| Negotiable | The card names an implementation | Rewrite as a need; cite real constraints beside it |
| Valuable | "so what?" finds no user change | Escalate; a task or an enabler, not a story |
| Estimable | No seed example will come | Spike (vague) or split (large) |
| Small | Several verbs, rules, sources or user classes | Split (splitting patterns) |
| Testable | Success is a matter of opinion | Write one concrete example; cite NFRs for numbers |

---

## Anti-Pattern Catalogue

| Anti-pattern | Example | Why it fails | Letter |
|---|---|---|---|
| **Persona-free story** | "As a user, I want to…" | Which user? No persona or role | (format) |
| **System as actor** | "As the scheduler, I want to send reminders…" | Systems have no wants; a task | Valuable |
| **Solution story** | "…I want a REST endpoint that returns JSON…" | The how, not the need | Negotiable |
| **Circular "so that"** | "…export a CSV so that I can export the data." | Restates the want | Valuable |
| **Benefit-free story** | "As a steward, I want to export a report." | Value unstated | Valuable |
| **The novel** | Twenty lines of UI detail on the card | The conversation has been frozen into text | Negotiable |
| **Epic masquerading as a story** | Fifteen conditions, three personas | Too big to build and verify in one pass | Small / Estimable |
| **Task masquerading as a story** | "Set up the database schema" | No user, no user value | Valuable |
| **Untestable quality story** | "…the app to be fast." | No pass/fail; a quality target belongs in the NFRs | Testable |
| **MoSCoW on the card** | "Priority: Must" at writing time | MoSCoW (or the lean block) finalises priority last | (traceability) |

The two most common and damaging are the **circular "so that"** and the **task masquerading as a story**.

---

## Role Brainstorming (when no persona exists yet)

Cohn's technique predates persona-driven design. When `user-persona` has not produced personas, generate the "As a ___" list mechanically:

1. **List** every distinct way someone interacts with the product.
2. **Consolidate** near-duplicates into one role.
3. **Organise** the survivors along an axis that changes behaviour: novice vs expert, frequent vs occasional, internal vs external, own tenant vs another tenant.

A **user role** is lighter than a **persona**: enough to write and sanity-check a story's actor before persona depth exists. Role brainstorming is also how a disfavoured user class (another tenant's staff, an anonymous visitor) surfaces before anyone asks for it; access stories come from those. Once personas exist, replace each role name with the persona (P-n). Which roles a product has is that product's business: no role is mandatory for every product.
