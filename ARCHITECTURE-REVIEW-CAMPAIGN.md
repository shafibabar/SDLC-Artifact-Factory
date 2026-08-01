# Architecture Review Campaign — Master Charter

**Status:** v0 (living document) · **Started:** 2026-08-01 · **Owner:** Shafi Babar · **Engine:** Claude Code

> **This is the resumable source of truth for the Architecture Review campaign.** If this conversation
> is interrupted — different account, different machine, fresh session — a cold-start agent reconstructs
> the entire campaign from: (1) this file, (2) `sdlc-context.json` `architecture_review_campaign` block
> (current parent, integration branch, child position), (3) the GitHub Project board and open issues.
> **Read those three, in that order, then continue from the first incomplete child.**

---

## 1. Why this campaign exists

The repo is now an agent *platform* (186 skills, 13 agents, 15 commands, 7 hooks, research, tests,
schemas). Across five architecture reviews we established that its relationships and standards are
**implicit and un-enforced**, and that the real missing thing is not another structural *tier* but
**machine-readable component metadata + a derived catalog + a validating linter** — plus the disciplined
extraction of the new concepts (workflows-as-data) and a deep refactor of every component to that
standard. This campaign builds exactly that, thoroughly, one artifact at a time.

Grounded in: `research/ai-agent-engineering/mastering-claude-code-agent-skills-gale.md`,
`research/ai-agent-engineering/context-engineering-for-ai-agents-zhu.md`,
`skills/skill-authoring-standards/SKILL.md`, and the platform constraints recorded in `CLAUDE.md` (D016
flat discovery; commands are prompts not programs; hooks are the only deterministic enforcement; Claude
is the only executor).

---

## 2. Locked architectural decisions (from the five reviews)

1. **Workflows-as-data, Claude-as-interpreter.** Workflows are declarative config a *thinned* command
   reads and interprets. There is **no workflow engine** — the platform has none and one cannot be a
   plugin component. Hooks + `sdlc-context.json` provide the deterministic guardrails and durable state.
2. **Relationship model over a Capability Registry.** Relationships are modelled as a **derived graph**
   built from component frontmatter (+ one new `produces:` field). "Capability" is a **derived view**
   over that graph (seeded from `skill_domains`), never a hand-authored tier.
3. **Manifests = enriched frontmatter (source of truth) + a derived catalog.** No parallel manifest
   files. Author only non-derivable, consumed fields; derive everything else. Never version-pin.
4. **Libraries rejected as a system.** Duplication is removed by **deletion + repointing** to existing
   homes (CLAUDE.md always-on standards; cross-cutting skills; scripts/hooks for enforcement) plus a
   thin `shared-references/` for the genuine minority. No `libraries/` tree.
5. **The keystone is the linter.** A consistency/relationship linter (schema shape + cross-references +
   cycles + orphans + duplication + drift) wired into CI is the highest-leverage deliverable; it
   validates everything else and is what makes the whole model self-honest.
6. **Skills and agents stay flat** (discovery). All new concepts are Descriptors (data), not Executors.

Full reasoning: this charter's companion is the conversation record; the responsibility matrix
(Section 6) is its distilled form.

---

## 3. Component model — Executors vs Descriptors

**Executors (do things):** Command · Agent · Skill (applied) · Hook · Script.
**Descriptors (data, read — never run):** Workflow spec · Manifest (frontmatter) · Catalog (derived) ·
`sdlc-context.json` · `CLAUDE.md` · cross-cutting skills · `shared-references/` · Research · Schemas.

Every new thing this campaign builds is a Descriptor or a Script (the linter/catalog/generators).
Claude is the only new "executor," and it belongs to the platform, not to this repo.

---

## 4. Parent issues (the build steps) — dependency-ordered

Each parent, when picked up, gets an **integration branch** `arch-review/<Pn>-<slug>`. Children branch
from and merge back into that integration branch; the integration branch merges to `main` when the
parent is complete. Parents are executed roughly in order (P1 first — it defines the standard everything
validates against); some later parents may interleave once P1/P3 exist.

| # | Parent | Scope of children (one per artifact, no grouping) | Est. children |
|---|---|---|---|
| **P1** | **Governance Foundation — Manifest Schemas + Consistency Linter** | one child per schema (skill/agent/command/hook/workflow) + one per linter (manifest, relationship, duplication) + CI wiring | ~10 |
| **P2** | **Skill Manifest Enrichment** (`produces`/`domain`/`status`) | one child per skill | 186 |
| **P3** | **Derived Component Catalog + CI Integration** | build-catalog script + catalog + CI + snapshot test | ~3 |
| **P4** | **Skill De-duplication & Repointing** (delete restatements → CLAUDE.md/cross-cutting; repoint validation → scripts/hooks; extract `shared-references/`) | one child per skill flagged by the P1 duplication linter | ~120–186 |
| **P5** | **Agent Deep Refactor** (absorbs epic #777) | one child per agent — behavioral directives, manifest fields, owns/does-not-own, description-as-trigger-surface, acceptance test (run it) | 13 |
| **P6** | **Hook Deep Refactor** | one child per hook — determinism/<2s/idempotency audit, catalog/linter integration where relevant | 7 |
| **P7** | **Command Refactor & Workflow-as-Data** | one child per workflow spec (~9 phase workflows) + one per command thinned/refactored (15) | ~24 |
| **P8** | **Test & Schema Infrastructure Hardening** | one child per shared test-infra artifact (harness, assertions, runner, tests/scripts group, tests/schemas, agent-test coverage) + schema completeness | ~15 |
| **P9** | **Catalog-driven Generation** (docs, dependency graph, capability view, search index, onboarding) | one child per generator | ~5 |

**Order:** P1 → P2 → P3 → (P4 · P5 · P6 · P7, each validated by P1's linter + P3's catalog) → P8 → P9.
**Rough totals:** 9 parents · ~380–450 child issues · same count of branches · same count of merges
(child→integration) + 9 (integration→main). Counts are indicative; thoroughness governs, not economy.

> **Note on #777:** the agent-refactor epic is **folded into P5**. product-strategist (already v2.0.0,
> acceptance test passing) gets a light P5 child for the manifest fields + linter conformance only; the
> other 12 agents get full P5 children. #777 is closed with a pointer to P5.

