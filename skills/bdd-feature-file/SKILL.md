---
name: bdd-feature-file
description: >
  Teaches how to write Gherkin feature files as executable specifications — the
  Given/When/Then structure, mapping acceptance criteria to scenarios, scenario
  outlines for data variation, the ubiquitous-language rule for step wording,
  binding steps to Go step definitions (godog) and to frontend e2e, and keeping
  feature files as living documentation a PM can read. Covers the Specification
  Workshop definition-of-ready (business-language-only, one-rule-per-example,
  team-agreed — the Three Amigos collaborative-authorship expectation made
  checkable), Living Documentation's full two-part definition, and the Key
  Examples minimality principle, in
  references/collaborative-specification-and-living-documentation.md. Includes
  assets/bdd-feature-file-template.md and
  scripts/scaffold-bdd-feature-file.sh / scripts/validate-bdd-feature-file.sh.
  BDD is a mandatory methodology. Used by the test-strategist during Implement
  and Quality.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, bdd, gherkin, feature-file, godog, executable-spec, given-when-then]
produces: gherkin-feature-file
domain: testing
status: stable
---

# BDD Feature File

## Purpose

A feature file written in Gherkin is two things at once: a specification a Product Manager can read and approve, and an automated test that proves the system meets it. This is the heart of Behavior-Driven Development — Specification by Example — the acceptance criteria *are* the test, in the business's language. There is no translation gap between "what we agreed" and "what we verified" because they are the same artifact.

BDD is a non-negotiable methodology in this plugin (CLAUDE.md). Every acceptance criterion from the Ideate phase becomes a scenario here; the absence of feature files for acceptance criteria is a defect.

---

## Where Feature Files Come From

Feature files are not invented by the test-strategist — they are the realisation of the `requirements-analyst`'s `acceptance-criteria` (the Gherkin scenarios drafted during Ideate) and the `example-mapping` examples. The test-strategist takes those, refines them into executable scenarios, and binds them to step definitions.

```
acceptance-criteria (Ideate) ──► bdd-feature-file (Implement) ──► step definitions (Go/JS)
   the agreement                    the executable spec              the automation
```

The examples a feature file's scenarios are built from should come from a **Three Amigos** session — business, development, and testing perspectives deriving concrete examples together before Gherkin is finalised (see the canonical glossary; played solo by a single agent when no live multi-role team exists). In this repo that expectation is realised as a joint sanity check between `requirements-analyst` and `test-strategist`, not a one-directional handoff refined solo. `references/collaborative-specification-and-living-documentation.md` gives this a concrete, checkable definition-of-ready.

---

## Gherkin Structure

```gherkin
# features/classify_data_asset.feature
Feature: Classify a data asset
  As a Data Steward
  I want to set a data asset's sensitivity level
  So that downstream access control and retention apply correctly

  Background:
    Given a tenant "acme" with a data steward "maya"
    And a data asset "Q3 Report" exists with no classification

  Scenario: Successfully classify an asset
    Given Maya is authenticated with permission "data-assets:classify"
    When she classifies "Q3 Report" as "Confidential"
    Then the asset's sensitivity level is "Confidential"
    And a "DataAssetClassified" event is published

  Scenario: Reject classification without permission
    Given Maya is authenticated without permission "data-assets:classify"
    When she attempts to classify "Q3 Report" as "Confidential"
    Then the request is forbidden
    And the asset remains unclassified
```

| Keyword | Role |
|---|---|
| `Feature` | The capability, with the user-story framing (As/I want/So that) |
| `Background` | Shared `Given` steps run before each scenario |
| `Scenario` | One concrete example of behaviour |
| `Given` | Precondition — the world before the action |
| `When` | The action under test (exactly one, ideally) |
| `Then` | The observable outcome (assertions) |
| `And`/`But` | Additional steps of the preceding type |

---

## The Golden Triangle — Cover More Than the Happy Path

Every feature needs at least three scenarios (from `acceptance-criteria`): the happy path, a negative path, and an edge case. A feature with only a happy-path scenario is incomplete.

```gherkin
  Scenario: Successfully classify an asset            # happy
  Scenario: Reject classification without permission  # negative
  Scenario: Reject downgrade without reclassification # edge (the domain invariant)
```

These map directly to the user flows' branches (`ux-flow-design`) and to the backend's domain invariants (`go-domain-model`) — the feature file is where requirements, UX, and domain meet and are verified together.

---

## Scenario Outlines for Data Variation

When the same behaviour holds across many inputs, use a `Scenario Outline` with an `Examples` table instead of copy-pasting scenarios — this keeps the spec readable and the variations explicit.

```gherkin
  Scenario Outline: Sensitivity level drives required controls
    When an asset is classified as "<level>"
    Then access requires "<control>"
    And it is audited on read: <audited>

    Examples:
      | level        | control          | audited |
      | Public       | none             | false   |
      | Confidential | abac-permission  | false   |
      | Restricted   | abac-least-priv  | true    |
```

This mirrors the data-architect's classification control mapping (`data-classification`) — one spec, verified across every level.

An Examples table answers "how many rows," a question the Golden Triangle doesn't address (it governs *which angles* — happy/negative/edge — not *how many examples per angle*). `references/collaborative-specification-and-living-documentation.md` gives the minimality principle for pruning a table that's grown past what actually teaches the reader something new.

