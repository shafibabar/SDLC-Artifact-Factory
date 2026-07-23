---
name: skill-authoring-standards
description: >
  Teaches how a Claude Code Agent Skill in this plugin must be shaped, written,
  discovered, versioned, and tested: the three-tier progressive disclosure model
  (metadata, body, references), the description field as the literal discovery
  surface rather than documentation, the resident-content threshold for when body
  content must move to references/, the two-surface versioning rule, declared
  composability via an optional related: field, and the scripts/ plus assets/
  convention for deterministic artifact generation and copyable templates.
  Consulted at the start of every skill-refactor session and whenever a new skill
  is created — the canonical rubric, not a convention imitated from whichever
  skill was refactored most recently. Cross-cutting governance skill alongside
  glossary-management and methodology-review.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-23
tags: [skill-authoring, progressive-disclosure, governance, cross-cutting, meta]
---

# Skill Authoring Standards

## Purpose

Every skill in this plugin is prose consumed by Claude, not code executed by a runtime — which means "does this skill work" can only be verified by triggering it and checking behavior, never by reading it for coherence. At 141 skills and counting, imitating whichever skill was refactored most recently is no longer a reliable way to keep new skills shaped consistently. This skill is the checkable rubric: a skill's shape, its `description`, its version bumps, and its cross-references against a stated standard, not a fresh judgment call every refactor session.

This skill governs *this plugin's own components*. It teaches nothing about a downstream product's domain — that is what every other skill does. It sits beside `glossary-management` (canonical vocabulary) and `methodology-review` (methodology compliance) as the third cross-cutting authority, this one about the shape of a Skill itself.

---

## The Four-Part Skill Shape

A skill directory has one mandatory part and three optional ones, added only when the content genuinely warrants them — most of this plugin's skills correctly have none of the three:

| Part | Mandatory? | Holds | Loaded when |
|---|---|---|---|
| `SKILL.md` | Always | Decision-shaping guidance: when to use what, what "good" looks like, the core procedure | Every time the skill's trigger surface matches |
| `references/*.md` | Optional | Reference material: full templates, worked examples, exhaustive checklists, deep explanatory content | Only when the body explicitly points to that file |
| `assets/*` | Optional | Copyable files meant to be used as-is in a produced artifact: a fill-in template, boilerplate config, an example file to copy from | Only when the skill's procedure calls for copying one into a new artifact |
| `scripts/*.sh` | Optional | Deterministic, single-purpose executables that scaffold or validate an artifact this skill governs | Only when the skill's procedure calls for running one via the Bash tool |

The test for which of the three optional parts a piece of content belongs in: if it's *prose you'd read*, it's a `references/` file. If it's a *file you'd copy into a new artifact largely unchanged*, it's an `assets/` file. If it's *something you'd run* to generate or check an artifact deterministically, it's a `scripts/` file. Content that fails all three tests — it's short, it shapes a decision, most invocations need it — stays in the `SKILL.md` body.

`scripts/` here is a different invocation context from the repo-root `scripts/` folder CLAUDE.md already documents (hook- or command-invoked). A skill-owned script is invoked by the agent applying that skill, via the Bash tool, at a path the skill's own body names (`skills/<name>/scripts/<script>.sh`) — the same "Scripts = Actions: atomic, deterministic, stateless, single-purpose" rule applies; only the location and the caller differ.

---

## Progressive Disclosure Is Three Cost Tiers, Not "Split the File"

| Tier | Content | Cost |
|---|---|---|
| 1 — Metadata | `name` + `description` | Resident every session, whether or not the skill fires — must be cheap and dense |
| 2 — Body | The `SKILL.md` content below the frontmatter | Loaded once the metadata triggers a match — can afford more detail, but still shared by every invocation |
| 3 — References | `references/*.md` | Loaded only when the body explicitly points to it — zero cost to invocations that never need it |

**The split threshold:** for every section of a `SKILL.md` body, ask whether it is *decision-shaping guidance* (stays at Tier 2) or *reference material* — a full template, a worked example, an exhaustive checklist, generated code (moves to Tier 3). As a concrete backstop, treat a body whose content below the frontmatter exceeds **200 lines** as a split candidate by default — not a hard rule that blocks anything, but a prompt to apply the test above rather than let a body grow indefinitely. A `references/` file must be **self-contained**: loadable and usable without assuming the parent `SKILL.md` body is also in context, since it may be loaded independently on a later turn or pointed to by a different skill entirely.

When a skill's `references/` directory holds more than one file, use the naming convention already converged on independently across this plugin's existing splits: `output-format-template.md` for the copyable template, `worked-example.md` for the illustrative instance.

---

## The `description` Field Is the Discovery Surface, Not a Summary

`description` is what Claude's skill-matching logic scores against a live prompt — it is not documentation written for a human skimming a directory listing. Draft it as if it were the *only* text available to decide whether this exact skill should fire: name the nouns and verbs a real request would contain, name the owning agent, name the command or phase that invokes it if applicable. A description that reads as an accurate topic summary but omits the usage condition ("when any agent is unsure whether a term is canonical, they check this skill first" — `glossary-management`'s own pattern) is weaker at its actual job than one that reads slightly less like a summary and more like a trigger condition.

---

## Single-Responsibility Boundary

A skill that quietly covers two unrelated capabilities produces a `description` that is either too vague to match precisely or too long to stay cheap at Tier 1. This is the same boundary CLAUDE.md's Component Architecture draws for architectural reasons ("Skills = Expertise... no reasoning, no decisions") — single-purpose skills are also what keeps a large, concurrently-registered skill roster individually matchable instead of degrading into a pile the matcher has to guess between.

