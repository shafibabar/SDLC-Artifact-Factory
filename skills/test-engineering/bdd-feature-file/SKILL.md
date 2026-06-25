---
name: bdd-feature-file
description: >
  Teaches how to write Gherkin feature files as executable specifications — the
  Given/When/Then structure, mapping acceptance criteria to scenarios, scenario
  outlines for data variation, the ubiquitous-language rule for step wording,
  binding steps to Go step definitions (godog) and to frontend e2e, and keeping
  feature files as living documentation a PM can read. BDD is a mandatory
  methodology. Used by the test-strategist during Implement and Quality.
version: 1.0.0
phase: implement
owner: test-strategist
tags: [implement, quality, bdd, gherkin, feature-file, godog, executable-spec, given-when-then]
---

# BDD Feature File

## Purpose

A feature file written in Gherkin is two things at once: a specification a Product Manager can read and approve, and an automated test that proves the system meets it. This is the heart of Behavior-Driven Development — the acceptance criteria *are* the test, in the business's language. There is no translation gap between "what we agreed" and "what we verified" because they are the same artifact.

BDD is a non-negotiable methodology in this plugin (CLAUDE.md). Every acceptance criterion from the Ideate phase becomes a scenario here; the absence of feature files for acceptance criteria is a defect.

---

## Where Feature Files Come From

Feature files are not invented by the test-strategist — they are the realisation of the `requirements-analyst`'s `acceptance-criteria` (the Gherkin scenarios drafted during Ideate) and the `example-mapping` examples. The test-strategist takes those, refines them into executable scenarios, and binds them to step definitions.

```
acceptance-criteria (Ideate) ──► bdd-feature-file (Implement) ──► step definitions (Go/JS)
   the agreement                    the executable spec              the automation
```

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

---

## Ubiquitous Language in Steps

Step wording uses the **canonical glossary terms** — "data asset," "sensitivity level," "classify," "tenant." Never synonyms ("file," "label," "tag"). Because feature files are read by Shafi and bind to code, drift in step language is drift in the product. Step phrasing is declarative (what, not how): "she classifies the asset," not "she sends a PATCH to /v1/data-assets/{id}/classification" — the HTTP detail lives in the step definition, not the spec.

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

## Output Format

Produces Gherkin feature files plus their step definitions (written before implementation — BDD):

```
features/*.feature                         (Gherkin scenarios — readable by Shafi)
internal/test/bdd/steps_*.go               (godog step definitions)
tests/e2e/*.spec.ts                         (journey scenarios bound to Playwright)
```
