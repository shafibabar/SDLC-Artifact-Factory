# Checklist: Acceptance Criteria

Run after `validate-criteria.sh` (the skill's script) is clean. The script checks structure and wording; this list checks judgement.

## Inputs
- [ ] The story's own example map was read, is ready, and every question in it was answered by the product owner.
- [ ] Each fit criterion and business rule the story carries is covered by a criterion; one the map never showed went back to the map as a question.
- [ ] Every NFR ID cited exists; no speed, availability or similar number is restated as a criterion.

## Each criterion
- [ ] It says only what the map's rule and examples agreed: no new behaviour, value or limit.
- [ ] Given is a state that already holds; When is one action; Then is something the persona (or a named operational record, such as an audit record) can observe.
- [ ] It is in the product's business language: no screen mechanics, endpoints, storage or tool names.
- [ ] Two readers would give the same pass or fail verdict.
- [ ] It proves something no other criterion proves.

## The set
- [ ] A happy path, a negative case and an edge case are present, at every size.
- [ ] Who may not do this, nothing to show, maximum volume, two at once and a dependency being down were each considered, and tenant isolation if the product has tenants: each is a criterion, an out-of-scope line or a question on the map.
- [ ] IDs agreed before are unchanged; no removed ID was reused.
- [ ] More than 12 criteria: a split was proposed to the product owner.

## Reply
- [ ] It states what "What every answer states" lists, including anything replaced or removed, by name.
