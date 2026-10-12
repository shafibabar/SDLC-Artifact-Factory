# Proposal 14 — Scale each phase's output to the product (#1257)

**Status:** proposal for Shafi's decision. No code has changed.

## The problem in one paragraph

Every product gets the same artifact set, whatever its size. In the dogfood run, a lunch-order tracker for a 20-person office produced 11 Strategy documents (about 1,590 lines, **$6.40**). Ideate then stopped at the first of its 11 approval gates. The agents' quality was good; the **volume** is what makes the plugin impractical for a PM to review.

Across all 13 agents the plugin can produce about 132 kinds of output. Design alone has 35 from 5 agents, several of them repeated "per Bounded Context" or "per story". A large regulated SaaS platform needs most of them. An internal tool needs a fraction.

## Proposed design

**1. Three scale profiles, chosen at `/sdlc-start`.**

| Profile | Fits | Example |
|---|---|---|
| **lean** | Internal or single-team tool, one service, no regulated data, no multi-tenancy | The lunch-order tracker |
| **standard** | A B2B SaaS product: a few services, one region, ordinary personal data | A team-scheduling SaaS |
| **enterprise** | Multi-tenant, regulated (SOC 2 / GDPR / HIPAA), high availability, multi-region | Your Data Estate product |

`/sdlc-start` recommends a profile from the problem statement and asks the user to confirm it. The choice is stored in `sdlc-config.json` as `scale_profile`. Changing it later is a recorded decision, like any config change. These are the same three tiers each skill's `examples/` folder already climbs (simple → enterprise), so agents have a worked example at every level.

**2. One shipped file says what each phase produces at each profile:** `phase-requirements.json`. Proposal 13's phase gate reads the **required** set from the same file.

**3. The methodologies stay non-negotiable at every profile.** `lean` produces *fewer, shorter* artifacts. It never drops DDD, Event Storming, TDD, BDD or SOLID. For example, lean runs a big-picture Event Storm only, and its acceptance criteria are still Gherkin.

**4. Approval gates scale too.**

| Profile | Default approval mode |
|---|---|
| lean | **Batch:** the phase's artifacts are produced together, then reviewed once from a one-page summary table |
| standard | **Key decisions only:** 2–3 gates per phase, at the artifacts that change direction (e.g. vision, Context Map, Container Diagram); the rest are batched |
| enterprise | **Per artifact** (today's behaviour) |

The user can switch mode at any time ("review each one" / "batch the rest").

## Draft matrix: Strategy, Ideate, Design

R = required · O = on request or when a trigger applies · — = not produced (or folded into another artifact, as noted)

**Strategy** (today: 8)

| Artifact | lean | standard | enterprise |
|---|---|---|---|
| Vision statement | R | R | R |
| Mission statement | — (one line inside the vision) | R | R |
| Stakeholder map | — | R | R |
| Competitive analysis | O | R | R |
| Business model canvas | — (no business model) | R (Lean Canvas) | R |
| GTM strategy | — | R | R |
| Roadmap | R (one page) | R | R |
| OKRs | R (one objective) | R | R |
| **Count** | **3** | **8** | **8** |

**Ideate** (today: 11 requirements artifacts)

| Artifact | lean | standard | enterprise |
|---|---|---|---|
| User personas | R (1–2 proto-personas) | R | R |
| JTBD analysis | — (folded into personas) | R | R |
| Functional requirements | — (the story backlog is the requirements) | R | R |
| NFR specification | R (short) | R | R |
| Impact map | — | O | R |
| Epics | — | R | R |
| Story backlog | R (with MoSCoW inline) | R | R |
| Acceptance criteria (Gherkin) | R | R | R |
| Example maps | O | R | R |
| Story map | O | R | R |
| MoSCoW prioritisation | — (inline in backlog) | R | R |
| **Count** | **4** | **10** | **11** |

**Design** (today: 35)

| Group | lean | standard | enterprise |
|---|---|---|---|
| Domain (Event Storming, Ubiquitous Language, Context Map, Aggregates, Domain Events, Commands, Read Models, domain stories) | Event Storm (big picture), Ubiquitous Language, Context Map (may be one context), and **one** domain-model document covering aggregates, events, commands and read models | All, per Bounded Context | All, per Bounded Context |
| Architecture (system context, containers, components, ADRs, principles, API contract, integration, multi-tenancy, summary) | System context, container diagram, API contract, ADRs that pass the risk gate, summary | + component diagrams, integration design (O), multi-tenancy (O) | All |
| UX (journeys, IA, flows, component specs) | Flows | All | All |
| Data (model, canonical model, event schema, pipeline, classification, lineage, retention) | Data model; retention (O) | + event schema, classification, retention; pipeline and lineage (O) | All |
| Security (threat model, zero trust, security architecture, access control, secrets, privacy, compliance) | Threat model (STRIDE-lite), access control, secrets (short); privacy if personal data | + security architecture, privacy; zero trust and compliance (O) | All; compliance required if regulated |
| **Approximate count** | **~14** | **~28** | **~35+** |

Implement through Customer Validation produce mostly **code, tests and config**, which already scale with the number of services. The same file would still mark platform extras (service mesh, multi-region, chaos testing) as `—` for lean and `O` for standard. The full matrix for those phases gets drafted during implementation.

**Expected effect for the lunch tracker:** Strategy drops from 11 artifacts / $6.40 to 3 artifacts / about $2, with one review instead of 11 gates.

## Decisions for Shafi

| # | Decision | Recommendation |
|---|---|---|
| 1 | Profiles | **Three:** lean / standard / enterprise |
| 2 | How the profile is chosen | **Recommended by `/sdlc-start` from the problem statement, confirmed by the user, changeable later as a recorded decision** |
| 3 | Methodologies under lean | **Kept, in lighter form; never dropped** (the alternative relaxes CLAUDE.md's non-negotiables for small products) |
| 4 | Approval mode per profile | **Batch / key decisions / per artifact**, as above; the user can switch at any time |
| 5 | The matrix | **Approve the draft above** (or mark changes); Implement → Customer Validation rows to follow in the PR |

## Size and order

- One shipped `phase-requirements.json`, plus a check that every artifact it names exists in the catalog.
- A `scale_profile` field in the `sdlc-config` schema.
- `/sdlc-start` question.
- Each phase command reads the profile.
- Each agent's execution sequence says "produce what `phase-requirements.json` lists for this profile".

It shares the requirements file with proposal 13. Recommended order: **13 first**, with today's full set as the only profile, **then 14**. That way the phase gate and approvals work before the matrix changes what is required.
