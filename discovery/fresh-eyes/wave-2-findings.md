# Wave 2 Findings: Domain-Modeling and Architecture Skills (issue #1377, parent #1376)

- **Scope:** 24 skills plus one new skill. Domain-modeling (13): aggregate-design, bounded-context-mapping, command-catalog, context-map-patterns, cqrs-pattern, ddd-agent-handoff, domain-event-catalog, domain-storytelling, event-schema-design, event-storming-facilitation, read-model-design, subdomain-distillation, ubiquitous-language. Architecture (11): api-contract-design, api-gateway-design, component-diagram, container-diagram, event-driven-patterns, grpc-contract-design, integration-design, message-broker-selection, multi-tenancy-design, system-context-diagram, workflow-orchestration. New (D045): `architecture-evaluation`.
- **Read:** every `SKILL.md` in full; reference, asset and script files in full where a finding depends on them, otherwise by heading and targeted search (see "What I could not finish or verify"). The exemplars `skills/adr-authoring/`, `skills/vision-statement/` and `evals/adr-authoring/`; `skills/skill-authoring-standards/SKILL.md`; `discovery/fresh-eyes/wave-1-findings.md` (format); decisions D045 and D046; `agents/domain-modeler.md`, `agents/enterprise-architect.md` and the `skills:` lists of every agent; `skills/artifact-manifest/resources/phase-requirements.json` (Design phase); all three files in `research/domain-driven-design/`; in `research/software-architecture/` the Bass, Clements, Fairbanks, Richards & Ford, Hard Parts, Newman, Richardson, both Kleppmann, Geewax, Lane, gRPC, Roy, Xu and Clean Architecture files; `research/devops-and-delivery/api-gateway-patterns.md`; and every other research line that names a Wave 2 skill (found by search; 216 lines in 49 files).
- **Layout linter:** `python3 scripts/lint-skill-layout.py --skill <name>` reports findings for **4 skills**, all rule L5 (repo-rooted path): domain-event-catalog (1), domain-storytelling (3), event-schema-design (1), subdomain-distillation (1, inside its `description`). The other 20 are clean, because their non-body files sit in `references/` or `assets/`, which the linter accepts. As in Wave 1, the linter does not catch mixed files or templates filed under `assets/`.
- **Structure validator:** `bash scripts/validate-skill-structure.sh` passes 19 skills. It fails the 4 lint skills above, and `integration-design` (body 204 lines, threshold 200). `api-contract-design` is at 199.
- **Evals:** none of the 24 has an `evals/` suite; all 24 still have `tests/skills/<name>.contract.sh`.
- **No edits outside `discovery/fresh-eyes/`.** Nothing committed.

---

## Narrative: what I found

**1. Nothing is declared as grounding, and the strategic half of DDD has no research behind it.** None of the 24 skills has a `sources:` field. Most name authors in prose (Evans, Vernon and Khononov in 11 skills; Ford in 5; Kleppmann in 4; Newman in 4). Several name books that are **not** in `research/`: Brandolini (event-storming-facilitation, ubiquitous-language), Hofer & Schwentner (domain-storytelling), Kaiser and Lilienthal & Schwentner (subdomain-distillation), Simon Brown (all three C4 skills), Greg Young (cqrs-pattern), Hohpe (workflow-orchestration) and Team Topologies (ddd-agent-handoff). Under `skill-authoring-standards/SKILL.md:80` these must trace to a research file or be dropped.

The bigger gap: the three DDD research files are about **tactical** design only. Each says so. Evans: "This document deliberately does not re-derive Bounded Context / Context Map depth" (`domain-driven-design-evans.md:93`). Khononov: "This book's substantial strategic-design content (Bounded Context discovery workshops, Context Mapping patterns, Event Storming facilitation…) is intentionally not covered here" (`learning-ddd-khononov.md:83`, also `:79`). So bounded-context-mapping, context-map-patterns, event-storming-facilitation, domain-storytelling and ubiquitous-language have no research grounding beyond lines that "confirm" them. Event Storming and DDD are two of the five non-negotiable methodologies.

The research files' "Applies To" tables are also stale, as in Wave 1: `grpc-up-and-running.md:31` says grpc-contract-design "Does not yet exist"; `microservices-patterns-richardson.md:30` says workflow-orchestration is "not yet built"; `rabbitmq-in-depth-roy.md:29` calls message-broker-selection "new in Phase 2"; `api-gateway-patterns.md:30` says the gateway skill is "to be created"; `fundamentals-of-software-architecture-richards-ford.md:26` still speaks of the NFR skill's "8 categories".

**2. The same concept is taught in two or more places with different answers.** This is the Wave 2 version of the pilot's "positioning taught as vision". The biggest:

- **Event versioning.** `domain-event-catalog/SKILL.md:62,116-117` versions events with a `.v1` suffix and a semver major bump run in parallel. `event-schema-design/SKILL.md:113-123,149` forbids the version suffix ("`DataAssetClassified.v2` is not a type") and requires a new event type instead.
- **Event envelope.** `event-schema-design/SKILL.md:39-46` makes CloudEvents 1.0 "the mandatory envelope… This is not optional". `domain-event-catalog/references/event-format.md:110` says "This repo's envelope is not a formal CloudEvents implementation" and defines its own camelCase envelope. Event type names follow three schemes: `[Aggregate][PastTenseVerb]` (`domain-event-catalog/SKILL.md:158`), `com.caizin.classification-engine.DataAssetClassified` (`event-format.md:115`) and `com.sdlc-factory.<bc>.<aggregate>.<verb>` (`event-schema-design/SKILL.md:55,137`). The schema skill also lists `datacontenttype` as one of "five required" CloudEvents attributes (`:44-52`); CloudEvents 1.0 requires four (`id`, `source`, `specversion`, `type`) and `datacontenttype` is optional.
- **When to orchestrate.** `event-driven-patterns/SKILL.md:43-47` sends "any multi-step distributed business process with compensations" to an orchestrator. `workflow-orchestration/SKILL.md:37,44` says orchestration is "the deliberate exception to the choreography+Saga default" and fires on compensation only when undo spans "4+ services". Richardson's file sides with the second (`microservices-patterns-richardson.md:20`). Both skills also teach the Saga step classes, the pivot and the "orchestrator doing the work" anti-pattern.
- **How to read across models.** `cqrs-pattern/SKILL.md:41,45` makes the Simple Read Model (a query-time join through a read-side type) the legitimate default, citing Khononov (`learning-ddd-khononov.md:23`). `read-model-design/SKILL.md:44,91` says "no JOINs at read time" and lists "Querying the Write Model for reads" as an unconditional anti-pattern. `workflow-orchestration/SKILL.md:98` makes API Composition the default for cross-service queries. Three skills, three defaults.
- **Competing Consumers** means a Kafka consumer group in `event-driven-patterns/SKILL.md:63` and the opposite of a consumer group in `message-broker-selection/SKILL.md:58` (Roy agrees with the second, `rabbitmq-in-depth-roy.md:39`).
- **Context Map patterns** are taught in full by both `bounded-context-mapping/SKILL.md:92-121` and `context-map-patterns/SKILL.md:65-93`. They disagree on tight co-evolution (Shared Kernel "as last resort" at `bounded-context-mapping:121`; "Shared Kernel (small) or Partnership" at `context-map-patterns:91`) and on which relationships need Consumer-Driven Contracts (Customer/Supplier only at `bounded-context-mapping:133`; Customer/Supplier and OHS at `context-map-patterns:112`).
- **Transactional Outbox, CDC, DLQ and the idempotent consumer** are taught in at least five Wave 2 skills (`domain-event-catalog/references/outbox-and-cdc.md`, 371 lines; `event-driven-patterns`; `cqrs-pattern/references/go-implementation.md`; `aggregate-design/references/go-implementation-patterns.md`; `integration-design:119-129`) plus `go-event-publisher` and `go-repository-pattern`.
- **Service decomposition** is taught by the domain-modeler's skill (`bounded-context-mapping/references/service-decomposition.md`: "One Bounded Context equals one deployable microservice") although `agents/domain-modeler.md:76` says it does not own service decomposition, and `container-diagram` (enterprise-architect) has its own "Deciding Service Boundaries" table.
- **"CDC" means two things in one table.** `integration-design/SKILL.md:166-167` uses "CDC" for Change Data Capture in one quality criterion and for Consumer-Driven Contract in the next.

**3. Phase and ownership are confused, and four skills are never loaded.**

- `api-gateway-design`, `grpc-contract-design`, `message-broker-selection` and `workflow-orchestration` appear in **no** agent's `skills:` list and in no run order. They are never preloaded.
- `cqrs-pattern` has three owners: its frontmatter says `owner: backend-engineer`, `phase: implement` (`:13`); only `enterprise-architect` preloads it; `ddd-agent-handoff`'s matrix routes "architecture-level CQRS" to enterprise-architect. The order is also inverted: the domain-modeler designs Read Models at step 11 (`agents/domain-modeler.md:164`) before the enterprise-architect decides whether CQRS applies at step 7 of its own run (`agents/enterprise-architect.md:156`), which starts after the domain-modeler finishes.
- `event-schema-design` says `owner: domain-modeler`, but its artifact is owned by data-architect (`phase-requirements.json:675`), only data-architect preloads it, and the handoff matrix routes it there.
- `subdomain-distillation` says it runs "early in the Design phase, before Bounded Contexts are modeled" and is "the primary input" to handoff mode selection (`:10-14`). It is in none of: the domain-modeler's Owns list (`agents/domain-modeler.md:65-72`), its run order (`:148-164`), its outputs table, or `phase-requirements.json`.
- The lean profile requires one `domain-model` document (`phase-requirements.json:416`). No skill produces it (`generated/catalog.json` has no producer).
- The enterprise-architect designs multi-tenancy at step 4, after the container diagram (`agents/enterprise-architect.md:149,153`), although the tenancy model decides the deployment topology. Step 4 is labelled "physical isolation architecture".
- Nine Design-phase reference files carry Go implementation code (`aggregate-design/references/go-implementation-patterns.md` alone is 777 lines with 15 Go blocks), overlapping the backend-engineer's `go-*` skills and ignoring that the tech stack can be overridden in `sdlc-config.json`.

