# Skill: ideate/story-map

## Purpose
Produce a User Story Map — a two-dimensional arrangement of user stories that preserves the narrative of user activity. The horizontal axis tells the story of how a user accomplishes a goal (activities and steps). The vertical axis slices those steps into release tiers (MVP slice, Phase 2 slice, etc.). The Story Map makes scope and sequence visible and prevents building disconnected features.

## Inputs
Read before generating:
- `artifacts/ideate/requirements/functional.md` — must exist
- `artifacts/ideate/personas/` — read all personas
- `artifacts/strategy/roadmap.md` — for release slicing alignment
- `artifacts/ideate/impact-map.md` — recommended

## Output
**File:** `artifacts/ideate/story-map.md`
**Registers in manifest:** yes

## Story Map Levels
1. **Activities** — high-level user goals (e.g. "Register a storage location", "Review compliance posture"). These span the top row.
2. **Steps** — the sequence of actions a user takes within each activity (e.g. "Provide storage credentials", "Select scan scope"). These form the backbone row under activities.
3. **Stories** — specific user stories that fulfil each step. Stacked vertically below the step, ordered by priority. The horizontal cut across a priority tier defines a release.

## Process
1. Read functional requirements, personas, roadmap, and impact map.
2. Identify the primary user journey for the main persona (the most important user type).
3. Write the Activities (4–8 top-level goals that span the full user journey).
4. For each Activity, write the Steps (the backbone narrative).
5. For each Step, write 1–4 User Stories, ordered by priority.
6. Draw the release slice lines: what stories are in the MVP slice vs Phase 2 slice.
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# User Story Map

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** User Story Map
**Version:** 1.0
**Date:** {date}
**Primary Persona:** {persona name / role}
**Status:** Draft

---

## The User Narrative
{One paragraph telling the complete story of how the primary persona accomplishes their main goal using the product — from first contact to success. This is the narrative the map below illustrates.}

---

## Story Map

### Activity 1: {e.g. Get Started}
*Goal: {what the user wants to achieve in this activity}*

| Step | MVP Slice | Phase 2 Slice | Phase 3 Slice |
|------|-----------|---------------|---------------|
| **{Step 1.1: e.g. Create account}** | As a {persona}, I want to sign in with my company's identity provider so that I do not manage separate credentials | As a {persona}, I want to invite team members during onboarding so that the team is set up in one session | — |
| **{Step 1.2: e.g. Register storage location}** | As a {persona}, I want to connect my Google Drive workspace so that the product can begin scanning my files | As a {persona}, I want to connect my AWS S3 bucket so that cloud storage is also in scope | As a {persona}, I want to connect my SharePoint site so that Microsoft 365 content is included |
| **{Step 1.3: e.g. Configure scan settings}** | As a {persona}, I want to set a resource cap for the initial scan so that the scan does not impact production performance | As a {persona}, I want to define which file types to include or exclude so that scan scope matches my compliance needs | — |

---

### Activity 2: {e.g. Monitor the data estate}
*Goal: {what the user achieves}*

| Step | MVP Slice | Phase 2 Slice | Phase 3 Slice |
|------|-----------|---------------|---------------|
| **{Step 2.1: e.g. View entity graph}** | As a {persona}, I want to see a graph of all entities and their locations so that I have a complete map of what data we hold and where | As a {persona}, I want to filter the graph by entity type so that I can focus on specific compliance concerns | — |
| **{Step 2.2: e.g. View compliance dashboard}** | As a {persona}, I want to see my SOC 2 compliance posture at a glance so that I can assess audit readiness without manual effort | As a {persona}, I want to see GDPR compliance posture so that I can fulfil data subject rights obligations | — |

---

### Activity 3: {next activity — continue pattern}

---

### Activity {N}: {last activity — e.g. Act on findings}

---

## Release Slices

### MVP Slice
{Restate the MVP in one sentence: the minimum set of stories from the backbone that deliver the core value proposition end-to-end.}

**Stories included:**
- {Activity 1, Step 1.1, MVP story}
- {Activity 1, Step 1.2, MVP story}
- {Activity 2, Step 2.1, MVP story}
- {... etc}

### Phase 2 Slice
{Stories that expand on the MVP for the next release.}

### Phase 3 Slice (if applicable)
{Further expansions.}

---

## Story Count Summary

| Slice | Story count | Activities covered |
|-------|-------------|-------------------|
| MVP | {n} | {activities} |
| Phase 2 | {n} | {activities} |
| Phase 3 | {n} | {activities} |
| **Total** | {n} | All |
```

## Quality Checks
Before writing:
- [ ] Activities tell a coherent narrative from left to right — a user could read the activity row and understand the full product journey
- [ ] Every step in the backbone belongs to exactly one activity
- [ ] Every story is written in "As a / I want to / so that" format
- [ ] The MVP slice is the thinnest horizontal cut that delivers end-to-end value
- [ ] No story in the MVP slice is purely internal/infrastructure
- [ ] No undefined ubiquitous language terms
