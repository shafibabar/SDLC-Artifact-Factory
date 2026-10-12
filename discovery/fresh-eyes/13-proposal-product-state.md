# Proposal 13 — Product state and approvals (#1251 + #1253)

**Status:** proposal for Shafi's decision. No code has changed.

## The problem in one paragraph

The plugin has no defined place where a *product's* state lives. Commands read `sdlc-context.json`, but that is the name of the **plugin's own** build-memory file, so in a fresh product repo Claude either finds nothing or wanders off and reads the plugin's file (dogfood pass 01, step 1). Nothing records which phase a product is in, and nothing records an approval. Every artifact stays `"status": "draft"` after the user approves it. The phase gate therefore can only check "does the previous phase's folder contain any file?", which a single half-finished draft satisfies.

## What happens today (verified on `main`, 2026-10-12)

| Mechanism | What it does | Problem |
|---|---|---|
| `sdlc-context.json` | 13 of 15 commands read it; `/sdlc-start` writes `first_product` into it | Same file name as the plugin's own memory; no schema for a product's copy |
| "Confirm `sdlc-context.json`'s checklist reflects it" | The last step of 9 phase commands | That checklist is the **plugin's** build checklist, and it has moved to `sdlc://self/build_checklist` anyway |
| `/sdlc-adr` | Appends to `sdlc-context.json`'s `decisions` array | That array no longer exists (moved to project memory) |
| `/sdlc-status` | Reports the plugin's factory build status first | Meaningless to a product user (dogfood step 4) |
| `artifacts/<product>/_manifest.json` | Hook-maintained registry; `status` can be `draft`, `approved` or `superseded` | Nobody ever writes `approved` |
| `pre-phase-advance` hook | Allows an agent if the previous phase's folder has any file | No notion of "complete" or "approved" |

## Proposed design

**One rule: a product's state lives in its manifest.** `artifacts/<product>/_manifest.json` is already per-product, schema-validated (since #1252) and maintained by the hook. It gains two product-level fields:

```json
"current_phase": "ideate",
"phases": {
  "strategy": { "status": "approved", "approved_on": "2026-10-12" },
  "ideate":   { "status": "in-progress" }
}
```

Per-artifact approval keeps using the existing `status` field.

**One small script owns every write of state**, so no agent hand-edits JSON that a hook also rewrites. `scripts/product-state.py` (repo-root, called by commands through `${CLAUDE_PLUGIN_ROOT}`):

| Command | When it runs | What it does |
|---|---|---|
| `init <slug> "<name>"` | `/sdlc-start` | Creates the manifest with `current_phase: strategy` |
| `approve <artifact path>` | Right after the user approves an artifact at a gate | Sets that entry's `status: approved` |
| `complete <phase>` | End of a phase command | Checks every **required** artifact for the phase is approved, then marks the phase approved and advances `current_phase`; otherwise lists what is missing |
| `status` | `/sdlc-status`, `/sdlc-next` | Plain-language JSON: phase, approved/draft counts, what's missing |

**The gate reads the same state.** `pre-phase-advance` allows an agent only if the preceding phase's status is `approved`, instead of "folder not empty".

**Which artifacts are "required" per phase** comes from a shipped file, `phase-requirements.json`. Proposal 14 (output scaling) uses the same file to vary the set by product size, so the two proposals share one mechanism.

**Product repos stop using the name `sdlc-context.json`.** A product repo holds:
- `sdlc-config.json`: its tech-stack overrides (unchanged);
- `artifacts/<product>/_manifest.json`: artifacts, approvals, phase;
- `.sdlc-memory/`: decisions and open questions (#1249 made these work).

The plugin's own `sdlc-context.json` stays as the factory's memory and is no longer read by any user-facing command.

**Commands lose their factory-only steps:**
- the "confirm the checklist" line becomes `product-state.py complete <phase>`;
- `/sdlc-adr` records decisions in project memory;
- `/sdlc-status` drops factory build status. That status moves to the internal `.claude/commands/`, if wanted at all.

## Decisions for Shafi

| # | Decision | Recommendation | Why |
|---|---|---|---|
| 1 | Where product state lives | **The manifest** (alternative: a product-level `sdlc-context.json` with its own schema) | It already exists, has a schema and has one writer. A second file with the plugin's own file name is what confused Claude in the dogfood run. |
| 2 | Approval granularity | **Per artifact, rolled up to the phase** (alternative: per phase only) | It matches the approval gates the agents already stop at, and it shows exactly what is still unapproved. |
| 3 | Gate strictness | **Block** an agent when the previous phase is not approved, with a message naming the missing approvals (alternative: warn only) | The phase gate is the plugin's core promise. You can always say "proceed anyway", and that is recorded as a decision. |
| 4 | Who records an approval | **Only after the user explicitly approves in the conversation**; the agent runs `approve`, and never self-approves | Keeps a human sign-off meaningful (and matches the acceptance-sign-off skill's rule against unilateral sign-off). |

## Size and order

About 1 script with its tests, 1 hook change, 15 command edits, 2 skill edits (`artifact-manifest`, `memory-recall`) and 1 schema change. The pieces depend on each other, so they ship as **one PR**. Proposal 14's `phase-requirements.json` is needed first. Shipping it with a single profile equal to today's full set (what proposal 14 calls `enterprise`) lets this land before the scaling decisions are made.

## Tied issues

- #1251 (product vs plugin state) and #1253 (approvals not persisted): closed by this.
- #1254 (agents without Bash): partly eased. Approvals are recorded by the **command** (the main session, which has Bash), not by the agent.
