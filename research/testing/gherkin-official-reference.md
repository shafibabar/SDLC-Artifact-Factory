# Gherkin Official Reference
**Authors:** Cucumber project (cucumber.io)
**Domain:** Testing (Behavior-Driven Development)

Accessed 2026-11-25. The pages state no current Gherkin version; `Rule` is dated to Gherkin 6.

Sources:
- [G] https://cucumber.io/docs/gherkin/reference/
- [A] https://cucumber.io/docs/cucumber/api/

## Core Concepts

- One `Feature` per `.feature` file, as the first primary keyword. Keywords are localised; `# language:` selects the language [G].
- `Rule` (Gherkin 6 onward) groups scenarios illustrating one business rule [G].
- `Scenario` and `Example` are synonyms; 3 to 5 steps recommended [G].
- Steps: `Given` context, `When` action, `Then` observable outcome; `And`, `But`, `*` continue. Matching ignores the keyword, so the same text cannot be defined twice under different keywords [G].
- `Background`: shared steps run before each scenario (after Before hooks), placed before the first scenario; one per Feature or Rule; keep short [G].
- `Scenario Outline` (synonym `Scenario Template`) needs one or more `Examples` (or `Scenarios`) sections; `<placeholders>` come from table headers [G].
- Free-text descriptions are allowed under Feature, Rule, Background, Scenario and Outline if no line starts with a keyword; ignored at run time [G].
- **Comments** start with `#` at the start of a line (leading whitespace allowed); no block comments [G].
- Doc Strings use triple quotes or backticks; Data Tables are pipe rows with `\n`, `\|`, `\\` escapes [G].
- **Tags** go on Feature, Rule, Scenario, Scenario Outline and Examples, never Background or steps; children inherit them. Boolean tag expressions (`@smoke and not @slow`) select runs and conditional hooks [A].
- Hooks: scenario `Before`/`After` (After runs even on failure), step hooks, `BeforeAll`/`AfterAll`; support differs by implementation [A].

## Actionable Techniques

- Group scenarios under `Rule:`, one per business rule [G].
- Mark path type and criterion IDs with tags, not trailing comments [A] [G]; the ID convention itself is this repository's choice.
- Use tags on separate `Examples` blocks to run subsets of an outline [A].
- Keep a `Given` in outlines as good practice.

## Applies To

| Skill/Agent | Gap (from Wave 3 audit) | What the docs add |
|---|---|---|
| bdd-feature-file | W3A-40, W3A-41; trailing comment convention | Rule, tag and comment syntax |
| acceptance-criteria, example-mapping | rules-only structure | `Rule:` maps to a business rule |

## Candidate New Skills/Agents

None.

## Key Terminology

Feature File, Rule, Scenario, Scenario Outline, Examples, Background, Tag, Tag Expression, Doc String, Data Table [G] [A].

## Caveats

- These are Cucumber's pages. [unverified] godog's support for `Rule:`, tag expressions and these hooks; it belongs to the Go tools research.
- [unverified] Example Mapping and its time box were not researched.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3A-40: is `Rule:` Gherkin 6? | Yes [G] | Confirmed |
| Batch A narrative: must comments start their own line? | Yes [G] | Confirmed |
| Same: a trailing `# happy` becomes part of the scenario name | Follows from the comment rule; not stated by the page, not run | Unverified |
| Batch A narrative: are `@happy`/`@negative`/`@edge` tags valid? | Tags are supported on scenarios [A] | Confirmed |
| W3A-41: can `@AC-US-n.m` tags carry traceability? | Tags are allowed and selectable [A]; the docs do not state characters permitted in tag names | Confirmed for tagging; the exact format unverified |
| W3A-40: is an outline without `Given` invalid? | The page does not say | Unverified |
| W3D-27 / W3A-38: do feature files drive Playwright natively? | Not covered by these pages | Unverified |
