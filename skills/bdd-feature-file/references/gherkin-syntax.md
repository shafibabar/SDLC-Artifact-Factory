# Gherkin Syntax and Tags

Self-contained. Use when writing or fixing a `.feature` file. From the Cucumber project's Gherkin reference unless marked as this plugin's rule. Behaviour of a particular runner must be confirmed by running it.

## Keywords

| Keyword | Meaning | Notes |
|---|---|---|
| `Feature` | One per file, first primary keyword | Plugin: with As a / I want / So that |
| `Rule` | Groups scenarios for one business rule (Gherkin 6 onward) | Runner support: godog's is not verified; check before relying on it |
| `Background` | Steps run before each scenario, after Before hooks | One per Feature or Rule, before the first scenario; keep short. Plugin: Given only |
| `Scenario` (= `Example`) | One concrete example | 3 to 5 steps recommended |
| `Given` | Context | A state that holds |
| `When` | Action | Plugin: exactly one per scenario |
| `Then` | Observable outcome | |
| `And`, `But`, `*` | Continue the previous step type | |
| `Scenario Outline` (= `Scenario Template`) | Run once per Examples row | Needs one or more `Examples`; `<name>` comes from a column header |

- Step matching ignores the keyword: the same step text cannot be defined twice under different keywords.
- Description text may follow `Feature`, `Rule`, `Background`, `Scenario` and `Scenario Outline` if no line starts with a keyword; it is ignored at run time.
- A Doc String sits between triple quotes or triple backticks; a Data Table is pipe rows, with `\|`, `\n` and `\\` escapes.
- `# language:` selects another keyword language. The skill's script reads English only.

## Comments

A comment starts with `#` at the start of a line (leading spaces allowed). There are no block comments. So `Scenario: Refused # negative` has no comment: the text is expected to become part of the name (this follows from the rule; not run). Use tags.

## Tags

- Allowed on `Feature`, `Rule`, `Scenario`, `Scenario Outline` and `Examples`; never on `Background` or steps. Children inherit them.
- Selection and conditional hooks use tag expressions. The expression syntax differs by runner (godog: `@a`, `~@a`, `&&`, `,` for or).
- Tags on separate `Examples` blocks run or label subsets of one outline, for example `@AC-US-2.3 @edge` on the limit rows.

## This plugin's tags

| Tag | Where | Rule |
|---|---|---|
| `@AC-US-n.m` | Scenario, outline or Examples block | At least one; never on Feature or Rule, where it would cover everything below |
| `@happy`, `@negative`, `@edge` | Same | Exactly one |
| `@quarantine` | Scenario | Only under `test-pyramid`'s flaky policy; counts as unproven |
| `@skip`, `@wip`, `@ignore`, `@manual`, `@pending` | Scenario | Count as unproven |

The reference does not list which characters tag names permit, so confirm with the runner that selecting `@AC-US-4.2` finds the scenario.

## File header

Gherkin cannot hold YAML frontmatter, so the artifact fields are comment lines at the top: `# name:`, `# product:`, `# story-id:`, `# version:`, `# phase:`, `# owner:`, `# created:`, `# summary:`, `# run:`, `# traces_to:`, then a line saying how the file was made.

## Wording traps

| Technical or scripted | Declarative (Pugh; Adzic) |
|---|---|
| `When she sends a PATCH request` | `When she changes her pick-up time` |
| `When she clicks Renew and types the card number into the field` | `When she renews the loan` |
| `Then the response is 403 Forbidden` | `Then she is told only staff may do this` |
| `Then order_status = "cancelled"` | `Then the order shows as cancelled` |

Everyday words are fine: "get a refund", "delete the post", "click-and-collect". Use the product's glossary term for each thing, never a synonym.
