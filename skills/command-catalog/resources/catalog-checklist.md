# Command Catalog Checklist

Run after `./scripts/validate-command-catalog.sh` exits clean. The script checks structure; these items need judgement.

## Intents and names
- [ ] Every Command is on the Event Storming wall, in an Aggregate's Commands-and-events table or in a Policy's "then", and every Aggregate Command is here.
- [ ] Each name is the intent a domain expert would say, in this context's Ubiquitous Language.
- [ ] No Command hides several intents (a status field, a bag of optional fields); values that differ in actor, rule or event are split.
- [ ] No bulk action as a loop of Commands; a bulk intent starts a tracked process.

## Target and inputs
- [ ] Each Command changes one Aggregate instance, which the caller can name from what it has.
- [ ] Each input is needed by the intent and says what "absent" means.
- [ ] Who issued it and the tenant (multi-tenant only) come from the authenticated context, never the request.

## Rejections
- [ ] Every rule in `aggregates.md` for this Command appears as a rejection checked in the Aggregate.
- [ ] Input checks need nothing but the request; nothing that reads state is marked *invalid input*.
- [ ] Access checks (who may) are separate from rules (what may happen).
- [ ] Each rule about another Aggregate names its option: read-only copy, reference check, or redrawn boundary.
- [ ] Each rejection is worded so the person who issued it can act on it.

## Retries, concurrency, outcome
- [ ] Each key is stable across retries of one intent; Policy-issued Commands use the triggering event's ID.
- [ ] The key retention covers the longest retry horizon, failover included.
- [ ] "Already in effect" is decided per Command.
- [ ] External effects pass the same key downstream.
- [ ] Concurrency is decided per Command, with the reason.
- [ ] Each success records an event from `aggregates.md`; replies carry identifiers, not state.

## Hand-off
- [ ] enterprise-architect can design each API operation from the catalog without guessing who may call it, how it fails or what it is keyed on.
- [ ] `traces-to` names the Aggregate design, the Event Storming output, the language document and the event catalog.
