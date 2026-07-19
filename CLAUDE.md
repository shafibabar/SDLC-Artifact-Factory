# SDLC Artifact Factory — Always-On Standards

This file is read on every session. It encodes the non-negotiable rules every agent, skill, command, hook, and tool in this plugin must follow.

---

## Session Startup

**Every session begins with these three steps — no exceptions:**

1. Read `sdlc-context.json` — this restores full project context, build position, decisions, and tech stack.
2. Check `build_checklist` in that file — find the first incomplete item. That is where work continues.
3. If Shafi has not said "go" on the next chunk — do not build. Discuss the plan, get approval, then build.

---

## Who Shafi Is

Shafi Babar is the sole operator (Han Solo). He is a Product Manager — not a programmer. He provides the problem statement, reviews artifacts, and approves each chunk of work. Claude Code does all engineering. Every artifact must be reviewable by a PM without IDE tooling.

---

## What This Plugin Does

Takes a problem statement and drives a product through eight phases, producing real artifacts at every stage:

```
Strategy → Ideate → Design → Implement → Data → Quality → Deploy → Customer Validation
```

Each phase has defined inputs, outputs, and applicable methodologies. Phase gates are enforced. Nothing advances without passing validation.

---

## Working in This Repository

This repository **is the plugin itself** — component definitions in Markdown plus JSON configuration. There is currently no application code, no build step, and no test suite to run. Validation is structural (frontmatter, naming, glossary terms) until governance hooks land (Chunk 20). The `go`/`npm` permissions in `settings.json` are for code the plugin *generates*, not for this repo.

**Layout:**

```
.claude-plugin/plugin.json        Plugin manifest — component paths, agent roster, phases, tech defaults
sdlc-context.json                 Factory memory — build checklist, decisions, open questions
CLAUDE.md                         This file — always-on standards
settings.json                     Permissions, env vars, hook config
skills/<domain>/<name>/SKILL.md   One skill per directory, grouped by domain
agents/<role>/AGENT.md            One agent per directory
commands/ hooks/ tools/ schemas/  Empty until Chunks 19–21
mcp/ lsp/ monitors/               Deferred — .gitkeep placeholders
```

**Build workflow:**

- One chunk = one feature branch = one PR to `main`. Branch names follow `feature/<n>-<chunk-description>` (e.g. `feature/11-test-engineering-skills-and-test-strategist-agent`).
- After a chunk merges, update `build_checklist` status in `sdlc-context.json` and its `_meta.last_updated`/`updated_by` fields in the same piece of work.
- A chunk typically delivers one skill domain directory plus its owning agent(s) together.

---

## Non-Negotiable Methodology

These five methodologies are mandatory. Their absence in any artifact where they apply is a **defect** — not a warning, not advisory.

| Methodology | Where It Applies |
|---|---|
| **Domain-Driven Design** | Design, Implement — every service, every bounded context |
| **Event Storming** | Design — every domain and subdomain before any architecture decisions |
| **Test-Driven Development** | Implement — tests are written before implementation code, always |
| **Behavior-Driven Development** | Implement, Quality — Gherkin feature files for all acceptance criteria |
| **SOLID** | Implement — every class, function, and module in generated code |

---

## Component Architecture

One rule governs which component type to create:

```
Skills     = Expertise    — knowledge, standards, patterns. No reasoning, no decisions.
Agents     = Reasoning    — design, analysis, code generation, test writing. Use skills for knowledge.
Commands   = Workflows    — user-facing phase drivers. Orchestrate agents. No domain expertise.
Hooks      = Governance   — event-driven, <2s, idempotent. Validate only. No business logic.
Tools      = Actions      — atomic, deterministic, stateless. Single purpose.
MCP        = Integrations — external systems. Deferred.
LSP        = Code intel   — language-aware analysis. Pending.
```

**Component hierarchy:**
```
Command → Agent → Skill
Agent → Tool
Hook → Tool
```

**The anti-patterns that must never appear:**
- Skill that reasons or decides → move reasoning to an Agent
- Agent that stores large domain knowledge → move knowledge to a Skill
- Command that contains methodology → belongs in a Skill
- Hook that runs a workflow → hooks validate only
- Tool that makes business decisions → decisions belong in Agents

**Two boundary clarifications:**
- Decision *criteria* — selection tables, "use when / do not use when" guides, defaults — are knowledge and belong in Skills. *Applying* those criteria to a specific system is reasoning and belongs in Agents. A pattern-selection table in a skill is not a violation.
- An agent may carry a compressed **Behavioral Directives** index: short imperative bullets that each cite the owning skill in parentheses. This is a table of contents into skills, not stored knowledge. Any directive whose substance is not actually present in the cited skill is a defect — move the substance into the skill.

---

## Naming Conventions

All component names must match: `^[a-z0-9]+(-[a-z0-9]+)*$`

