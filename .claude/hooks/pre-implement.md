# Hook: pre-implement

## Trigger
Fires before `/sdlc-artifact implement/service-skeleton` and before any code generation command that produces implementation code.

## Purpose
Enforce the TDD contract: no implementation code is generated unless a TDD specification exists and has been reviewed. Also verify that BDD feature files exist for the stories being implemented.

---

## Checks

### 1. TDD Spec existence check

For the story or feature being implemented:
- Check `artifacts/implement/specs/{story-id}-tdd-spec.md` exists
- If missing: **BLOCK** with message:

```
TDD spec missing for {story-id}.

A TDD specification must exist before implementation code is generated.
This is a non-negotiable methodology requirement (Red → Green → Refactor).

Fix: /sdlc-artifact implement/tdd-spec {story-id}

If implementing across multiple stories, each story needs its own TDD spec.
Acknowledge and bypass? (yes — with justification / no)
```

If user acknowledges with justification: record in manifest `phases.implement.warnings[]` with code `MISSING_TDD_SPEC` and the provided justification. Allow continuation.

### 2. BDD feature file existence check

For the story being implemented:
- Check `artifacts/implement/features/{story-id}.feature` exists
- If missing: **WARN** (not block — BDD is required for DoD but may be written after skeleton):

```
Warning: BDD feature file missing for {story-id}.
  Fix: /sdlc-artifact implement/bdd-feature-file {story-id}
  This must be resolved before the Implement phase DoD can be satisfied.
```

### 3. Story readiness check

Read `artifacts/ideate/backlog/stories/{story-id}.md`:
- Check for `Status: READY` (set by backlog-refiner agent)
- If status is `NOT READY` or `DRAFT`: **WARN**:

```
Warning: Story {story-id} is not marked as READY.
  The backlog-refiner agent has flagged open gaps.
  Review: artifacts/ideate/backlog/stories/{story-id}.md → "Refinement Gaps"
  Run /sdlc-story {story-id} to complete refinement.
```

### 4. Design phase dependency check

Verify that the design artifacts needed for implementation exist:
- `artifacts/design/domain/aggregates/` — at least one file
- `artifacts/design/domain/commands.md`
- `artifacts/design/domain/events.md`
- `artifacts/design/bounded-contexts.md`

If any are missing: **BLOCK** with guidance to complete the design phase first.

### 5. Coding standards check

Verify `artifacts/implement/standards/coding-standards.md` exists. If not: **BLOCK** — coding standards must be agreed before any code is generated.

---

## Output Format

```
=== Pre-Implement Check ===

  ✓ Design artifacts: present
  ✓ Coding standards: present
  ✓ TDD spec: artifacts/implement/specs/US-004-tdd-spec.md
  ⚠ BDD feature file: missing — run /sdlc-artifact implement/bdd-feature-file US-004
  ⚠ Story status: DRAFT — run /sdlc-story US-004 to complete refinement

{All clear:}
  ✓ All pre-implement checks passed. Proceeding with implementation.
```
