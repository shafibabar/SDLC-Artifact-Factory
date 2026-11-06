# Domain Event Catalog Checklist

Run after `./scripts/validate-domain-event-catalog.sh` exits clean. The script checks structure; these items need judgement.

## Facts and names
- [ ] Every event is on the Event Storming wall or in an Aggregate's Commands-and-events table, and every Aggregate Command's event is here.
- [ ] Each name is the business fact a domain expert would say, in this context's Ubiquitous Language.
- [ ] No generic event hides several facts that consumers treat differently.
- [ ] One event per fact: not one per field, not one per transaction.
- [ ] No Command in disguise; each instruction lives in a consumer's policy.

## Payload meaning
- [ ] Each field says what it means (including what "absent" means) and which reaction it enables.
- [ ] Consumers can react without calling back, unless an ID-only event is a stated choice with its cost.
- [ ] Other Aggregates appear by ID; the prior value is there where consumers act on transitions.
- [ ] No state dump, no envelope facts, no raw sensitive values.

## Visibility
- [ ] Each published event is a business fact on a context-map line, and that line's contract obligations are known.
- [ ] Internal and stored events have a translation (or "never published" with a reason); none leak as published contracts.

## Consumers
- [ ] Every published event lists its consumers (or "none yet" with a reason), each with a policy and an idempotency key.
- [ ] Ordering needs are per Aggregate; each consumer's stuck-event choice is recorded.
- [ ] Assumed reactions of other contexts are marked *assumed*, with an open question.

## Retention and hand-off
- [ ] Each retention need gives the business reason; the schedule is left to `data-retention-policy`.
- [ ] data-architect can write `event-schemas.md` for every published event without guessing what a field means.
- [ ] `traces-to` names the Aggregate design, the Event Storming output and the language document.