---

## Ubiquitous Language in Steps

Step wording uses the **canonical glossary terms** — "data asset," "sensitivity level," "classify," "tenant." Never synonyms ("file," "label," "tag"). Because feature files are read by Shafi and bind to code, drift in step language is drift in the product. Step phrasing is declarative (what, not how): "she classifies the asset," not "she sends a PATCH to /v1/data-assets/{id}/classification" — the HTTP detail lives in the step definition, not the spec. This declarative discipline is this repo's permanent instance of Ken Pugh's ATDD point (`research/requirements-and-user-stories/lean-agile-atdd-pugh.md`) and Gojko Adzic's framing of Given/When/Then as illustrating a business rule, not scripting a UI interaction (`research/testing/specification-by-example-adzic.md`) — cited here as provenance, not an unattributed local rule.

---

## Binding Steps to Automation

### Backend — godog (Cucumber for Go)
Each `Given/When/Then` maps to a Go step function. Steps drive the system through its public interface (API/command handlers), not its internals (black-box — see the test-strategist's functional-testing stance).

```go
func (w *world) sheClassifiesAs(asset, level string) error {
    return w.api.Classify(w.ctx, w.assetID(asset), domain.SensitivityLevel(level))
}

func InitializeScenario(ctx *godog.ScenarioContext) {
    w := &world{}
    ctx.Before(w.reset)                                  // hermetic: fresh state per scenario
    ctx.Step(`^she classifies "([^"]*)" as "([^"]*)"$`, w.sheClassifiesAs)
    ctx.Step(`^the asset's sensitivity level is "([^"]*)"$`, w.assertSensitivity)
}
```

### Frontend — the same scenarios drive Playwright
Journey-level scenarios bind to Playwright e2e steps (see `react-e2e-testing`), so a single Gherkin scenario can be verified at the UI level too. The spec is shared; the bindings differ per layer.

---

## Living Documentation

Feature files live in the repo (`features/`), are reviewed in PRs, and run in CI. They are always current because a stale scenario fails the build. This makes them trustworthy documentation — unlike a wiki page, a feature file cannot quietly drift from the system, because it *is* tested against the system.

This is half of what "living documentation" actually requires. `references/collaborative-specification-and-living-documentation.md` covers the other half: mechanically deriving a browsable documentation artifact from the executed spec suite, so what a PM reads is generated from verified results — not a raw `.feature` file browsed in a repo.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Traceable to criteria | Every acceptance criterion has a scenario | Acceptance criteria with no feature file |
| Golden triangle | Happy + negative + edge per feature | Happy-path-only features |
| Declarative steps | Steps say what, not how (no HTTP/SQL in the spec) | Implementation detail leaking into Gherkin |
| Ubiquitous language | Canonical glossary terms in steps | Synonyms / informal wording |
| Outlines for variation | Scenario Outline + Examples for data sets | Copy-pasted near-identical scenarios |
| Hermetic | Fresh state per scenario (Background + Before) | Scenarios depending on prior scenario state |
| Executable & current | Bound to step defs; runs in CI | Feature files that don't execute |

---

## Anti-Patterns

- **Imperative scripts in Gherkin** — "she sends a PATCH with header X" is a test script, not a specification; the HTTP mechanics belong in the step definition.
- **Multiple `When` steps in one Scenario** — two actions means two behaviours; split the Scenario so a failure names one behaviour.
- **Scenarios chained on prior Scenario state** — every Scenario must be runnable alone and in any order; shared setup goes in `Background` or a `Before` hook.
- **`Then` steps with no observable assertion** — "Then the system processes the request" verifies nothing; assert an outcome a user or downstream consumer can observe (state, response, Domain Event).
- **Feature files written after the code** — they become descriptions of what was built, not specifications of what was agreed; BDD writes the Scenario first.
- **Synonym drift in steps** — "file," "label," "tag" instead of "data asset," "sensitivity level," "classification" silently forks the Ubiquitous Language.
- **Untended specification growth** — duplicated step definitions, overlapping scenarios, and scenarios that no longer reflect a live business rule left to accumulate as the suite grows, until no one trusts whether the whole suite still reflects live behaviour. Refactor the specification suite the way disciplined teams refactor production code, not as an afterthought (see `references/collaborative-specification-and-living-documentation.md`).

---

## Output Format

Produces Gherkin feature files plus their step definitions (written before implementation — BDD):

```
features/*.feature                         (Gherkin scenarios — readable by Shafi)
internal/test/bdd/steps_*.go               (godog step definitions)
tests/e2e/*.spec.ts                         (journey scenarios bound to Playwright)
```

- **Starting a new feature file** — copy `assets/bdd-feature-file-template.md`, or run `scripts/scaffold-bdd-feature-file.sh` to generate one pre-filled with the Golden Triangle's three tagged placeholder scenarios.
- **Checking a feature file mechanically** — run `scripts/validate-bdd-feature-file.sh` to check Golden Triangle tag presence, imperative/HTTP-mechanics leakage in step text, and multiple-`When`-per-scenario.
- **Going deeper on collaborative authorship, living documentation, or example minimality** — read `references/collaborative-specification-and-living-documentation.md`.