---

## 5. Execution model — per-child agent handoff

To keep the main conversation light and minimise compactions, **every child issue is dispatched to a
fresh agent** (via the Workflow/Agent tooling) briefed with **all required context**:
- the child issue's detailed description,
- the specific artifact(s) it touches,
- the manifest/linter standard and the relevant `skills/skill-authoring-standards` rules,
- the exact research files to read for that artifact,
- the git contract (below).

The main loop orchestrates, reviews returned work, and keeps state; the reading/writing lives in the
sub-agents. This is the same fan-out pattern used across Chunks 52–66, now formalised per child.

### Per-child lifecycle (the git contract)
1. Cut child branch `arch-review/<Pn>-<child-slug>` **from the parent's integration branch**.
2. Implement + test (test bundled with the artifact — TDD, per repo rule).
3. **Detailed commit message on every commit, however small** (non-negotiable) — what changed, why,
   which decision/standard it satisfies, `Co-Authored-By` line.
4. PR → **merge child branch into the integration branch** → confirm the PR shows `MERGED`.
5. Close the child issue; update the Project board.

### Per-parent completion
1. All children merged into the integration branch.
2. **Major-commit housekeeping** (Section 7).
3. Merge integration branch → `main`; close the parent; update the board.

---

## 6. Responsibility matrix (distilled)

The authoritative matrix lives in the conversation record; the operative summary:

- **Sequencing/dependency** → Workflow spec + artifact-graph (data), validated by the linter; resolved
  at runtime by Claude reading `sdlc-context`.
- **Metadata/relationships** → frontmatter (authored source) → catalog (derived) → linter (validate) →
  generators (consume). Capability = a derived view.
- **Gates** → mechanical = hooks/scripts (deterministic); semantic = agents; hard gates = enforced by a
  hook, never by prose.
- **State/resume/rollback** → `sdlc-context.json` (checkpoint + resume-point); rollback = git. No
  engine-grade retry/rollback/checkpoint is ever encoded as if real.
- **Standards/de-dup** → CLAUDE.md (always-on) + cross-cutting skills + `shared-references/` +
  the duplication linter. Skills point to enforcers; never restate them.
- **Enforcement** → schemas (shape) + linter (cross-refs/cycles/orphans/drift) + tests, all CI-gated.

---

## 7. Housekeeping contract (non-negotiable)

**Before each major commit** (every integration→main merge, and any parent completion), update as
relevant:
- **`sdlc-context.json`** — the `architecture_review_campaign` block (current parent, integration
  branch, children done/remaining) **and** a dated `build_checklist` chunk entry.
- **`CHANGELOG.md`** — a dated `[Unreleased]` entry for the parent/step.
- **`CLAUDE.md`** — when the component model changes (new concept lands: manifest fields, catalog,
  workflow specs, shared-references, linter) — its Component Architecture / Layout / Frontmatter
  sections must reflect reality.
- **`README.md`** — when user-facing structure changes (new top-level dirs, new commands, new workflow
  concept) — the human-facing overview must reflect reality.

Per-child commits always carry a detailed message but need not touch all four files — only major commits
do. **A commit that changes the component model without updating CLAUDE.md is a defect.**

---

## 8. Resumability protocol (cold-start recovery)

A fresh agent on any machine/account resumes as follows:
1. Read `sdlc-context.json` → `architecture_review_campaign` → get `active_parent`,
   `integration_branch`, and the child checklist.
2. Read this charter (`ARCHITECTURE-REVIEW-CAMPAIGN.md`) for the full model and standards.
3. `git fetch` and check out the `integration_branch`.
4. Query the GitHub Project board / parent issue for the first **incomplete** child.
5. Continue from that child using the per-child lifecycle (Section 5).

No campaign state lives only in conversation memory. The board + `sdlc-context` + this charter are the
tape.

---

## 9. Non-negotiables (restated)

- One child issue per artifact. **No grouping.**
- **Detailed** parent and child issue descriptions.
- **Detailed** commit message on **every** commit.
- Test bundled with its artifact (TDD).
- Four-file housekeeping before every major commit.
- The charter + `sdlc-context` + board are always kept truthful — the linter enforces the rest.

---

## 10. Progress log

| Parent | Integration branch | Status | Children done / total | Merged to main |
|---|---|---|---|---|
| P1 | `arch-review/p1-governance-foundation` | **in progress** (parent #780; wave 1 done, wave 2 executing) | 6 / 10 | — |
| P2 | — | not started | 0 / 186 | — |
| P3 | — | not started | 0 / ~3 | — |
| P4 | — | not started | 0 / ~150 | — |
| P5 | — | not started | 0 / 13 | — |
| P6 | — | not started | 0 / 7 | — |
| P7 | — | not started | 0 / ~24 | — |
| P8 | — | not started | 0 / ~15 | — |
| P9 | — | not started | 0 / ~5 | — |

_This table is updated at each major commit; it is the at-a-glance resume pointer._