| Component | Convention | Examples |
|---|---|---|
| Skills | `<domain-noun>` or `<action-noun>` | `vision-statement`, `go-chi-handler`, `bdd-feature-file` |
| Agents | `<role-noun>` | `backend-engineer`, `domain-modeler` |
| Commands | `/sdlc-<verb-or-noun>` | `/sdlc-start`, `/sdlc-implement`, `/sdlc-adr` |
| Hooks | `<validate/check/enforce/tdd>-<noun>` | `pre-phase-advance`, `tdd-gate` |
| Tools | `<action>-<noun>` | `validate-openapi-contract`, `generate-artifact-id` |

---

## Ubiquitous Language

These terms must be used consistently across every artifact. Never substitute synonyms.

**Core DDD terms:**
`Bounded Context` · `Ubiquitous Language` · `Domain Event` · `Aggregate` · `Command` · `Read Model` · `Write Model` · `Subdomain` · `Context Map` · `Anti-Corruption Layer`

**Event-driven terms:**
`Transactional Outbox` · `Dead Letter Queue` · `Idempotency` · `Event Choreography` · `Eventual Consistency` · `Change Data Capture` · `Circuit Breaker` · `Retry and Backoff`

**Testing terms:**
`Test Pyramid` · `Consumer-Driven Contract` · `Specification by Example` · `Feature File` · `Scenario` · `Given/When/Then` · `Test Fixture` · `Mutation Testing`

**Platform terms:**
`GitOps` · `Infrastructure as Code` · `Helm Chart` · `OpenTofu Module` · `Service Mesh` · `Blue-Green Deployment` · `Canary Deployment` · `Pipeline of Pipelines`

**Security terms:**
`Zero Trust Architecture` · `Principle of Least Privilege` · `Attribute-Based Access Control` · `Non-Repudiation` · `Encryption at Rest` · `Encryption in Transit` · `Secrets Management`

Full glossary: `skills/governance/glossary-management/` (built in Chunk 4).

---

## Tech Stack Defaults

These defaults apply to all generated code and configuration unless overridden in `sdlc-config.json` at `/sdlc-start`.

| Concern | Default |
|---|---|
| Backend language | Go |
| API framework | `net/http` + `chi` |
| Frontend | React + TypeScript |
| Primary database | PostgreSQL + `pgx` |
| Message broker | Redpanda |
| Graph database | Apache AGE (PostgreSQL extension) |
| CI/CD | GitHub Actions |
| IaC | OpenTofu + Helm |
| Service mesh | Linkerd (automatic mTLS) |
| Container orchestration | Kubernetes |
| Observability | OpenTelemetry + Prometheus + Tempo + Grafana |

---

## Artifact Standards

Every artifact produced by this plugin must:

1. Have a frontmatter block with `name`, `version`, `phase`, `owner`, and `created` fields.
2. Use only terms from the canonical glossary (`skills/governance/glossary-management/`).
3. Be traceable — reference the requirement, event, or decision that caused it to exist.
4. Apply all non-negotiable methodologies applicable to its type.
5. Be reviewable by Shafi without IDE tooling — plain Markdown, clear structure.

This applies to artifacts the plugin *emits* (vision statements, ADRs, feature files, …) and to every `## Output Format` template inside a skill — templates use the key `name:`, never `artifact:`.

### Component Frontmatter

The plugin's own components carry these canonical schemas — no other shapes are permitted:

| Component | Required frontmatter fields, in order |
|---|---|
| SKILL.md | `name, description, version, phase, owner, created, tags` |
| AGENT.md | `name, description, role, version, phase, owner, created, inputs, outputs, skills, tools, tags` |

Every agent's `skills:` list includes `glossary-management` and `methodology-review` in addition to its domain skills. Agents that run shell commands (build, test, scan) declare `tools: [Bash]`.

---

## Agent Behaviour Rules

Every agent in this plugin must:

- **Produce real outputs** — not design notes. `backend-engineer` produces runnable Go code. `test-strategist` produces executable test files. `frontend-engineer` produces runnable React+TypeScript code.
- **Own its domain completely** — produce all design artifacts, implementation artifacts, and documentation for its domain. Do not narrow scope to code-only or design-only.
- **Declare what it owns and does not own** in its AGENT.md.
- **Never overlap** with another agent's domain.
- **Always check** `sdlc-context.json` to understand current phase and what artifacts already exist before producing new ones.

---

## Phase Gate Rules

A phase does not advance until all required artifacts for that phase pass governance hook validation.

The `pre-phase-advance` hook checks:
- All required artifacts for the current phase exist
- All artifacts pass `validate-artifact-structure`
- All artifacts pass `methodology-compliance-check`
- Ubiquitous language terms are consistent (`terminology-drift-detector`)

The `tdd-gate` hook checks:
- For every implementation file, a corresponding test file must exist with a date/commit earlier than or equal to the implementation file.

---

## Context File Maintenance

`sdlc-context.json` is updated by the `post-artifact-created` hook whenever an artifact is produced. The checklist `status` field must be updated to `complete` when a chunk finishes. The `decisions` array is appended whenever an architectural decision is made. The `open_questions` array is cleared when questions are resolved.

---

## Budget and Frugality

- Open-source over paid tooling at every decision point.
- No external paid APIs added without explicit approval.
- Prefer simpler solutions over sophisticated ones when outcomes are equivalent.
- Every added dependency must justify its presence against the frugality constraint.
