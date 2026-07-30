# Skill Authoring Vocabulary and Collision Detection

Self-contained reference for `skill-authoring-standards`. Defines the six
named concepts the SKILL.md body uses but does not define in full, and
covers the periodic collision-detection practice for large skill libraries.

---

## Defined Terms

### Trigger Surface

The only content resident in context for every session, whether or not a
skill fires: the `name` field plus the `description` field. Everything else
in a `SKILL.md` — the body, any `references/` files — loads only after the
trigger surface has matched.

Practical consequence: a weak `description` wastes a strong body. If the
trigger surface does not match the prompt, the body is never loaded. Draft
`description` as if it were the *only* text available to decide whether this
skill should fire.

---

### Resident Content

Content loaded into context the moment a skill's trigger surface matches,
regardless of whether the specific triggering task needs that section.

Resident content is the Tier-2 body: everything below the frontmatter in
`SKILL.md`. The **200-line body threshold** in `skill-authoring-standards`
is a direct proxy for resident-content cost: a body that has grown to
include a full template and a worked example is paying Tier-2 cost (loaded
on every invocation) for material that most invocations never use — the
definition of a split candidate.

The test for whether content should be resident: if removing it would leave
the body without the decision-shaping guidance needed to act on a typical
invocation, it is resident by right. If removing it would only mean "some
invocations would need to load a reference file to get the full detail," it
is a `references/` candidate.

---

### Skill Collision

Two (or more) skills whose `description`s both plausibly match a single real
prompt, creating ambiguous routing — the matcher may route to either, neither
consistently.

Collisions become more likely as a skill library grows past ~50 entries and
are particularly common in adjacent domains (e.g., `access-control-model` vs
`zero-trust-design`, or the several DDD skills all owned by `domain-modeler`).
They are invisible to per-skill behavioral contract tests, which by
construction test one skill in isolation and cannot catch two skills
competing for the same prompt.

Symptoms of a latent collision:
- Two skills in the same domain whose `description` fields use nearly identical
  nouns and verbs without distinguishing the ownership condition
- A skill that answers questions it does not own because it matched before the
  correct skill did
- A prompt that should trigger one skill reliably but sometimes triggers another

---

### Progressive Disclosure

The three-tier loading model for a skill's content — not merely "split the file
into multiple files":

| Tier | Content | Loaded when |
|---|---|---|
| 1 — Trigger surface | `name` + `description` | Every session, always |
| 2 — Body | `SKILL.md` content below frontmatter | Once the trigger surface matches |
| 3 — References | `references/*.md` files | Only when the body explicitly points at them |

The model's value is that Tier-3 content costs nothing to sessions that never
need it — a 300-line worked example in a `references/` file imposes zero
context cost on the 80% of invocations that never ask for a worked example.
The same content resident in the body imposes that cost on every invocation.

---

### Declared Composability

A machine-checkable cross-skill dependency — specifically, this plugin's
optional `related:` frontmatter field — as opposed to **Implicit Composability**
(a prose mention of another skill that no test or script can validate).

| Form | Mechanism | Caught by a script? |
|---|---|---|
| Declared | `related: [other-skill]` in frontmatter | Yes — `validate-skill-structure.sh` can verify the referenced skills exist |
| Implicit | "See `other-skill`'s `references/x.md`..." in prose | No — invisible to any automated check; silently rots if the skill is renamed |

The `related:` field is not part of the closed Component Frontmatter required
schema — it is an optional, retrofit-as-you-go addition. Declare it when a
skill's body already makes prose references to specific other skills; let it
accumulate naturally during refactors rather than requiring a one-time audit.

---

### Self-Contained Reference

A `references/` file written so that loading it alone — with no assumption the
parent `SKILL.md` body is also in context — is sufficient to use it.

Required because Claude may load a `references/` file:
- Independently on a later turn (the body loaded on a previous turn, the
  session has moved on)
- Via a pointer from a *different* skill that cross-references this file

A reference file that opens with "As described in the body above..." or assumes
the reader already knows a concept introduced in the body violates this
requirement. Open every reference file with enough context to be usable
stand-alone — a one-sentence statement of what concept the file covers and
which skill owns it is sufficient, and is the pattern `SKILL.md` bodies in
this plugin already use as their opening line for their own body sections.

---

## Periodic Collision Detection

A full pairwise comparison of all skills' `description` fields for semantic
overlap is combinatorially expensive and is explicitly deferred as a standing
CI gate (too many live model calls for this repo's frugality constraint).

A practical, affordable alternative:

**Target only known-adjacent skill pairs.** These are pairs that share an
owning agent, a phase, or a domain tag and whose `description` fields use
overlapping nouns. Current candidates in this plugin (checked by grep):

| Pair | Shared terms |
|---|---|
| `access-control-model` / `zero-trust-design` | authorization, access, policy |
| `security-architecture` / `security-implementation` | security |
| `distributed-tracing-design` / `opentelemetry-instrumentation` | tracing, spans |
| `prometheus-metrics-design` / `metrics-instrumentation-plan` | metrics |
| `domain-event-catalog` / `event-schema-design` | event, schema |

**Sampling cadence:** after any batch of skill additions or description edits
(not per-refactor), pick 3–5 adjacent pairs, craft a prompt that could
reasonably trigger either skill in the pair, invoke each skill directly, and
confirm the correct one fires. This is a judgment check, not an automated
test — record the outcome as a comment in the next housekeeping issue.

**The collision fix:** if two skills consistently compete for the same prompt,
the fix is in `description`, not in the body — sharpen the owning agent, the
phase, or the usage condition to distinguish them at Tier 1 before they reach
the body. A description edit that resolves a collision is a MAJOR version bump
(trigger surface changed).
