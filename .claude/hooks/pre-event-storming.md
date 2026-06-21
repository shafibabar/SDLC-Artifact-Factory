# Hook: pre-event-storming

## Trigger
Fires immediately before `/sdlc-event-storm` begins Part 1 (Big Picture Event Storming).

## Purpose
Validate that the product context is rich enough to support a productive Event Storming session. An under-prepared session wastes time; this hook catches the most common preparation gaps before starting.

---

## Checks

### 1. Minimum artifact coverage

| Artifact | Status if missing |
|----------|-----------------|
| `artifacts/strategy/vision.md` | WARN — session can proceed but domain grounding will be weak |
| `artifacts/ideate/requirements/functional.md` | FAIL — Event Storming without functional scope is unanchored |
| `artifacts/ideate/personas/` (at least one file) | WARN — facilitator needs to know the actors |
| `artifacts/ideate/jtbd.md` | INFO — helpful context for scenario generation |

If any FAIL: block the session start and show the resolution path.

### 2. Problem statement quality

Read `sdlc-config.json` → `problem_statement`.

Flag if:
- Problem statement is under 50 characters (too vague)
- Problem statement uses generic language like "improve", "optimize", "better" without measurable context

Output: WARNING with prompt to enrich the problem statement before the session.

### 3. Session time estimate

Based on the number of functional requirements in `functional.md`:
- < 20 FRs: "Expect a focused 2–3 turn session"
- 20–50 FRs: "Expect a detailed 4–6 turn session — consider breaking into multiple sittings"
- > 50 FRs: "Large scope detected. Strongly recommend scoping to one subdomain per session. Proceed?"

### 4. Previous session detection

Check if `artifacts/design/event-storm-session.md` already exists.

If exists:
```
An Event Storming session file already exists from {date}.
Status: {status from session file}

Options:
  1. Resume the existing session (recommended) — /sdlc-event-storm --resume
  2. Start a new session (will archive the previous session file)
  3. Cancel

Choice (1/2/3): _
```

---

## Output Format

```
=== Pre-Event Storming Checks ===

  ✓ Vision statement found
  ✓ Functional requirements found (34 requirements)
  ⚠ Personas: Only 1 persona file found — consider adding more before session
  ℹ JTBD analysis not found — facilitator will work without it

Scope estimate: Medium session (34 FRs) — expect 4–5 turns

{FAIL case:}
  ✗ Functional requirements missing — session cannot proceed
    Fix: /sdlc-artifact ideate/functional-requirements

{All pass case:}
  All required artifacts present. Starting Event Storming...
```
