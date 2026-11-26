# Checklist: Test Fixtures

Run after `validate-test-fixtures.sh` (the skill's script) is clean. The script finds text patterns; this list checks judgement.

## Ownership and isolation
- [ ] Each test creates what it reads; no shared seed rows or shared mutable object.
- [ ] Database tests roll back. Each one that commits states which real-commit reason applies.
- [ ] The scope key matches the tenancy design; no invented `tenant_id`; an undecided design is put to the product owner.
- [ ] Anything that reads all rows (relay, batch job) cannot pick up another test's data.
- [ ] Broker tests use their own topic and consumer group.

## Cleanup and safety
- [ ] Cleanup is registered before seeding, runs on failure, reports errors and covers every written table.
- [ ] No setup or cleanup resets shared tables.
- [ ] The database address comes only from what this run started; other addresses are refused.

## Data
- [ ] Time, IDs and seeds are controlled.
- [ ] Mothers and builders set the state their names claim, through domain behaviour.
- [ ] Unit cases use literals unless construction really repeats.
- [ ] No production-derived data without the product owner's decision.
- [ ] Golden diffs were read; old event samples are unchanged.

## Proof and answer
- [ ] Tests ran, also in another order and in parallel where the suite does; anything not run is called unverified.
- [ ] The answer states isolation, what was replaced or refused and why, the size note, product-owner decisions and what was run, and offers no way around a rule.
