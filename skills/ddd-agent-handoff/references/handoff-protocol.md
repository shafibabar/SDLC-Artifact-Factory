# DDD Handoff Protocol

Full protocol for how DDD work hands off between this plugin's agents. This
file is self-contained — loadable without reading `SKILL.md` first, since
agents may consult it directly. It assumes only that you know the 11 agents
that touch DDD work (domain-modeler, enterprise-architect, data-architect,
data-engineer, backend-engineer, security-architect, security-engineer,
platform-engineer, ux-architect, frontend-engineer, test-strategist) and
that `SKILL.md`'s Agent Boundary Matrix is the lookup table for which one
owns a given concern.

---

## Handoff Record Schema

Every handoff between two agents is recorded using
`assets/handoff-record-template.md`. The schema is one common structure for
every pairing — auditability requires a consistent shape — but which fields
are *required* versus optional depends on the interaction mode (below).

| Field | Purpose |
|---|---|
| `from_agent` / `to_agent` | Who is handing off to whom |
| `concern` | The specific piece of DDD work changing hands (name it precisely — "Aggregate boundary for Order" not "domain modeling") |
| `interaction_mode` | `collaboration` \| `x-as-a-service` \| `facilitating` — see below |
| `subdomain_classification` | `core` \| `supporting` \| `generic` — from `subdomain-distillation`; the primary input to mode selection |
| `status` | `in-progress` \| `blocked` \| `abandoned` \| `completed` |
| `resumption_type` | `operational-pause` \| `breakthrough-triggered-refactor` — only set when `status` reflects an interruption; see Resumption below |
| `artifacts_produced` | What was actually produced so far, with paths |
| `open_questions` | Unresolved items the next agent (or a resumed session) must see |
| `roster` | Every agent currently party to this handoff, with a join history if the roster changed mid-session |
| `dates` | Created, last updated |

## The Three Interaction Modes

From Team Topologies, applied to agent-to-agent DDD handoffs:

- **Collaboration** — iterative, back-and-forth. Both agents actively shape
  the outcome together; neither can finish alone. Used when the work is
  genuinely joint (e.g. security-architect and domain-modeler jointly
  deciding how a PII-bearing Aggregate's invariants interact with an access
  policy).
- **X-as-a-Service** — one-directional. The producing agent finishes an
  artifact to a Definition of Done; the consuming agent takes it as a
  finished input and doesn't need to renegotiate it. Used when the artifact
  is stable and the boundary is well-understood (e.g. backend-engineer
  consuming a finished Aggregate design from domain-modeler).
- **Facilitating** — guidance transfer, no artifact ownership change. One
  agent helps another get unstuck or apply a standard correctly, without
  taking over the work. Used when the concern is really a capability gap,
  not a boundary question (e.g. test-strategist facilitating BDD feature
  file conventions to backend-engineer, who still owns and writes the
  tests).

## Mode Selection Criteria

Apply in this order. This is a selection table — *applying* it to a specific
task is the acting agent's job, not something this skill decides for you.

1. **Subdomain classification (primary signal)** — from `subdomain-distillation`:
   - **Core Domain** → default to **Collaboration**, regardless of how
     stable or familiar the pairing seems. Core Domain work deserves the
     deepest joint effort every time; a "routine" Core Domain handoff is
     still worth the collaboration cost.
   - **Generic Subdomain** → default to **X-as-a-Service**, or skip the
     cross-agent DDD process entirely if the subdomain is genuinely being
     bought/adopted rather than modeled.
   - **Supporting Subdomain** → use the secondary signals below to decide
     between Collaboration and X-as-a-Service.
2. **Secondary signals** (for Supporting Subdomain, or to sanity-check a
   Core/Generic default):
   - **Artifact stability** — still evolving → Collaboration; finished and
     stable → X-as-a-Service.
   - **Regulatory/PII sensitivity** — present → lean Collaboration even if
     otherwise stable (compliance risk from a misunderstood handoff is
     rarely worth the X-as-a-Service savings).
   - **Pairing history** — first time these two agents have handed off this
     kind of concern → lean Collaboration; well-established, repeated
     pairing → X-as-a-Service is usually safe.
   - **Cross-Bounded-Context ambiguity** — the concern spans an unclear or
     disputed Bounded Context boundary → Collaboration (resolve the
     ambiguity jointly before treating it as a stable handoff).

## Definition of Done Per Stage

A handoff should not begin until the producing agent's stage meets its DoD.
Sequencing follows each agent's own declared phase order.

