# Command: /sdlc-story

## Purpose
The story readiness workflow — the complete pipeline from raw story to implementation-ready. Invokes the backlog-refiner agent, verifies example mapping, produces TDD spec and BDD feature file, and declares the story Ready.

Usage:
```
/sdlc-story <story-id>
/sdlc-story <story-id> --tdd-only
/sdlc-story <story-id> --bdd-only
```

Options:
- `--tdd-only`: Skip story refinement; only generate or update the TDD spec
- `--bdd-only`: Skip story refinement; only generate or update the BDD feature file

---

## Pre-Flight Checks

- Verify `artifacts/ideate/backlog/stories/{story-id}.md` exists
- Verify current phase is `implement` or that the story belongs to a phase that permits it
- Load `sdlc-config.json` for product context

---

## Full Workflow (default — no flags)

### Step 1: Story Assessment

Read the story file. Show current status:

```
=== Story: {story-id} ===

{story title}
As a {persona}, I want {capability}, so that {outcome}

Status: DRAFT | READY | NOT READY
Acceptance criteria: {n}
Example mapping: {exists | missing}
TDD spec: {exists | missing}
BDD feature: {exists | missing}
```

### Step 2: Invoke Backlog Refiner Agent

Hand off to the `backlog-refiner` agent with:
- Full story content
- Example mapping content (if exists)
- Parent epic content
- Persona files
- Relevant domain model (commands, aggregates for this BC)

The agent runs the refinement process interactively, asking clarifying questions one at a time.

When the agent returns:
- Updated story file saved to `artifacts/ideate/backlog/stories/{story-id}.md`
- Status set to `READY` or `NOT READY + gaps`

If NOT READY: stop here and show the gap list. The story cannot proceed to TDD until gaps are resolved.

### Step 3: Example Mapping Check

If `artifacts/ideate/backlog/examples/{story-id}.md` does not exist, or has open questions (red cards):

```
Example mapping is incomplete for {story-id}.

Options:
  1. Run example mapping now (/sdlc-artifact ideate/example-mapping {story-id})
  2. Proceed without example mapping (WARN — TDD spec may be incomplete)
  3. Cancel

Choice (1/2/3): _
```

### Step 4: Generate TDD Specification

Run pre-implement hook checks, then invoke `implement/tdd-spec` skill:

```
Generating TDD specification...
  Reading story: artifacts/ideate/backlog/stories/{story-id}.md
  Reading examples: artifacts/ideate/backlog/examples/{story-id}.md
  Reading aggregates: artifacts/design/domain/aggregates/...

✓ TDD spec written: artifacts/implement/specs/{story-id}-tdd-spec.md
  {n} unit test cases (domain layer)
  {n} application test cases (mocked infrastructure)
  {n} integration test cases (real infrastructure — tagged)
```

### Step 5: Generate BDD Feature File

Invoke `implement/bdd-feature-file` skill:

```
Generating BDD feature file...

✓ Feature file written: artifacts/implement/features/{story-id}.feature
  {n} scenarios ({n} happy path, {n} error scenarios, {n} data-driven outlines)
```

### Step 6: Completion Summary

```
=== Story {story-id} — IMPLEMENTATION READY ===

  ✓ Story refined: READY (INVEST: all pass)
  ✓ TDD spec: artifacts/implement/specs/{story-id}-tdd-spec.md ({n} test cases)
  ✓ BDD feature: artifacts/implement/features/{story-id}.feature ({n} scenarios)

Developer instructions:
  1. Run the failing tests: go test -run TestStorageLocation ./internal/domain/...
  2. All tests should FAIL (Red) — implement until they pass (Green)
  3. Refactor to clean code standards; ensure tests still pass
  4. Request code review: /sdlc-artifact implement/code-review {bc-name}/{file}

Next story: /sdlc-story {next-story-id}
```

---

## Story Status Lifecycle

| Status | Set by | Meaning |
|--------|--------|---------|
| `DRAFT` | `/sdlc-artifact ideate/user-story` | Initial draft — not yet refined |
| `NOT READY` | `backlog-refiner` agent | Refinement gaps identified |
| `READY` | `backlog-refiner` agent | All DoR criteria met; TDD and BDD can proceed |
| `IN PROGRESS` | Developer (manual) | Implementation started |
| `DONE` | Developer (manual) | Implementation complete; all tests green |
