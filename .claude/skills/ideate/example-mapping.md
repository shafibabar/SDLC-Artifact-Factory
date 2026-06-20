# Skill: ideate/example-mapping

## Purpose
Run an Example Mapping session for one User Story to clarify scope, surface rules, uncover edge cases, and produce BDD-ready examples. Example Mapping is the bridge between the story and the BDD feature file — it resolves ambiguity before implementation begins.

## Inputs
Read before generating:
- `artifacts/ideate/backlog/stories/{story-id}.md` — must exist
- `artifacts/ideate/personas/{persona}.md` — relevant persona
- **Argument required:** story ID

## Output
**File:** `artifacts/ideate/backlog/examples/{story-id}.md`
**Registers in manifest:** yes

## Example Mapping Structure (four card types)
- **Story (blue):** the user story being mapped — one per session
- **Rules (yellow):** business rules that govern the story's behaviour
- **Examples (green):** concrete scenarios that illustrate each rule (one example per rule minimum)
- **Questions (red):** open questions that cannot be answered now — must be resolved before the BDD feature file is written

## Process
1. Read the story and persona.
2. Restate the story in one sentence at the top.
3. Derive business rules from the story's acceptance criteria and functional requirements context.
4. For each rule, write at least one concrete example (a specific, named scenario with specific values — not generic descriptions).
5. Surface any questions that the story raises but does not answer.
6. If there are more than 3 open questions, flag the story as NOT READY — it should not proceed to BDD feature file generation until questions are answered.
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Example Map: {US-ID} — {Story Title}

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** Example Map
**Story ID:** {US-ID}
**Version:** 1.0
**Date:** {date}
**Status:** {Ready for BDD / NOT READY — open questions remain}

---

## Story (Blue)
> As a **{persona}**, I want to **{action}**, so that **{outcome}**.

---

## Rules and Examples

### Rule 1: {Business rule statement — e.g. Storage credentials must be validated before a location is accepted}
*Source: {functional requirement ID or acceptance criteria reference}*

#### Example 1.1: {Happy path — e.g. Valid read-only Google Drive credentials accepted}
- **Given:** Sarah (IT Administrator) has a Google Drive service account with read-only scope on the company's shared drives
- **When:** Sarah enters the service account credentials in the storage registration form and clicks Register
- **Then:** The system validates the credentials against the Google Drive API, confirms read-only scope, and creates the storage location record with status "Pending Initial Scan"

#### Example 1.2: {Rejection case — e.g. Credentials with write scope rejected}
- **Given:** Sarah provides a service account that has both read and write scope
- **When:** she submits the registration
- **Then:** The system rejects the registration with the message "Credentials must be scoped to read-only access. Please provide a read-only service account." and no storage location record is created

#### Example 1.3: {Failure case — e.g. Invalid credentials}
- **Given:** Sarah provides an expired or revoked service account key
- **When:** she submits the registration
- **Then:** The system returns "Could not authenticate with the provided credentials. Please verify the key is active." and no storage location record is created

---

### Rule 2: {Business rule statement — e.g. Registration is idempotent — re-registering the same location is a no-op}

#### Example 2.1: {e.g. Duplicate registration attempt}
- **Given:** The company's Google Drive workspace is already registered with status "Active"
- **When:** an administrator attempts to register the same workspace again with the same credentials
- **Then:** The system returns a success response with the existing storage location record — no duplicate is created and no error is shown

---

### Rule 3: {Additional rule}

#### Example 3.1:
- **Given:** {specific starting state with real values}
- **When:** {specific user action}
- **Then:** {specific, observable outcome}

---

## Open Questions (Red)

| # | Question | Why it blocks | Owner | Status |
|---|----------|--------------|-------|--------|
| Q1 | {e.g. Should the system test connectivity to the storage location immediately on registration, or defer to the first scan?} | {Affects whether registration can complete instantly or requires a network call} | {stakeholder} | Open |
| Q2 | {question} | {why it blocks an example or rule} | {owner} | Open |

---

## Readiness Assessment

| Check | Status |
|-------|--------|
| All rules have at least one happy-path example | ✓ / ✗ |
| All rules have at least one rejection/error example | ✓ / ✗ |
| Open questions count | {n} |
| Story is ready for BDD feature file generation | **Yes / No** |

**If No:** Resolve the open questions above before running `implement/bdd-feature-file` for this story.
```

## Quality Checks
Before writing:
- [ ] Every Rule has at least one happy-path Example and one rejection/error Example
- [ ] All Examples use specific, concrete values (real names, real numbers) — not generic placeholders
- [ ] Open Questions are genuine blockers, not just nice-to-haves
- [ ] Readiness assessment is honest — do not mark Ready if there are unresolved blocking questions
- [ ] No undefined ubiquitous language terms