---

## Declared Composability: the Optional `related:` Field

A skill's prose often points at another skill ("see `subdomain-distillation`'s `references/security-sensitive-subdomains.md`"). That pointer is invisible to any script or test — if the referenced skill is renamed, split, or has that file moved, nothing catches it until a human notices during an unrelated refactor. Document an optional `related:` frontmatter field (a short list of skill names this skill's body references in prose) as a lightweight, retrofit-as-you-go convention. It is not part of CLAUDE.md's closed seven-field Component Frontmatter schema and does not change required-field ordering — it is an additional, optional field for skills that choose to declare it, giving a future validation script something concrete to check.

---

## Versioning: Two Independently-Breaking Surfaces

A `description` edit can silently break discovery for prompts that used to match, without a single word of the body changing — a different kind of breaking change than a body edit that changes what the skill teaches once triggered. Apply this bump rule going forward (retrofitting past versions is not required):

| Change | Bump |
|---|---|
| `description` changes in a way that could change what prompts trigger it, or previously-taught guidance is reversed or removed | MAJOR |
| Body content added (new section, new anti-pattern, new quality criterion) without changing the trigger surface | MINOR |
| Wording-only fixes, typo corrections | PATCH |

---

## Testing: Behavior, Not Coherence

A skill's content is prose consumed by a model, not code executed by a runtime — reading it and nodding along proves nothing about whether it actually produces the intended behavior when triggered. The only trustworthy test is a live invocation: load the skill, give it a narrow, near-verbatim-answerable question whose correct answer only exists in the skill's content (ideally content that lives specifically in a `references/` file, so a passing test also proves the progressive-disclosure split is actually being followed), and assert on a quotable substring of the response. This is exactly what every `tests/skills/*.contract.sh` file already does via `tests/lib/harness.sh` — this skill names the philosophy the existing test suite already practices.

For a skill with `scripts/`, testing has a second, cheaper layer: the scripts themselves are ordinary deterministic code and belong in `tests/scripts/`, run against synthetic input with no live model call — the same category `scripts/*.sh` at the repo root already uses. A skill's contract test should additionally assert that its scripts actually run successfully end-to-end, not merely that the skill's prose mentions them.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Single responsibility | Skill covers one coherent capability; `description` names it precisely | Skill quietly covers two+ unrelated capabilities |
| `description` is a trigger surface | Names the nouns/verbs/owning agent a real prompt would contain | Reads as an accurate topic summary with no usage condition |
| Resident-content budget respected | Body holds only decision-shaping guidance; templates/worked examples/exhaustive checklists live in `references/` | A full template or worked example sits resident in the body |
| `references/` self-contained | Each reference file is usable without the parent body already in context | A reference file assumes prior body context it can't rely on being present |
| Scripts are deterministic and tested | Every `scripts/*.sh` has a corresponding `tests/scripts/*.test.sh` using synthetic input | A script exists with no test, or is only exercised via a live model call |
| Assets are genuinely copyable | An `assets/` file is usable as-is, dropped into a new artifact with minimal editing | An `assets/` file needs substantial rewriting to be usable — it should have been a `references/` template instead |
| Version bump matches change type | `description` changes bump MAJOR; body-only additions bump MINOR | A trigger-surface change ships as a MINOR/PATCH bump |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Description as documentation** — writing `description` as an accurate summary with no usage condition | The matcher has no trigger signal to score against; a technically-accurate description can still fail at its actual job | Draft it as the only text deciding whether this skill fires for a real prompt; name nouns, verbs, and the owning agent |
| **The unsplit skill** — a body that keeps growing past the point a reader would tolerate skimming, with a full template and worked example resident | Every invocation pays Tier-2 cost for content only some invocations need; the skill becomes a chore to read even when correct | Apply the resident-content test per section; move reference material to `references/`, keep only decision-shaping guidance in the body |
| **Implicit-only composability** — a prose "see `other-skill`" with no `related:` field backing it | Nothing catches a rename, split, or moved file on the referenced side; the pointer silently rots | Add the referenced skill to `related:`, retrofitting as skills come up for refactor rather than all at once |
| **The reference file that assumes body context** — a `references/*.md` file written as a continuation of the body's train of thought | Breaks the moment it's loaded independently, or pointed to by a different skill | Open every reference file able to stand alone; state the concept it needs before using it |
| **The script nobody tests** — a `scripts/*.sh` file whose only verification is that the skill's prose describes what it should do | A described behavior is not a verified one; a script can be broken for months if the skill itself is rarely triggered | Every skill-owned script gets a synthetic-input test in `tests/scripts/`, same as repo-root scripts |
| **The asset that isn't actually copyable** — an `assets/` file that needs substantial editing before it's usable in a real artifact | Defeats the purpose of an asset, which is to save the work of writing an artifact from scratch | If it needs substantial rewriting every time, it was reference material, not an asset — move it to `references/output-format-template.md` instead |
| **Version bump blindness** — bumping PATCH or MINOR for a `description` change that alters what prompts trigger the skill | Silently changes discovery behavior under a version number that implies nothing meaningful changed | Bump MAJOR whenever `description` changes in a way that could change matching, regardless of how small the body change was |

---

## Applying This Skill

When creating a new skill: write the `SKILL.md` body first, decide only afterward whether any content earned a `references/`, `assets/`, or `scripts/` split using the tests above — do not create empty subdirectories speculatively. When refactoring an existing skill: check it against every row of the Quality Criteria table above before treating the refactor as complete, not just against the specific gap that motivated the refactor.
