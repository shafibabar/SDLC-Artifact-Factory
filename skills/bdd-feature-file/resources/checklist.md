# Checklist: Feature File

Run after `validate-bdd-feature-file.sh` (the skill's script) is clean. The script checks structure, tags and coverage; this list checks judgement.

## Inputs
- [ ] The story's criteria file was read and the product owner has approved it (the manifest says so).
- [ ] Its example map, the glossary and the test strategy were read.

## Ready to automate (each scenario)
- [ ] Business language only: no screen mechanics, requests, status codes, storage or tool names.
- [ ] It illustrates a single rule.
- [ ] It was agreed: it says what an approved criterion says, with the same actor, values, limit and outcome.

## Each scenario
- [ ] Given is a state that already holds; When is one action; Then is something the persona (or a named operational record or Domain Event another party observes) can observe.
- [ ] Everything a But or And in the criterion forbids or requires is still asserted.
- [ ] It runs alone and in any order; shared state is a short Background or a hook, never a previous scenario.
- [ ] Every Examples row would lose something if removed.

## The set
- [ ] Every criterion of every Must Have story has a scenario; the product-wide check was run with the Must Have list.
- [ ] A rule with three or more interacting conditions had a decision table; each missing combination went back as a question.
- [ ] Scenarios for removed or changed criteria were removed or updated; no live ID lost its scenario.
- [ ] Each WARN from the script was read and answered.

## Reply
- [ ] It states what "What every answer states" lists, including anything replaced or refused, by name.
- [ ] No pass is reported without a run; a mismatch is put to the product owner with both options, undecided.