**4. The first product leaks into defaults, trigger surfaces and one company name.** Wave 1's pattern repeats. Every worked example is the data-estate / compliance product. Worse:

- `multi-tenancy-design/SKILL.md:49`: "This repo's default is physical isolation (the stamp model)", justified by the first product. Its `description` (`:11`) says the skill is "grounded in this repo's SOC 2 physical-isolation product context". `:47` calls the stamp "the only model that satisfies SOC 2 physical-isolation controls"; SOC 2 has no such control (the commitment was the first product's own).
- `domain-event-catalog` references contain a real company name, `caizin`, in 6 lines (`event-format.md:115,119` and others).
- `bounded-context-mapping/SKILL.md:96`: ACL is the "Default for all external integrations in this platform (Google Drive, AWS S3, Office 365)".
- `message-broker-selection/SKILL.md:30` justifies Redpanda as "the right default for a data-estate/compliance" product; `workflow-orchestration/SKILL.md:48` says the coordinator is "deployed per-tenant like everything else"; `cqrs-pattern/SKILL.md:137` applies Full CQRS to "this plugin's first product"; `subdomain-distillation/SKILL.md:96-114` puts the first product's classification in the body.

**5. Workshops without people.** Event Storming and Domain Storytelling are written as human workshops. `event-storming-facilitation/references/facilitation-guide.md:16-20` makes domain experts mandatory; its own anti-pattern table lists "Facilitator writes all the cards" and "Storming without a domain expert: every card is a guess" (`:157-158`). The domain-storytelling guide needs a narrator (`references/facilitation-guide.md:15`). In this plugin the domain-modeler agent always writes every card, alone, from the Ideate artifacts. The skills' own anti-patterns describe the pipeline's only mode. This is the Wave 1 "simulated interview" defect (W1-18) at Design scale.

**6. The C4 skills are internally sound but inconsistent with each other.** `container-diagram` already absorbed Clements' split between a runtime (C&C) view and a deployment (allocation) view, but sends deployment placement to "`deployment-diagram` / `platform-engineer`" (`:65-66`). That skill does not exist. `component-diagram/SKILL.md:52-62` says skip the diagram when a service follows the default skeleton; `phase-requirements.json:503` requires one per service at standard and enterprise. The context diagram treats ASCII as the primary presentation and Mermaid as a convenience (`system-context-diagram/references/diagram-template-and-example.md:27,187`); the container and component templates are Mermaid only (`container-diagram/references/runtime-topology-and-template.md:87`, `component-diagram/references/diagram-template.md:91`). The container table calls Redpanda a "Shared broker" (`:81`) while multi-tenancy requires a dedicated broker per tenant; a real deployment view would hold that difference. C4 itself is unsourced (Clements calls it a narrowed profile of its C&C viewpoint, `documenting-software-architectures-clements.md:58`).

**7. Sync vs async guidance is mostly consistent; the gaps are scale and trust.** All skills agree that asynchronous Domain Events are the default across Bounded Contexts (`integration-design:53-57`, `event-driven-patterns:47`). But:

- `integration-design:74-90,163` makes the full stack (timeout, retry, breaker, bulkhead, fallback) mandatory for every synchronous call at every scale. Fairbanks' risk-driven model (`just-enough-software-architecture-fairbanks.md:10,24`) would size it to the risk.
- The one-BC-one-service default and Redpanda for every product take no account of profile. Hard Parts' granularity integrators (`software-architecture-hard-parts-ford.md:11,20`) and Richards & Ford's style selection (`fundamentals…richards-ford.md:10,23`) argue the other way for small products; Vernon's in-process publisher (`implementing-ddd-vernon.md:18`) covers events inside one deployable. No Wave 2 skill mentions lean / standard / enterprise.
- `api-gateway-design/SKILL.md:46-48` says "downstream services trust an already-authenticated request". `zero-trust-design/SKILL.md:29` says no actor is implicitly trusted.

**8. A real gap: nothing checks the design against the NFRs.** `nfr-specification` now writes quality-attribute scenarios, ranks them and hands over candidate trade-off points (`nfr-specification/SKILL.md:8-11,62`). The enterprise-architect reads that handoff first and then never evaluates its design against it. Bass supplies the method (`software-architecture-in-practice-bass.md:34-41,68,91`). This is the new `architecture-evaluation` skill (scope below).

**What is good.** `aggregate-design` has already absorbed Evans, Vernon and Khononov in depth (business-logic-pattern gate, true-invariant test, identity and concurrency, event sourcing). `container-diagram` and `component-diagram` already apply Clements. `api-contract-design` already applies Geewax and Lane. `workflow-orchestration` matches Richardson closely. These need folder work, sources and examples, not rewrites.

**Size counts:** S = 7, M = 13, L = 4 (plus the new skill, M).

---

## Findings table

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact H/M/L | Effort S/M/L | Confidence |
|---|---|---|---|---|---|---|---|---|
| W2-1 | depth | All 24 `SKILL.md` frontmatter (no `sources:`); author names in prose, e.g. `aggregate-design/SKILL.md:3-16` | No skill declares `sources:`; eight cited books have no research file | Add `sources:` per the per-skill lists; source or drop each unsourced attribution | docs | M | S | High |
| W2-2 | depth | `domain-driven-design-evans.md:93`; `learning-ddd-khononov.md:79,83` | DDD research covers tactical design only; strategic design (BC discovery, context mapping, Event Storming) explicitly excluded | A strategic-design research pass from the books already held (Evans Part IV, Vernon, Khononov Part I) before the strategic skills are rebuilt | new-reference | H | M | High |
| W2-3 | depth | `domain-event-catalog/SKILL.md:62,116-117` vs `event-schema-design/SKILL.md:113-123,149` | Two contradictory breaking-change rules (`.vN` + semver vs new type, suffix banned) | One rule, owned by `event-schema-design`; catalog points to it (Decision 1) | bug | H | S | High |
| W2-4 | depth | `event-schema-design/SKILL.md:39-46,55`; `domain-event-catalog/references/event-format.md:110,115`; `domain-event-catalog/SKILL.md:158` | CloudEvents "mandatory" vs "not a formal CloudEvents implementation"; three type-naming schemes | One envelope and one naming scheme (Decision 1) | bug | H | S | High |
| W2-5 | depth | `event-schema-design/SKILL.md:44-52,136` | Lists `datacontenttype` as one of five required CloudEvents attributes; the spec requires four | Fix the list; add the CloudEvents 1.0 spec (free) as a reference note | bug | M | S | High (spec, not research) |
| W2-6 | depth | `event-driven-patterns/SKILL.md:43-47` vs `workflow-orchestration/SKILL.md:37,44`; `microservices-patterns-richardson.md:20` | Contradictory orchestration triggers; Saga step classes taught twice | `workflow-orchestration` owns orchestration; `event-driven-patterns` keeps a one-row pointer and Richardson's rule (Decision 3) | bug | M | S | High |
| W2-7 | depth | `cqrs-pattern/SKILL.md:41,45`; `read-model-design/SKILL.md:44,91`; `workflow-orchestration/SKILL.md:98`; `learning-ddd-khononov.md:23` | Three different read-side defaults | One escalation ladder in `cqrs-pattern` (Decision 4) | bug | H | S | High |
| W2-8 | depth | `event-driven-patterns/SKILL.md:63` vs `message-broker-selection/SKILL.md:58`; `rabbitmq-in-depth-roy.md:39` | Competing Consumers defined two opposite ways | Use the queue sense (Roy); call the Kafka shape "consumer group" | bug | M | S | High |
| W2-9 | maintainability | `bounded-context-mapping/SKILL.md:92-121,133` vs `context-map-patterns/SKILL.md:65-93,112` | Pattern catalogue taught twice with different rules | `context-map-patterns` owns the catalogue and selection; `bounded-context-mapping` owns discovery, BC definition and drawing the map (Decision 5) | merge/delete | M | S | High |
| W2-10 | maintainability | `domain-event-catalog/references/outbox-and-cdc.md`; `event-driven-patterns/references/go-implementation.md`; `cqrs-pattern/references/go-implementation.md`; `aggregate-design/references/go-implementation-patterns.md`; `integration-design/SKILL.md:119-129` | Outbox / CDC / DLQ / idempotent consumer taught in 5+ places | Design-level home `event-driven-patterns`; code home `go-event-publisher` / `go-event-consumer`; others point | merge/delete | M | M | High |
| W2-11 | depth | `bounded-context-mapping/references/service-decomposition.md` (one BC = one service); `agents/domain-modeler.md:76`; `container-diagram/SKILL.md` "Deciding Service Boundaries" | Service decomposition taught by the agent that does not own it, with a fixed default | Move to `container-diagram`; replace the default with granularity integrators / disintegrators (Hard Parts `:10-11,20`) and profile (Decision 6) | bug | H | M | High |
| W2-12 | depth | `integration-design/SKILL.md:166-167` | "CDC" means Change Data Capture and Consumer-Driven Contract in adjacent rows | Never abbreviate Consumer-Driven Contract as CDC; spell it out | bug | M | S | High |
| W2-13 | usage | Agents' `skills:` lists (none contain these four); `agents/enterprise-architect.md:145-162` | `api-gateway-design`, `grpc-contract-design`, `message-broker-selection`, `workflow-orchestration` never preloaded or sequenced | Add them to owning agents and run orders (Decision 11) | process | H | S | High |
| W2-14 | depth | `cqrs-pattern/SKILL.md:13`; `agents/enterprise-architect.md:156`; `agents/domain-modeler.md:164`; `ddd-agent-handoff/SKILL.md` matrix | Three owners; CQRS decided after Read Models are designed | `owner: enterprise-architect`, `phase: design`; decide CQRS before Read Model design (Decision 4) | bug | M | S | High |
| W2-15 | depth | `event-schema-design/SKILL.md` frontmatter; `phase-requirements.json:675`; handoff matrix | Owner domain-modeler, artifact owned by data-architect | Split semantics (catalog, domain-modeler) from serialization (schema, data-architect) (Decision 2) | bug | M | S | High |
| W2-16 | process | `subdomain-distillation/SKILL.md:10-14`; `agents/domain-modeler.md:65-72,148-164`; `phase-requirements.json` (absent) | Classification has no step, no owner entry, no artifact | Add a step after Event Storming Big Picture; register `subdomain-classification` (Decision 14) | process | H | S | High |
| W2-17 | process | `phase-requirements.json:416`; `generated/catalog.json` | Lean `domain-model` document has no producing skill or template | Give it a template (in `aggregate-design` or a shared domain-modeling template) and a skill that produces it | process | M | S | High |
| W2-18 | process | `agents/enterprise-architect.md:149,153` | Multi-tenancy designed after the container diagram; step hard-labelled "physical isolation" | Run tenancy before the container diagram's deployment view; neutral label (Decision 7) | process | M | S | High |
| W2-19 | portability | `multi-tenancy-design/SKILL.md:11,47,49` | Plugin-wide physical-isolation default from the first product; SOC 2 claim is wrong | No default; model chosen from NFR and compliance input; the SOC 2 case becomes one example (Decision 7) | bug | H | M | High |
| W2-20 | portability | `domain-event-catalog/references/event-format.md:115,119`; `outbox-and-cdc.md` (2 lines); `versioning-and-retention.md` (1 line) | A real company name (`caizin`) in 6 lines | Replace with a neutral placeholder (`com.example`) | bug | M | S | High |
| W2-21 | portability | `bounded-context-mapping/SKILL.md:96,115`; `subdomain-distillation/SKILL.md:96-114`; `message-broker-selection/SKILL.md:30`; `workflow-orchestration/SKILL.md:48`; `cqrs-pattern/SKILL.md:137`; every worked example | First product in defaults and every example | Generic rules in the body; examples across several products and scales | portability | H | M | High |
| W2-22 | depth | `event-storming-facilitation/references/facilitation-guide.md:16-20,157-158`; `domain-storytelling/references/facilitation-guide.md:15-16`; `agents/domain-modeler.md:148-152` | Workshops need experts; the agent runs them alone; the skills' anti-patterns describe the pipeline | Add an agent-run mode: derived from named upstream artifacts, cards labelled as assumptions, hotspots become questions for the product owner at the gate (Decision 8) | bug | H | M | High |
| W2-23 | depth | `container-diagram/SKILL.md:65-66`; `ls skills` (no `deployment-diagram`) | Points to a skill that does not exist | Put a deployment view section and template inside `container-diagram` (Clements `:42` says no new skill) (Decision 13) | bug | M | S | High |
| W2-24 | process | `component-diagram/SKILL.md:52-62` vs `phase-requirements.json:503` | Skill says skip default services; manifest requires one per service | Manifest: required only for services that depart from the default skeleton (Decision 13) | bug | M | S | High |
| W2-25 | maintainability | `system-context-diagram/references/diagram-template-and-example.md:27,187`; `container-diagram/references/runtime-topology-and-template.md:87`; `component-diagram/references/diagram-template.md:91` | ASCII primary at L1, Mermaid-only at L2/L3 | One rule for all three (Decision 13) | bug | L | S | High |
| W2-26 | depth | Three C4 skills cite Simon Brown; `documenting-software-architectures-clements.md:58` | C4 notation unsourced | Short research note from the free c4model.com material | new-reference | M | S | High |
| W2-27 | depth | `api-gateway-design/SKILL.md:46-48` vs `zero-trust-design/SKILL.md:29` | Gateway text says downstream services trust the edge | State that services still verify identity (mesh mTLS plus token claims); gateway is the first check, not the only one (Decision 12) | bug | M | S | High |
| W2-28 | portability | `api-gateway-design/SKILL.md:15,36`; `skills/sdlc-config-management/resources/tech-stack-defaults.json` (no gateway) | "Kong… because the platform names it" — it does not; skill is Deploy-phase but gateway placement is a Design decision | Gateway placement at Design (container diagram); configuration at Deploy; Kong named as an example (Decision 11) | portability | L | S | High |
| W2-29 | usage | `integration-design/SKILL.md:74-90,163`; `just-enough-software-architecture-fairbanks.md:10,24` | Full resilience stack required on every sync call at every scale | Size the stack to the call's risk and the profile; keep the full stack for cross-service calls at standard/enterprise | process | M | S | Medium |
| W2-30 | usage | `message-broker-selection/SKILL.md:30`; `implementing-ddd-vernon.md:18` | No "do we need a broker at all" question; Redpanda for every product | First question: one deployable with in-process events, or a broker; then log vs queue | process | M | S | Medium |
| W2-31 | depth | Nine Design-phase reference files with Go code (largest `aggregate-design/references/go-implementation-patterns.md`, 777 lines) | Design skills carry Implement code; overlap with `go-*` skills; stack override ignored | Move code to the `go-*` skills; design skills stay stack-neutral with a pointer (Decision 10) | merge/delete | M | M | High |
| W2-32 | depth | `cqrs-pattern/SKILL.md:68`; `subdomain-distillation` (no "Active Record") | Points to subdomain-distillation for the four business-logic patterns; they live in `aggregate-design` | Repoint to `aggregate-design` | bug | L | S | High |
| W2-33 | depth | `api-contract-design/SKILL.md:46` vs `phase-requirements.json:541` | Spec at `api/openapi.yaml` in the service repo vs `design/*/openapi.yaml` | Use the manifest path at Design; say where it is copied at Implement | bug | L | S | High |
| W2-34 | maintainability | `api-contract-design/references/output-format-template.md`; `assets/api-contract-summary-template.md` | Two copies of the summary template | One `templates/api-contract-summary.md` | merge/delete | L | S | High |
| W2-35 | maintainability | `aggregate-design/assets/aggregate-design-template.md`; `ddd-agent-handoff/assets/handoff-record-template.md`; `subdomain-distillation/assets/subdomain-classification-canvas.md` | Templates filed under `assets/` | Move to `templates/` | folder | L | S | High |
| W2-36 | usage | Lint L5 in 4 skills; `subdomain-distillation/SKILL.md:13-14` | Repo-rooted paths, one inside a trigger surface | Relative `./` pointers; no paths in descriptions | folder | L | S | High |
| W2-37 | depth | `ubiquitous-language/references/ul-discovery-and-curation.md:124,209`; `glossary-management/SKILL.md:4` | Product per-BC language "published by glossary-management", which is the plugin's own vocabulary | Decide where product terms live and what the drift hook checks (Decision 9) | bug | M | M | High |
| W2-38 | docs | `grpc-up-and-running.md:31`; `microservices-patterns-richardson.md:30`; `rabbitmq-in-depth-roy.md:29`; `api-gateway-patterns.md:30`; `fundamentals…richards-ford.md:26` | Research "Applies To" rows describe skills as unbuilt or old | Refresh these rows when the skills are rebuilt | docs | L | S | High |
| W2-39 | depth | `domain-event-catalog/SKILL.md:63` vs `:158` | Notification Event example `DataAssetUpdated` breaks the skill's own "no CRUD-only names" rule | Rename the example | bug | L | S | High |
| W2-40 | depth | `integration-design/SKILL.md:149-154` vs `:162,210` | Body inventory has no Consistency column; criteria and template require one | Add the column to the example | bug | L | S | High |
| W2-41 | depth | `domain-storytelling/SKILL.md:52-60,66-69` | "Annotated" mode and the 5–10 / 15–30 step counts have no source; as-is vs to-be is missing | Ground against Hofer & Schwentner or drop the claims | new-reference | M | S | Medium |
| W2-42 | depth | `event-storming-facilitation/SKILL.md:62-77`; `references/color-grammar-and-levels.md:84` | Colour grammar, levels and entry/exit criteria attributed to Brandolini with no research file | Brandolini research file (Missing books) | new-reference | M | S | High |
| W2-43 | description-rewrite | `subdomain-distillation/SKILL.md:3-14` (six authors); `aggregate-design/SKILL.md:3-16` (script paths); most descriptions start "Teaches…" | Descriptions are summaries, not trigger surfaces | Rewrite as "Use when…" with the request nouns and verbs; MAJOR bump | description-rewrite | M | S | High |
| W2-44 | depth | `agents/enterprise-architect.md:145-162`; `software-architecture-in-practice-bass.md:68,91` | No step checks the design against the NFR scenarios | New `architecture-evaluation` skill (scope below) | new-skill | H | M | High |
| W2-45 | depth | `fundamentals…richards-ford.md:12,33`; `component-diagram` (import fitness function only) | Fitness functions not taught anywhere as a practice | Part of `architecture-evaluation`; `component-diagram` and `container-diagram` point to it | new-reference | M | S | High |
| W2-46 | usage | No Wave 2 skill mentions a profile; `phase-requirements.json` Design entries carry lean/standard/enterprise | Nothing scales | Each skill states what it produces per profile | process | H | M | High |
| W2-47 | depth | `software-architecture-hard-parts-ford.md:33-34` | Context map and integration inventory do not record contract strictness (static coupling) | Add a contract-strictness column to the integration inventory | new-reference | L | S | Medium |
| W2-48 | depth | `multi-tenancy-design/SKILL.md:41-49`; `software-architecture-hard-parts-ford.md:51`; `just-enough…fairbanks.md:59` | Tenancy models have no research source; no hybrid (tiered) model | Golding research file (Missing books); add tiered model | new-reference | M | M | Medium |
| W2-49 | depth | `subdomain-distillation/references/classification-techniques.md:4,63-75`; `references/legacy-transformation-guidance.md:3`; `ddd-agent-handoff/SKILL.md:61` | Kaiser, Lilienthal & Schwentner and Team Topologies cited with no research file | Add files or drop the attributions (Missing books) | docs | L | S | High |
| W2-50 | usage | `integration-design` body 204 lines | Over the 200-line prompt | Move the Integration Inventory example and anti-patterns detail to `examples/` and `references/` | folder | L | S | High |

---

<!-- PER-SKILL SECTIONS FOLLOW -->
## Per-skill sections

Line references are to the skill's own files unless a path is given. "Strategic research file" means the supplement proposed in W2-2.

### ubiquitous-language

1. **Sources**
   - `research/domain-driven-design/domain-driven-design-evans.md`: Model-Driven Design, the code is the model (`:24`); Intention-Revealing Interfaces (`:18`); making implicit concepts explicit (`:23`); the "Continuous Integration" term collision to avoid (`:25`).
   - `research/domain-driven-design/learning-ddd-khononov.md`: BC boundary as a linguistic boundary, distinct from the Aggregate's transactional boundary (`:15-16`).
   - Strategic research file (W2-2) for one-language-per-context and translation at boundaries.
2. **Gaps and errors**
   - Product UL vs plugin glossary conflated (W2-37): `references/ul-discovery-and-curation.md:124` says the glossary-management artifact publishes each context's language, but `glossary-management` is the plugin's own vocabulary. The `terminology-drift-detector` hook (`SKILL.md:97`) checks the plugin glossary, so it cannot know a product's banned synonyms.
   - Brandolini is named in prose with no file (W2-1).
   - Homonym table and every example are first-product terms (`:52-55`, `:83-84`).
   - No scale rule: lean still requires one UL document per BC (`phase-requirements.json`, "One per Bounded Context").
   - Missing `related:` entries: none (complete).
   - Body 121 lines.
3. **Folder moves**
   - `references/ul-discovery-and-curation.md` is mixed (procedure + term format + lifecycle + output template at `:154`). Split: `templates/ubiquitous-language.md` (from `:154-205`), `references/discovery-and-lifecycle.md`.
   - `references/drift-detection.md` stays; it becomes the place that says what the hook can and cannot check.
   - Lint: clean.
4. **Examples**
   1. Lean internal tool (shift-swap app): one BC, 8 terms, one synonym ban ("swap" vs "trade").
   2. B2B clinic booking: two contexts where "Appointment" is a homonym (scheduling slot vs billing encounter), with the translation named.
   3. Enterprise insurer: four contexts, "Policy" meaning three things, a renaming that must reach code, API fields and Gherkin before the ban is complete.
5. **Eval ideas**
   - (a) "The billing team calls it an Invoice, the ledger team calls it a Charge. Should we pick one global term?" Trap: plain Claude picks one term. Grader checks it asks whether the meaning differs per context, and if so treats it as a homonym at a BC boundary with a translation, not a synonym to ban.
   - (b) "We banned 'file' in the glossary; the code still has `FileRecord`. Done?" Grader checks the ban is incomplete until code, API fields and tests are renamed.
6. **Overlaps**
   - `glossary-management` (artifact vs practice; Decision 9).
   - `domain-storytelling` and `event-storming-facilitation` (term discovery sources).
7. **Size:** M.

### subdomain-distillation

1. **Sources**
   - `research/domain-driven-design/domain-driven-design-evans.md`: Large-Scale Structure, Knowledge Level, Responsibility Layers (`:27`, Applies To `:56`).
   - `research/domain-driven-design/learning-ddd-khononov.md`: complexity vs strategic importance; the four business-logic patterns per subdomain (`:8-14`, `:52`).
   - `research/security/secure-by-design.md`: security-sensitive slice (already used by `references/security-sensitive-subdomains.md`).
   - `research/software-architecture/building-microservices-newman.md`: Strangler Fig execution (`:7`, `:29`).
   - Strategic research file (W2-2): Evans Part IV distillation (Core Domain, Generic Subdomains, Segregated Core).
2. **Gaps and errors**
   - Not in the pipeline (W2-16).
   - Kaiser and Lilienthal & Schwentner cited with no file (W2-49).
   - `description` names six authors and a repo path (`:3-14`; W2-36, W2-43). No `related:` field although prose names `ddd-agent-handoff`, `aggregate-design`, `bounded-context-mapping`.
   - Worked example in the body is the first product (`:96-114`; W2-21).
   - Does not point to `aggregate-design`'s business-logic-pattern gate, which consumes this classification.
   - Body 100 lines.
3. **Folder moves**
   - `assets/subdomain-classification-canvas.md` → `templates/` (W2-35).
   - The body worked example → `examples/`.
   - Lint L5: `SKILL.md:14` repo-rooted path in the description.
4. **Examples**
   1. Lean: a volunteer-rota app where everything but the rota rules is Generic.
   2. Standard: a logistics SaaS where route optimisation is Core and billing Supporting; the "hard is not Core" trap (route import parsing).
   3. Enterprise legacy: a bank's loan origination system, transformation order and Strangler Fig, with a security-sensitive slice inside a Generic identity subdomain.
5. **Eval ideas**
   - (a) "Our PDF parser is the hardest code we have, so it's Core, right?" Grader checks complexity is separated from differentiation and the parser is classified Generic or Supporting.
   - (b) "Auth is Generic, so we skip modelling it." Grader checks the security-sensitive slice still gets Core-level rigor.
6. **Overlaps**
   - `aggregate-design` (business-logic-pattern gate reads this).
   - `ddd-agent-handoff` (mode selection reads this).
   - `strategy-kernel` / `vision-statement` (what differentiates the product).
7. **Size:** M.

### event-storming-facilitation

1. **Sources**
   - Brandolini, *Introducing EventStorming* — **missing** (W2-42).
   - `research/domain-driven-design/implementing-ddd-vernon.md` and `learning-ddd-khononov.md`: two boundaries, two forces (`vernon:7-14`; `khononov:15-16`).
   - Strategic research file (W2-2).
2. **Gaps and errors**
   - Human workshop vs agent-run reality (W2-22). The anti-patterns at `references/facilitation-guide.md:157-158` describe every run.
   - Colour grammar and level criteria unsourced (W2-42).
   - Lean runs Big Picture only, timeboxed, and it "still identifies the Bounded Contexts" (`phase-requirements.json`, event-storming-big-picture note). The skill puts BC candidates at Design Level only (`:54`), so at lean there is no stated way to get them.
   - Hotspots feed an "Architecture risk register" (`:143`) that no skill produces; it should feed `architecture-evaluation` and the product owner's gate.
   - Worked session is the first product (`references/worked-session.md`).
   - Body 184 lines.
3. **Folder moves**
   - Output Format (`:166-209`) → `templates/event-storming-session.md`.
   - `references/worked-session.md` → `examples/02-…`.
   - `references/facilitation-guide.md` → split into `steps/` (one per level) only if the agent-run mode makes it long; otherwise stays.
   - Lint: clean.
4. **Examples**
   1. Lean: food-truck pre-orders, Big Picture only, two BC candidates from pivotal events.
   2. Standard: rental marketplace, Process Level for the booking-to-payout flow, with policies and an external payment system.
   3. Enterprise: multi-region claims processing, Design Level, hotspots routed to the product owner as questions, with assumptions labelled.
5. **Eval ideas**
   - (a) "Run an Event Storming for this product from these stories" (no expert). Trap: plain Claude presents invented events as facts. Grader checks events are traced to named upstream artifacts, unsupported ones are labelled assumptions, and open questions go to the product owner.
   - (b) Lean profile: grader checks Big Picture alone still yields BC candidates via pivotal events and language changes, not skipped.
   - (c) "One Aggregate per Bounded Context?" Grader checks the two-forces answer.
6. **Overlaps**
   - `domain-storytelling` (sequencing; both surface terms and boundaries).
   - `domain-event-catalog`, `aggregate-design`, `bounded-context-mapping` (consumers).
7. **Size:** L.

### domain-storytelling

1. **Sources**
   - Hofer & Schwentner, *Domain Storytelling* — **missing**.
   - `research/domain-driven-design/domain-driven-design-evans.md`: language discovery with experts (`:24`), only as context.
2. **Gaps and errors**
   - Needs a narrator (`references/facilitation-guide.md:15`); the agent has none (W2-22).
   - "Pure / annotated" modes and the step counts are unsourced; no as-is vs to-be scope (W2-41).
   - Domain stories are skipped at lean and optional above (`phase-requirements.json:342`), yet the agent always runs two at steps 1-2 (`agents/domain-modeler.md:148-149`).
   - `related:` lists `acceptance-criteria`, which the body never names.
   - Body 184 lines.
3. **Folder moves**
   - Output Format (`:158-210`) → `templates/domain-story.md`.
   - `references/worked-examples.md` → `examples/` (two files).
   - Lint L5 ×3: each reference says "Usable independently of `skills/domain-storytelling/SKILL.md`" — reword without the path.
4. **Examples**
   1. Coarse, as-is: a library's book-reservation flow.
   2. Fine, to-be: a pharmacy repeat-prescription flow with a digitalised step.
   3. Enterprise: cross-organisation customs clearance, a story per party, boundary markers between organisations.
5. **Eval ideas**
   - (a) "Draw the story with a decision diamond for approval." Grader checks it refuses flowchart shapes and runs a variation story instead.
   - (b) Agent-run case: grader checks the story is labelled as derived from named artifacts, not narrated.
6. **Overlaps**
   - `event-storming-facilitation` (order and outputs).
   - `ux-architect`'s journey maps / `user-flows` (narrative of who does what).
7. **Size:** M.

### bounded-context-mapping

1. **Sources**
   - `research/domain-driven-design/domain-driven-design-evans.md`: BC vs Aggregate granularity (`:29`).
   - `research/domain-driven-design/learning-ddd-khononov.md`: boundary hierarchy Subdomain → BC → Aggregate → service (`:16`); data ownership applied recursively (`:27`).
   - `research/software-architecture/building-microservices-newman.md`: Conway's Law (`:8,23`).
   - Strategic research file (W2-2).
2. **Gaps and errors**
   - Duplicates the pattern catalogue with different rules (W2-9).
   - Teaches service decomposition it does not own (W2-11).
   - First-product default in the body: ACL for "Google Drive, AWS S3, Office 365" (`:96,115`).
   - "Team ownership" as a discovery signal (`:51-52`) assumes teams; for an agent-built product, say how it applies (often not at all).
   - Body 138 lines.
3. **Folder moves**
   - `references/bc-definition-artifact.md` mixed (template + worked example + versioning) → `templates/bounded-context-definition.md`, `examples/`, a short reference.
   - `references/context-map-template.md` mixed → `templates/context-map.md` + `examples/`.
   - `references/service-decomposition.md` → moves to `container-diagram` (Decision 6).
   - Lint: clean.
4. **Examples**
   1. Lean: one BC, a context map of one box and two external systems.
   2. Standard: e-learning platform, three BCs found on language fractures ("Course" in catalogue vs enrolment).
   3. Enterprise: retail group with a legacy ERP as Big Ball of Mud behind one ACL, plus a Partnership between two internal contexts.
5. **Eval ideas**
   - (a) "Each Aggregate should be its own context, right?" Grader checks the category-error answer.
   - (b) "We have two teams, so two contexts?" Grader checks language change is the primary signal; team ownership confirms.
6. **Overlaps**
   - `context-map-patterns` (Decision 5); `container-diagram` (service boundaries); `ubiquitous-language`.
7. **Size:** L.

### context-map-patterns

1. **Sources**
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: contract strictness alongside pattern choice (`:33`); data-ownership patterns vs Shared Kernel (`:52`).
   - `research/software-architecture/building-microservices-newman.md`: Consumer-Driven Contracts (`:10,33`).
   - `research/testing/contract-testing-in-action-cruz-prescott.md` (names this skill; contract tests).
   - Strategic research file (W2-2).
2. **Gaps and errors**
   - Duplicated by `bounded-context-mapping` (W2-9).
   - Internal tension: "upstream has no obligation → Conformist or ACL" (`:54,59`) vs "third-party API → ACL always" (`:85`).
   - `references/integration-patterns-catalogue.md` holds Go code (3 blocks) and ACL implementation that `integration-design` also holds (W2-10, W2-31).
   - Output Format has no frontmatter (`:123-131`); it produces `pattern-selection-rationale`, which no manifest entry registers. Say it is a section of the context map.
   - Body 112 lines.
3. **Folder moves**
   - `references/worked-example.md` → `examples/`.
   - `references/pattern-selection-guide.md` stays (decision tree = knowledge).
   - Go shapes out of the catalogue (Decision 10).
   - Lint: clean.
4. **Examples**
   1. Conformist to a payment provider's well-designed API in a lean product.
   2. Customer/Supplier with contract tests between two internal contexts, escalating to OHS at the fourth consumer.
   3. Enterprise: pass-through ACL diagnosed and replaced; a `common/` "Shared Kernel" dissolved.
5. **Eval ideas**
   - (a) A translator that copies upstream fields 1:1. Grader checks "pass-through ACL" diagnosis and "admit it is Conformist" option.
   - (b) "Third party with a clean model and no obligation to us — ACL or Conformist?" Grader checks the trade-off rather than "ACL always".
6. **Overlaps**
   - `bounded-context-mapping`, `integration-design` (ACL implementation), `go-contract-test`.
7. **Size:** M.

### aggregate-design

1. **Sources** (already absorbed; declare them)
   - `research/domain-driven-design/domain-driven-design-evans.md` (`:7-31`, Factories `:16-17`, Specification `:22`).
   - `research/domain-driven-design/implementing-ddd-vernon.md` (`:7-23`; true-invariant test `:9`; identity `:19-20`; concurrency `:21`; not absolutist `:22`).
   - `research/domain-driven-design/learning-ddd-khononov.md` (business-logic patterns `:8-14`; event sourcing `:17-22`).
   - `research/security/secure-by-design.md` (Domain Primitives, cited in `references/entities-value-objects-and-domain-primitives.md`).
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md` (write skew, cited in sizing reference).
2. **Gaps and errors**
   - Content is strong. Problems are shape and scope.
   - 777-line Go reference in a Design-phase domain-modeler skill (W2-31).
   - Description lists authors and script paths (W2-43).
   - Lean `domain-model` document has no template (W2-17); this skill is the natural home.
   - All examples on one product (`references/worked-examples.md`).
   - `related:` includes `skill-authoring-standards`, which the product-facing prose need not name.
   - Body 156 lines.
3. **Folder moves**
   - `assets/aggregate-design-template.md` → `templates/` (W2-35); scripts keep working after a path fix and their tests (`tests/scripts/scaffold-aggregate-design.test.sh`, `validate-aggregate-design.test.sh`).
   - `references/worked-examples.md` → `examples/`.
   - `references/decision-trees-and-worksheets.md` (375 lines) is mixed: worksheets → `templates/`, decision trees stay.
   - `references/go-implementation-patterns.md` → `go-domain-model` (Decision 10).
   - Lint: clean.
4. **Examples**
   1. Transaction Script is enough: a lean sign-up sheet.
   2. Standard: a hotel booking where "room has bookings" is has-a, not must-be-atomic; Booking is its own Aggregate.
   3. Enterprise: a ledger where debit and credit must be atomic (Vernon's justified exception) plus event sourcing justified by audit-as-record.
5. **Eval ideas**
   - (a) "Product contains all its BacklogItems, so one Aggregate for safety." Grader checks the has-a vs must-be-atomic test and a split.
   - (b) "This subdomain is Core, so event-source it." Grader checks the three-question justification and premature event sourcing.
   - (c) A one-table settings feature. Grader checks Active Record or Transaction Script is accepted.
6. **Overlaps**
   - `go-domain-model`, `go-repository-pattern` (code); `subdomain-distillation`; `domain-event-catalog`.
7. **Size:** M.

### domain-event-catalog

1. **Sources**
   - `research/domain-driven-design/domain-driven-design-evans.md`: Domain Events as Evans' later addition (`:30`).
   - `research/domain-driven-design/implementing-ddd-vernon.md`: durable at-least-once publication and idempotent consumers (`:16-17`); in-process publisher (`:18`).
   - `research/domain-driven-design/learning-ddd-khononov.md`: internal vs integration events (`:20`); upcasting for stored events (`:21`).
   - `research/software-architecture/microservices-patterns-richardson.md`: Transactional Outbox (`:15`).
2. **Gaps and errors**
   - Versioning and envelope contradict `event-schema-design` (W2-3, W2-4).
   - Company name `caizin` (W2-20).
   - 371-line outbox/CDC reference duplicates `event-driven-patterns` (W2-10).
   - Notification Event example breaks its own naming rule (W2-39).
   - Catalogs "events, schemas, outbox, DLQ" per the agent (`agents/domain-modeler.md:162`): outbox and DLQ are architecture and implementation choices, not catalog content.
   - Body 146 lines.
3. **Folder moves**
   - `references/catalog-template.md` → `templates/domain-event-catalog.md` (worked entries → `examples/`).
   - `references/event-format.md` → envelope moves to `event-schema-design` (Decision 1); the catalog keeps the payload-field format.
   - `references/outbox-and-cdc.md` → removed; point to `event-driven-patterns`.
   - `references/versioning-and-retention.md`: versioning → `event-schema-design`; retention stays.
   - Lint L5: `versioning-and-retention.md:23` (`skills/aggregate-design/SKILL.md`).
4. **Examples**
   1. Lean: five events in one document, no integration events.
   2. Standard: food-delivery with a coarse public `OrderDelivered` and finer internal events.
   3. Enterprise: event-sourced ledger with internal events never published and an upcaster.
5. **Eval ideas**
   - (a) "Name the event for updating a customer's address." Trap: `CustomerUpdated`. Grader checks a business-meaningful past-tense name (`CustomerRelocated` / `AddressCorrected`) and asks which fact happened.
   - (b) "Publish every internal state transition so consumers have full detail?" Grader checks the internal vs integration distinction.
6. **Overlaps**
   - `event-schema-design` (Decisions 1–2); `event-driven-patterns`; `go-event-publisher`.
7. **Size:** L.

### event-schema-design

1. **Sources**
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md`: backward / forward compatibility (`:32`).
   - `research/software-architecture/building-microservices-newman.md`: tolerant reader (`:13`).
   - `research/domain-driven-design/learning-ddd-khononov.md`: upcasting only for stored events (`:21`).
   - CloudEvents 1.0 spec (free; add a reference note, W2-5); Greg Young's versioning book — **missing**.
2. **Gaps and errors**
   - Contradicts the catalog (W2-3, W2-4); CloudEvents required-attribute error (W2-5).
   - Owner conflict (W2-15).
   - Registry named "Apicurio or Confluent" (`:9`) but the tech-stack defaults name no registry; the quality criterion requires Apicurio (`:141`). Add it to the defaults or make the registry a choice.
   - No `related:` gaps (has 4). Body 157 lines.
3. **Folder moves**
   - `references/cloudevents-format.md` becomes the single envelope reference.
   - `references/go-event-structs.md` → `go-event-publisher` (Decision 10).
   - `references/schema-registry.md`, `references/schema-versioning.md` stay.
   - Lint L5: `SKILL.md:57`.
4. **Examples**
   1. Lean: JSON events, no registry, compatibility checked by a contract test.
   2. Standard: adding an optional field (minor) vs renaming (new type, parallel publish).
   3. Enterprise: Protobuf with a registry in BACKWARD mode across regions, retiring an old type by telemetry.
5. **Eval ideas**
   - (a) "List the required CloudEvents attributes." Grader checks the four (no `datacontenttype`).
   - (b) "We must rename `amount` to `amountMinor`." Grader checks it is breaking and follows the one chosen protocol (Decision 1).
6. **Overlaps**
   - `domain-event-catalog`; `data-architect`'s `canonical-data-model`; `go-contract-test`.
7. **Size:** M.

### command-catalog

1. **Sources**
   - `research/domain-driven-design/domain-driven-design-evans.md`: commands vs side-effect-free queries (`:19`).
   - `research/software-architecture/api-design-patterns-geewax.md`: commands as domain verbs, no gap (`:32`); custom methods for non-CRUD actions (`:19`).
   - `research/domain-driven-design/implementing-ddd-vernon.md`: one Aggregate per command (`:15`).
2. **Gaps and errors**
   - Command-to-HTTP mapping (`references/command-aggregate-mapping.md`) overlaps `api-contract-design`'s method table; one owner (the API skill) should hold HTTP.
   - Go validation code in `references/validation-patterns.md` (7 blocks) (W2-31).
   - First-product examples throughout (`ClassifyDataAsset`).
   - Body 130 lines.
3. **Folder moves**
   - `references/catalog-template.md` → `templates/command-catalog.md` + `examples/`.
   - `references/command-format.md`, `command-aggregate-mapping.md` stay; Go blocks move.
   - Lint: clean.
4. **Examples**
   1. Lean: four commands in the `domain-model` document.
   2. Standard: `CancelReservation` with structural vs business-rule rejection.
   3. Enterprise: an idempotent `CapturePayment` retried across a regional failover.
5. **Eval ideas**
   - (a) "Validate that the account has funds in the HTTP handler." Grader checks business-rule validation belongs in the Aggregate.
   - (b) "`UpdateOrder` with a status field." Grader checks intent-revealing commands.
6. **Overlaps**
   - `api-contract-design`, `aggregate-design`, `go-service-layer`.
7. **Size:** M.

### cqrs-pattern

1. **Sources**
   - `research/domain-driven-design/learning-ddd-khononov.md`: CQRS spectrum (`:23`).
   - `research/software-architecture/microservices-patterns-richardson.md`: API Composition vs CQRS (`:14`).
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md` and `…-part2-consistency-consensus.md`: read-your-writes and replication anomalies (`kleppmann:45`; `part2:28`).
   - Greg Young named in prose (`:27`) with no file — attribute the term's origin only, or drop.
2. **Gaps and errors**
   - Three owners and order inversion (W2-14).
   - Read-side default contradicts two skills (W2-7).
   - Wrong pointer for the four patterns (W2-32).
   - First-product rule at `:137`.
   - Body 169 lines.
3. **Folder moves**
   - `references/cqrs-variants.md` stays (decision knowledge).
   - `references/projection-patterns.md` → `read-model-design` (projection mechanics live there).
   - `references/go-implementation.md` → `go-service-layer` / `go-event-consumer`.
   - Lint: clean.
4. **Examples**
   1. Lean: no CQRS; one model.
   2. Standard: Simple Read Model for a dashboard, escalation trigger named.
   3. Enterprise: full projections per region with read-your-writes handled for the writer.
5. **Eval ideas**
   - (a) "Reads and writes differ a bit, load is low. Build projections?" Grader checks the Simple Read Model and a named escalation trigger.
   - (b) "CQRS means we drop the state table and event-source, right?" Grader checks independence.
6. **Overlaps**
   - `read-model-design`, `workflow-orchestration` (cross-service queries), `aggregate-design`.
7. **Size:** M.

### read-model-design

1. **Sources**
   - `research/domain-driven-design/learning-ddd-khononov.md`: read models decoupled from Aggregate boundaries (`:24`); spectrum (`:23`); snapshots as disposable acceleration (`:19`).
   - `research/software-architecture/designing-backend-systems-go-campbell.md`: cache-aside for read-heavy views (`:19,47,56`).
2. **Gaps and errors**
   - "No JOINs" and "never query the write model" contradict the CQRS ladder (W2-7).
   - Designed at Design step 11 before the CQRS decision exists (W2-14).
   - Go code: 400-line `references/go-implementation.md` (W2-31).
   - `references/read-model-format.md` example `DataAssetView` (first product).
   - Body 107 lines.
3. **Folder moves**
   - `references/read-model-format.md` mixed → `templates/read-model-design.md` + `examples/`.
   - `references/consistency-patterns.md`, `denormalization-patterns.md` stay.
   - Lint: clean.
4. **Examples**
   1. Standard: one dashboard projection with rebuild procedure.
   2. A search projection in a separate store fed by events from three Aggregates.
   3. Enterprise: per-region projections with a lag SLO and a shadow-table rebuild.
5. **Eval ideas**
   - (a) "Shape the Read Model like the Aggregate so it is reusable." Grader checks one Read Model per query shape.
   - (b) "The projection fell behind; just patch rows by hand." Grader checks rebuild from events.
6. **Overlaps**
   - `cqrs-pattern`, `data-model-design` (storage), `api-contract-design` (response shapes).
7. **Size:** M.

### ddd-agent-handoff

1. **Sources**
   - `research/devops-and-delivery/platform-engineering-fournier-nowland.md`: interaction modes drawn from Team Topologies (`:13`) — secondhand; Team Topologies itself is missing (W2-49).
   - `research/domain-driven-design/learning-ddd-khononov.md`: boundary hierarchy for who owns which layer (`:16`).
2. **Gaps and errors**
   - No `related:` field although the description names 12 skills.
   - The matrix will be wrong after Decisions 2, 4, 6, 11 (it routes `event-schema-design` and CQRS today and omits the four orphan skills and `architecture-evaluation`).
   - Plugin-internal governance skill; the solo product owner and agents run every mode, so "Collaboration mode" between agents needs a concrete meaning or removal.
   - Body 76 lines.
3. **Folder moves**
   - `assets/handoff-record-template.md` → `templates/` (W2-35).
   - `references/handoff-worked-examples.md` → `examples/`.
   - Lint: clean.
4. **Examples**
   1. Domain-modeler → enterprise-architect handoff of BC candidates.
   2. Disputed ownership of event schemas resolved by the matrix.
   3. Resuming an interrupted Design phase from handoff records.
5. **Eval ideas**
   - (a) "Who decides whether the Billing context uses CQRS?" Grader checks the post-Decision-4 owner.
   - (b) "The data architect found a wrong Aggregate invariant; should it fix the file?" Grader checks flag-back, never edit another agent's artifact.
6. **Overlaps**
   - Every agent file's Owns / Does not own sections.
7. **Size:** S.

### system-context-diagram

1. **Sources**
   - `research/software-architecture/documenting-software-architectures-clements.md`: C&C view at the coarsest grain; per-view rationale; C4 as a narrowed profile (`:31`, `:13`, `:58`).
   - `research/software-architecture/just-enough-software-architecture-fairbanks.md`: a model answers a named question (`:11,21`).
   - C4 research note from c4model.com — **missing** (W2-26).
2. **Gaps and errors**
   - Notation rule (ASCII primary) not shared by the other two C4 skills (W2-25).
   - Example and persona names are the first product (`references/diagram-template-and-example.md`).
   - No scale rule; required at every profile (`phase-requirements.json`), which is right, but lean should be one diagram with no supplementary notations.
   - Body 152 lines.
3. **Folder moves**
   - `references/diagram-template-and-example.md` mixed → `templates/system-context.md` + `examples/`.
   - `references/c4-context-notation.md`, `boundary-identification.md` stay.
   - Lint: clean.
4. **Examples**
   1. Lean internal tool: one person, two external systems.
   2. B2B SaaS with an identity provider, payment provider and an outbound webhook consumer.
   3. Enterprise: a system with partner systems in other organisations and a regulator feed, boundary notes on what is out of scope.
5. **Eval ideas**
   - (a) "Put the database and the message broker on the context diagram." Grader checks they are rejected (Level 2).
   - (b) "Is our frontend a separate system?" Grader checks it is a container, not a person or external system.
6. **Overlaps**
   - `container-diagram`; `user-persona` (persons); `event-storming-facilitation` (external systems).
7. **Size:** S.

### container-diagram

1. **Sources**
   - `research/software-architecture/documenting-software-architectures-clements.md`: C&C vs allocation; combined views; variability guide (`:11-16,22-23,32,42`).
   - `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`: characteristics as trade-offs; style selection (`:10,23,33`).
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: granularity integrators and disintegrators (`:10-11,20`).
   - `research/software-architecture/building-microservices-newman.md`: Conway, team ownership (`:8,30`).
   - `research/software-architecture/system-design-interview-xu.md`: gateway keeps no business logic (`:28,34`).
   - `research/devops-and-delivery/api-gateway-patterns.md`: draw the north-south and east-west planes (`:19`).
2. **Gaps and errors**
   - Points to a nonexistent `deployment-diagram` skill (W2-23).
   - "Shared broker" row (`:81`) vs per-tenant broker in multi-tenancy; belongs in the deployment view.
   - Receives service decomposition from `bounded-context-mapping` (W2-11); its boundary table should use granularity checklists and the profile (lean: one deployable, BCs as modules).
   - "One database per service is a hard rule" (`:85`) applies to services; say what it means for a modular monolith.
   - Mermaid-only template (W2-25).
   - Body 127 lines.
3. **Folder moves**
   - `references/runtime-topology-and-template.md` mixed → `templates/container-diagram.md` (with a new deployment-view section) + `examples/`.
   - `references/service-decomposition.md` arrives from `bounded-context-mapping`.
   - Lint: clean.
4. **Examples**
   1. Lean: modular monolith, one database, BCs as packages.
   2. Standard: four services, broker, gateway, one deployment view.
   3. Enterprise multi-region: per-region deployment view, tenant stamps in the allocation view only.
5. **Eval ideas**
   - (a) "Add pod counts and per-tenant multipliers to the container diagram." Grader checks they go to the deployment view.
   - (b) "Every Bounded Context becomes its own service, even for a 20-user tool?" Grader checks granularity integrators and the profile.
6. **Overlaps**
   - `bounded-context-mapping`, `multi-tenancy-design`, `api-gateway-design`, `kubernetes-manifest`.
7. **Size:** M.

### component-diagram

1. **Sources**
   - `research/software-architecture/documenting-software-architectures-clements.md`: layered module view; implementation view (`:10,24,33`).
   - `research/software-architecture/clean-architecture-martin.md`: Dependency Rule (`:28,40`).
   - `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`: fitness functions (`:12,34`).
   - `research/software-architecture/just-enough-software-architecture-fairbanks.md`: draw only what answers a question (`:11`).
2. **Gaps and errors**
   - "Skip when default" vs manifest "required per service" (W2-24).
   - Mermaid-only template (W2-25); Go package layout hardwired (stack override).
   - Body 110 lines.
3. **Folder moves**
   - `references/diagram-template.md` mixed → `templates/component-diagram.md` + `examples/`.
   - `references/layering-and-dependency-rules.md`, `c4-component-notation.md` stay.
   - Lint: clean.
4. **Examples**
   1. Default service: no diagram, one line saying why.
   2. A service with an ACL adapter and a projector.
   3. A service hosting a saga coordinator with its own ports.
5. **Eval ideas**
   - (a) "Number the arrows step 1, 2, 3 on the component diagram." Grader checks module views have no sequence.
   - (b) "Our service is plain four-layer; draw the diagram anyway?" Grader checks the skip rule (after Decision 13).
6. **Overlaps**
   - `go-project-structure`, `go-service-layer`, `architecture-evaluation` (fitness functions).
7. **Size:** S.

### integration-design

1. **Sources**
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: static vs dynamic coupling (`:8,34`).
   - `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`: broker vs mediator topology (`:11,36`).
   - `research/software-architecture/building-microservices-newman.md`: smart endpoints, dumb pipes; contracts (`:9-10,21,32`).
   - `research/software-architecture/system-design-interview-xu.md`: rate limiting, resilience (`:35,48`).
   - `research/software-architecture/software-architecture-in-practice-bass.md`: availability tactics (`:23`).
   - `research/software-architecture/just-enough-software-architecture-fairbanks.md`: risk-driven sizing (`:10,24`).
2. **Gaps and errors**
   - "CDC" collision (W2-12); inventory lacks the Consistency column (W2-40); resilience mandatory at every scale (W2-29); no contract-strictness column (W2-47).
   - ACL and CDC mechanics duplicated with `context-map-patterns` and `event-driven-patterns` (W2-10).
   - Body 204 lines (W2-50).
3. **Folder moves**
   - Output Format (`:194-226`) → `templates/integration-design.md`.
   - `references/worked-example.md` → `examples/`.
   - Inventory example (`:149-154`) → the example.
   - Lint: clean.
4. **Examples**
   1. Lean: two integrations, timeouts only, recorded as risk-accepted.
   2. Standard: sync payment call with full stack; async events with outbox and DLQ.
   3. Enterprise: cross-region calls with timeout budgets and a mediator flow.
5. **Eval ideas**
   - (a) "Retry the POST to the payment provider three times on timeout." Grader checks idempotency key or no retry.
   - (b) "Use request/reply over the broker for this lookup." Grader checks the anti-pattern.
6. **Overlaps**
   - `context-map-patterns`, `event-driven-patterns`, `api-contract-design`, `go-contract-test`.
7. **Size:** M.

### event-driven-patterns

1. **Sources**
   - `research/software-architecture/microservices-patterns-richardson.md`: saga, compensation classes, outbox (`:9-11,15,20`).
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: three dynamic-coupling axes; saga taxonomy (`:8-9,30`).
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md` and part 2: eventual consistency, no 2PC, consensus provided by the broker (`kleppmann:54`; `part2:29`).
   - `research/domain-driven-design/implementing-ddd-vernon.md`: at-least-once and idempotency (`:16`).
2. **Gaps and errors**
   - Orchestration rule contradicts `workflow-orchestration` and Richardson (W2-6).
   - Competing Consumers misdefined (W2-8).
   - Partition by `tenant_id` as the default ordering key (anti-patterns) assumes a multi-tenant product.
   - Output has no frontmatter; it is a section of the integration design (state that).
   - Body 142 lines.
3. **Folder moves**
   - `references/saga-patterns.md` → mostly to `workflow-orchestration`; keep choreographed sagas here.
   - `references/go-implementation.md` → `go-event-publisher` / `go-event-consumer`.
   - Lint: clean.
4. **Examples**
   1. Two-context choreography with an idempotent consumer.
   2. Partition-key choice for per-account ordering.
   3. A Horror Story saga diagnosed and redesigned.
5. **Eval ideas**
   - (a) "Make the three-service flow atomic with a distributed transaction." Grader checks no 2PC; saga with compensation.
   - (b) "Use CDC on our new service to publish events." Grader checks outbox default.
6. **Overlaps**
   - `workflow-orchestration`, `domain-event-catalog`, `message-broker-selection`, `integration-design`.
7. **Size:** M.

### workflow-orchestration

1. **Sources**
   - `research/software-architecture/microservices-patterns-richardson.md` (`:9-14,20`) — the process manager comes from here (`:13`); drop or re-source "Hohpe".
   - `research/software-architecture/software-architecture-hard-parts-ford.md` (`:9`).
2. **Gaps and errors**
   - Not loaded by any agent (W2-13).
   - "Deployed per-tenant like everything else" (`:48`) leaks the first product.
   - API Composition rule needs to join the CQRS ladder (W2-7).
   - Body 132 lines.
3. **Folder moves**
   - Output Format → `templates/orchestration-design.md`.
   - `references/orchestration-saga-design.md` worked saga → `examples/`.
   - Lint: clean.
4. **Examples**
   1. Choreography kept: a three-step order flow.
   2. Hand-rolled coordinator for a loan approval with a human wait.
   3. Enterprise: many long-running flows justify a workflow engine.
5. **Eval ideas**
   - (a) A saga with no pivot. Grader checks the pivot is identified.
   - (b) "Adopt Conductor for our single flow." Grader checks hand-rolled first.
6. **Overlaps**
   - `event-driven-patterns`, `conductor-workflow-authoring`, `cqrs-pattern`.
7. **Size:** S.

### message-broker-selection

1. **Sources**
   - `research/software-architecture/rabbitmq-in-depth-roy.md` (`:9-15,19-20,39`).
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md` (log-based messaging).
   - `research/domain-driven-design/implementing-ddd-vernon.md`: in-process publisher for one deployable (`:18`).
2. **Gaps and errors**
   - Not loaded by any agent (W2-13).
   - No "broker at all?" question (W2-30).
   - Justifies the default with the first product (`:30`).
   - Body 104 lines.
3. **Folder moves**
   - `references/selection-decision-guide.md`, `log-vs-queue-model.md` stay; add `examples/`.
   - Lint: clean.
4. **Examples**
   1. Lean: no broker; in-process events.
   2. Standard: log for domain events plus queue for report jobs.
   3. Enterprise: per-region clusters, replay for a new read model.
5. **Eval ideas**
   - (a) "Swap Kafka for RabbitMQ, it's just a client change." Grader checks replay, ordering loss.
   - (b) "We need a new read model from last month's events on RabbitMQ." Grader checks no replay.
6. **Overlaps**
   - `event-driven-patterns`, `go-event-*`, `go-amqp-*`.
7. **Size:** S.

### api-contract-design

1. **Sources**
   - `research/software-architecture/api-design-patterns-geewax.md` (`:7,19,30-31,44,48,55-56`).
   - `research/software-architecture/api-first-transformation-lane.md` (`:7,11,18-22,28`).
   - `research/software-architecture/building-microservices-newman.md`: tolerant reader, versioning (`:13,56`).
   - `research/testing/testing-web-apis-winteringham.md` (names this skill).
2. **Gaps and errors**
   - Spec path mismatch (W2-33); two templates (W2-34).
   - Overlaps `command-catalog` HTTP mapping; no pointer to `grpc-contract-design` for internal APIs (`grpc-up-and-running.md:33`).
   - Idempotency-Key on all POST/PUT/PATCH (`:148`) with 24 h storage at every scale.
   - Body 199 lines.
3. **Folder moves**
   - Templates → one `templates/api-contract-summary.md`; `references/openapi-spec-structure-example.md` → `examples/`.
   - Scripts stay (tests exist).
   - Lint: clean.
4. **Examples**
   1. Lean: three resources, no versioning beyond `/v1`.
   2. Standard: custom method and long-running operation.
   3. Enterprise public API with deprecation headers and partner consumers.
5. **Eval ideas**
   - (a) "Add `POST /approveInvoice`." Grader checks a custom method `POST /invoices/{id}:approve` or state field.
   - (b) "Remove a response field in v1." Grader checks breaking → v2 in parallel.
6. **Overlaps**
   - `command-catalog`, `read-model-design`, `grpc-contract-design`, `api-gateway-design`.
7. **Size:** M.

### grpc-contract-design

1. **Sources**
   - `research/software-architecture/grpc-up-and-running.md` (`:9-15,19-20`).
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: Protobuf is stricter static coupling (`:8`).
2. **Gaps and errors**
   - Not loaded by any agent (W2-13); tech-stack default is `net/http + chi`, so nothing says when gRPC is chosen.
   - First-product `DataAssetService` example.
   - Body 147 lines.
3. **Folder moves**
   - `references/protobuf-design-and-compat.md`, `streaming-and-errors.md` stay; add `examples/`.
   - Lint: clean.
4. **Examples**
   1. Internal unary service.
   2. Server-streaming telemetry feed.
   3. Mixed public REST + internal gRPC with a breaking-change CI check.
5. **Eval ideas**
   - (a) "Renumber field 3 to tidy the proto." Grader checks field numbers are permanent.
   - (b) "Return INTERNAL for not-found." Grader checks NOT_FOUND.
6. **Overlaps**
   - `api-contract-design`, `go-grpc-handler`, `integration-design`.
7. **Size:** S.

### api-gateway-design

1. **Sources**
   - `research/devops-and-delivery/api-gateway-patterns.md` (`:9-15,19-20`).
   - `research/software-architecture/system-design-interview-xu.md` (`:28,48`).
2. **Gaps and errors**
   - Not loaded by any agent (W2-13); phase deploy though placement is a design choice (W2-28).
   - Downstream-trust wording vs zero trust (W2-27).
   - Body 132 lines.
3. **Folder moves**
   - `references/kong-configuration.md` stays as one implementation example; `references/gateway-vs-mesh-and-placement.md` stays.
   - Lint: clean.
4. **Examples**
   1. Lean: no gateway; ingress only.
   2. Standard: gateway + one BFF.
   3. Enterprise: per-region gateways with tenant rate limits.
5. **Eval ideas**
   - (a) "Put the discount logic in the gateway." Grader checks no business logic at the edge.
   - (b) "Services can skip token checks since the gateway validated it." Grader checks zero trust.
6. **Overlaps**
   - `container-diagram`, `zero-trust-design`, `kubernetes-manifest`.
7. **Size:** S.

### multi-tenancy-design

1. **Sources**
   - `research/software-architecture/software-architecture-hard-parts-ford.md`: granularity disintegrator framing (`:35`); says multi-tenancy is out of its scope (`:51`).
   - `research/software-architecture/designing-data-intensive-applications-kleppmann.md` (`:30,55`).
   - `research/software-architecture/system-design-interview-xu.md` (`:38`).
   - Tod Golding, *Building Multi-Tenant SaaS Architectures* — **missing** (W2-48).
2. **Gaps and errors**
   - Physical default and SOC 2 error (W2-19); no hybrid tier model (W2-48); enforcement layers written for the stamp only (`references/enforcement-layers.md:63-71`).
   - Runs after the container diagram (W2-18).
   - No related-skill gap. Body 122 lines.
3. **Folder moves**
   - Output Format → `templates/multi-tenancy-design.md`.
   - `references/provisioning-and-stamps.md` → stamp case into `examples/`.
   - Lint: clean.
4. **Examples**
   1. Pooled with row-level security for a low-sensitivity SMB tool.
   2. Schema-per-tenant for a mid-market product.
   3. Tiered: pooled standard tenants plus silo stamps for regulated enterprise tenants.
5. **Eval ideas**
   - (a) "Does SOC 2 require a separate database per tenant?" Grader checks no.
   - (b) "Hundreds of small tenants, low sensitivity: which model?" Grader checks pooled with RLS, not stamps.
6. **Overlaps**
   - `container-diagram`, `zero-trust-design`, `opentofu-module`, `data-model-design`.
7. **Size:** L.

---

## Scope note: the new `architecture-evaluation` skill (D045)

- **What it owns:** checking a design against the NFR scenarios once a container diagram and first ADRs exist. Content: the lightweight evaluation steps; definitions of risk, non-risk, sensitivity point, trade-off point and risk theme; per-attribute tactics questionnaires (`software-architecture-in-practice-bass.md:22-30,34-41,68`); fitness functions as executable checks of characteristics (`fundamentals-of-software-architecture-richards-ford.md:12`). A full ATAM is out of scope (Bass file `:93`). The record says it is a self-check, not an independent review (`:116`).
- **Artifact:** `architecture-evaluation` record (`design/architecture/architecture-evaluation.md`): scenarios evaluated, approaches, risks, non-risks, sensitivity and trade-off points, risk themes, fitness functions proposed. Lean: a tactics questionnaire on 2–3 top scenarios; standard: the record; enterprise: a one-day lightweight evaluation with risk themes at the Design gate (`:68,117`).
- **Owner:** `enterprise-architect`, phase design, domain architecture; run after ADRs, before the architecture summary.
- **Stays with `nfr-specification`:** writing scenarios, the utility tree and candidate trade-off points (Ideate).
- **Stays with `adr-authoring`:** recording each resolved trade-off point as an ADR when it passes the risk gate.
- **Also:** hotspots from Event Storming and component-diagram import checks feed it.

---

## Decisions needed

1. **Event envelope and versioning.** (a) CloudEvents 1.0 with extensions (`correlationid`, `causationid`, `tenantid`); (b) house envelope mapped to CloudEvents. Breaking change: (i) new event type; (ii) `.vN` suffix. **Recommend (a) + (i)**, owned by `event-schema-design`; catalog points to it.
2. **Owner of `event-schema-design`.** (a) domain-modeler; (b) data-architect for serialization and registry, domain-modeler keeps payload semantics in the catalog. **Recommend (b).**
3. **Orchestration home.** **Recommend** `workflow-orchestration` owns orchestration with Richardson's rule; `event-driven-patterns` keeps choreography and a pointer.
4. **Read-side default and CQRS owner.** **Recommend** one ladder in `cqrs-pattern` (API composition across services; Simple Read Model in-service; projections on a named trigger), owner enterprise-architect, phase design, decided before `read-model-design` runs.
5. **Context-map skills.** (a) merge; (b) split responsibility. **Recommend (b):** patterns in `context-map-patterns`, discovery and drawing in `bounded-context-mapping`.
6. **Service decomposition owner and default.** **Recommend** move to `container-diagram`; lean = modular monolith; standard/enterprise use granularity checklists. Touches CLAUDE.md defaults, so the product owner decides.
7. **Multi-tenancy default.** **Recommend** no default; choose from NFR and compliance input; physical stamp becomes an example; tenancy runs before the deployment view.
8. **Agent-run workshops.** (a) agent mode from artifacts with assumptions and product-owner questions; (b) require a real human session. **Recommend (a)**, with (b) optional.
9. **Product language vs plugin glossary.** **Recommend** per-BC product UL lives in the product's artifacts; `glossary-management` stays the plugin vocabulary; the drift hook reads both.
10. **Go code in design skills.** **Recommend** move to `go-*` skills; design skills stack-neutral.
11. **Orphan skills.** **Recommend** add `message-broker-selection`, `workflow-orchestration`, `grpc-contract-design` to enterprise-architect; gateway placement at Design via `container-diagram`, gateway config with platform-engineer at Deploy.
12. **Gateway trust vs zero trust.** **Recommend** services verify identity; the gateway is the first check.
13. **C4 set.** **Recommend** a deployment-view section in `container-diagram`; component diagrams only for non-default services (manifest change); one notation rule (ASCII primary, Mermaid optional).
14. **Subdomain classification in the pipeline.** **Recommend** a step after Event Storming Big Picture; register `subdomain-classification` (lean: a short table).

---

## Missing books

| Title | Author | Skills | Why existing files don't cover it | Verdict |
|---|---|---|---|---|
| Strategic-design supplement from books already held (Evans Part IV, Vernon, Khononov Part I) | — | bounded-context-mapping, context-map-patterns, ubiquitous-language, subdomain-distillation | Existing files exclude strategic design (`evans:93`, `khononov:79,83`) | Needed (research pass, no purchase) |
| *Introducing EventStorming* | Alberto Brandolini | event-storming-facilitation, ubiquitous-language | Colour grammar, levels, facilitation unsourced (W2-42); no file mentions it | Needed |
| *Building Multi-Tenant SaaS Architectures* | Tod Golding | multi-tenancy-design | Hard Parts calls tenancy out of scope (`:51`); Fairbanks light on it (`:59`) | Needed |
| *Domain Storytelling* | Stefan Hofer, Henning Schwentner | domain-storytelling | Modes and step counts unsourced (W2-41) | Needed if the skill is kept |
| C4 model (c4model.com, free) / *Software Architecture for Developers* | Simon Brown | the three C4 skills | Clements covers viewtypes, not C4 notation (`:58`) | Needed as a free note |
| *Versioning in an Event Sourced System* | Greg Young | event-schema-design, domain-event-catalog | Kleppmann covers compatibility only (`:32`); the versioning dispute (W2-3) needs a source | Needed (medium) |
| CloudEvents 1.0 specification (free standard) | CNCF | event-schema-design | W2-5 | Needed as a reference note |
| *Enterprise Integration Patterns* | Hohpe & Woolf | workflow-orchestration, event-driven-patterns | Richardson covers the process manager (`:13`); Roy covers Competing Consumers (`:39`) | Not needed; re-source "Hohpe" to Richardson |
| *Architecture for Flow*; *Domain-Driven Transformation*; *Team Topologies* | Kaiser; Lilienthal & Schwentner; Skelton & Pais | subdomain-distillation, ddd-agent-handoff | Cited with no file (W2-49) | Low; drop attributions unless the product owner wants them |

**Coverage sufficient:** aggregate-design, cqrs-pattern, read-model-design (Evans, Vernon, Khononov, Richardson, Kleppmann); saga and orchestration (Richardson, Hard Parts); API and gRPC contracts (Geewax, Lane, Newman, gRPC); broker selection (Roy, Kleppmann); gateway (api-gateway-patterns); C4 view types (Clements, Fairbanks); architecture-evaluation (Bass, Richards & Ford).

---

## Proposed implementation order

0. **Pipeline sub-issue (like #1327), after decisions:** domain-modeler order (add subdomain classification; stories optional by profile); enterprise-architect order (CQRS before read models, tenancy before deployment view, orphan skills, architecture-evaluation); `phase-requirements.json` (subdomain-classification, architecture-evaluation, component-diagram rule, lean `domain-model` producer); `ddd-agent-handoff` matrix last.
1. **Research supplements:** strategic DDD, Brandolini, Golding, C4 note, CloudEvents note, Young.
2. **Domain track:** ubiquitous-language → subdomain-distillation → event-storming-facilitation → domain-storytelling → bounded-context-mapping → context-map-patterns → aggregate-design → event-schema-design → domain-event-catalog → command-catalog → cqrs-pattern → read-model-design → ddd-agent-handoff.
3. **Architecture track (can start after Decisions 6, 7, 13):** system-context-diagram → container-diagram → multi-tenancy-design → component-diagram → integration-design → event-driven-patterns → workflow-orchestration → message-broker-selection → api-contract-design → grpc-contract-design → api-gateway-design → architecture-evaluation (new).
4. **Eval budget:** about 25 suites at up to $7 each (≈ $175).

---

## What I could not finish or verify

- No eval or model runs; eval ideas are untested hypotheses.
- Large reference files (aggregate-design's Go and worksheet files, context-map-patterns' catalogue, outbox-and-cdc, the C4 notation references) were read by heading and search, not line by line.
- The CloudEvents attribute claim (W2-5), Domain Storytelling terminology (W2-41) and tenancy vocabulary (W2-48) rest on knowledge of the sources, not on files in `research/`; check against the spec and books before the rewrite quotes them.