| Stage | Producing agent | Definition of Done |
|---|---|---|
| Strategic design | domain-modeler | Subdomain classification recorded (`subdomain-distillation`); Bounded Contexts named with a Context Map covering every inter-context relationship referenced downstream |
| Tactical modeling | domain-modeler | Aggregates, invariants, and Domain Events identified for every Bounded Context in scope; Ubiquitous Language terms registered in `glossary-management` |
| Architecture | enterprise-architect / data-architect | Service decomposition, CQRS split, and physical/canonical data model all trace back to a named Bounded Context and Aggregate — no orphaned architecture decisions |
| Implementation | backend-engineer / frontend-engineer / platform-engineer | Code implements the Aggregate/event contract exactly as designed, with no undocumented deviation; deviations are handed back as a Collaboration item, not silently implemented |
| Verification | test-strategist / security-engineer | Tests bind to Aggregates and Domain Events (not incidental implementation details); compliance checks cover every Bounded Context flagged with regulatory sensitivity |

## Mode Transition Protocol

A handoff's mode can change mid-session. Trigger signs and how to record
the change:

- **Escalate X-as-a-Service → Collaboration** when the consuming agent
  repeatedly finds ambiguity the producing agent must resolve jointly (more
  than one round of "this doesn't quite fit" is the trigger — don't wait
  for a third).
- **Step down Collaboration → X-as-a-Service** when a pairing has produced
  several stable handoffs in a row for the same kind of concern — continued
  Collaboration at that point is unnecessary cost, not diligence.
- **Recording**: update the handoff record's `interaction_mode` field and
  append a dated note to `open_questions` (or a new `mode_history` entry if
  the template has one) stating the trigger and which agent identified it.
  A resumed session must be able to see *why* the mode changed, not just
  that it did.

## Roster Change Protocol

When a concern surfaces mid-session that maps to a Boundary Matrix row not
yet part of the active handoff:

1. Look up the owning agent in `SKILL.md`'s Agent Boundary Matrix.
2. Add them to the handoff record's `roster` with a join entry (date, what
   triggered the addition, which concern they now own).
3. The newly added agent applies Mode Selection Criteria for their piece
   independently — joining a Collaboration-mode handoff doesn't force every
   participant into the same mode for every sub-concern.

Common trigger: a PII or cross-border data signal surfaces during what
started as a two-agent handoff (e.g. domain-modeler + backend-engineer),
requiring security-architect or a compliance concern requiring
security-engineer to join.

## Conflict Resolution / Escalation

For genuine disagreement about ownership (distinct from `SKILL.md`'s "When
Nothing Matches," which covers the case where *no* row fits — this covers
two agents both believing a row fits *them*):

1. Both agents state their claimed boundary and cite the specific Boundary
   Matrix row or Definition of Done they believe applies.
2. If the disagreement is about Bounded Context scope, domain-modeler has
   final say (Context Map ownership) — not the two agents in dispute.
3. If the disagreement is about vocabulary, `glossary-management` is the
   tiebreaker, per `SKILL.md`'s existing rule.
4. If neither resolves it, record the dispute as an `open_questions` entry
   with `status: blocked` and escalate to Shafi rather than one agent
   unilaterally proceeding.

## Resumption: Operational Pause vs. Breakthrough

Not every interruption should resume the same way:

- **`operational-pause`** — the session ended for a reason unrelated to the
  model's correctness (context limit, time-boxing, unrelated interruption).
  Resume by reading the handoff record's `artifacts_produced` and
  `open_questions` and continuing from there — no model rework implied.
- **`breakthrough-triggered-refactor`** — the interruption happened *because*
  the team realized the current model (an Aggregate boundary, a Context Map
  relationship, a subdomain classification) is wrong. Per Evans' Continuous
  Refactoring Toward Deeper Insight, the correct move is not to resume
  forward — it's to route back to domain-modeler for deliberate model
  revision before any downstream agent continues building on the old model.
  Mark this explicitly in the record; a resumed session that only checks
  `artifacts_produced` and continues forward on a `breakthrough` record is
  compounding the error, not fixing it.

See `references/handoff-worked-examples.md` for both scenarios worked in
full.

## Handoff Quality Checklist

Pass/Defect, in `methodology-review`'s style. A **defect** blocks the
handoff from being considered complete.

| Check | Pass | Defect |
|---|---|---|
| Record exists | A handoff record exists for the concern before work starts on the receiving side | Work begins on the receiving side with no handoff record |
| Mode is justified | `interaction_mode` matches what Mode Selection Criteria would recommend given the recorded `subdomain_classification` | Mode was picked without reference to subdomain classification, or contradicts it with no noted override reason |
| DoD met before handoff | The producing agent's stage meets its Definition of Done | Handoff occurs with an unmet DoD item |
| Roster changes recorded | Every agent added mid-session has a join entry | An agent is acting on the concern with no roster entry |
| Mode changes recorded | Every mode change has a dated note explaining the trigger | `interaction_mode` changed with no record of why |
| Resumption typed correctly | Every interrupted handoff has `resumption_type` set before being picked back up | A resumed session continues forward without checking whether the interruption was a breakthrough |
