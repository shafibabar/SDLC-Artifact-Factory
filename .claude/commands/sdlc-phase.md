# Command: /sdlc-phase

## Purpose
Display the full state of a specific SDLC phase — artifacts produced, DoD status, gaps, and what can be generated next. The diagnostic view for a single phase.

## Usage
```
/sdlc-phase                    # Show current phase
/sdlc-phase {N}                # Show phase by number (1–8)
/sdlc-phase {name}             # Show phase by name (e.g. design, quality)
/sdlc-phase --all              # Show all phases in summary form
```

## Phase Number Map
| Number | Name | Skills |
|--------|------|--------|
| 1 | Strategy | vision, north-star, okrs, roadmap, gtm, bmc, stakeholders, competitive-analysis |
| 2 | Ideate | personas, requirements, impact-map, story-map, jtbd, moscow, backlog |
| 3 | Design | domain modelling, architecture, data, security, platform, UX |
| 4 | Implement | standards, TDD specs, BDD features, scaffolds, guides, contracts |
| 5 | Data | data models, analytics requirements, dashboards, pipelines, quality rules, reports |
| 6 | Quality | test plan, all test specs, performance, security, chaos, compliance |
| 7 | Deploy | CI/CD, IaC, Helm, GitOps, runbooks, SLOs, DR |
| 8 | Validate | UAT plan, scenarios, acceptance checklist, beta program, metrics |

## Execution

### Step 1: Load state
```
Read: sdlc-manifest.json → current_phase, artifacts, dod_gaps
Read: sdlc-config.json → product_name
Resolve: target phase from argument or default to current_phase
```

### Step 2: Compute DoD status for target phase

For each DoD item in the target phase (from CLAUDE.md Phase Definitions of Done):
- Check if the required artifact exists at its expected path
- Check if it is registered in the manifest as "complete"
- Label: DONE ✓ | MISSING ✗ | WARNED ⚠

### Step 3: List available skills for this phase

From plugin.json:
- Identify all skills declared for this phase
- For each skill: check if its output artifact exists
- Label: Generated | Not yet generated | Requires argument

### Step 4: Output

```
═══════════════════════════════════════════════════════════════
Phase {N}: {Phase Name} {← CURRENT | COMPLETE | FUTURE}
Product: {product_name}
═══════════════════════════════════════════════════════════════

Definition of Done
──────────────────
  ✓ vision.md — produced
  ✓ north-star.md — produced
  ✓ okrs.md — produced
  ✗ roadmap.md — MISSING
  ⚠ stakeholders.md — gap acknowledged
  ✓ terminology scan — last run: {date}

DoD status: {N} complete, {N} missing, {N} gaps acknowledged

Available Skills
────────────────
  strategy/vision                   → artifacts/strategy/vision.md              [Generated]
  strategy/north-star               → artifacts/strategy/north-star.md          [Generated]
  strategy/okrs                     → artifacts/strategy/okrs.md                [Generated]
  strategy/roadmap                  → artifacts/strategy/roadmap.md             [MISSING]
  strategy/gtm                      → artifacts/strategy/gtm.md                 [Generated]
  strategy/bmc                      → artifacts/strategy/bmc.md                 [Generated]
  strategy/stakeholders             → artifacts/strategy/stakeholders.md        [Generated]
  strategy/competitive-analysis     → artifacts/strategy/competitive-analysis.md [Generated]

Next actions:
  Generate missing: /sdlc-artifact strategy/roadmap
  Advance phase:    /sdlc-next  (DoD gap: roadmap.md missing)
```

### For `--all` mode:

```
SDLC Progress — {product_name}
════════════════════════════════

Phase 1: Strategy          ██████████ COMPLETE  (8/8 artifacts, 0 gaps)
Phase 2: Ideate            ████████░░ COMPLETE  (7/8 artifacts, 1 gap acknowledged)
Phase 3: Design            ████████████ COMPLETE (30/30 artifacts, 0 gaps)
Phase 4: Implement         ████████░░ COMPLETE  (12/15 artifacts, 2 gaps acknowledged)
Phase 5: Data          ◄── ████░░░░░░ IN PROGRESS (4/7 artifacts)
Phase 6: Quality            ░░░░░░░░░░ PENDING
Phase 7: Deploy             ░░░░░░░░░░ PENDING
Phase 8: Validate           ░░░░░░░░░░ PENDING

Run /sdlc-phase 5 for Data phase detail.
Run /sdlc-next when Data phase DoD is satisfied.
```
