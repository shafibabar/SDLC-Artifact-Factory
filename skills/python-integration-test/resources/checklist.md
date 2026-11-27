# Python Integration Test Checklist

Copy and tick before hand-off.

## Harness
- [ ] Real engine, pinned tag matching production; no fake, mock or substitute
- [ ] Address only from the started container; `DATABASE_URL` never read
- [ ] Real Alembic revisions applied by the harness
- [ ] One container per process, session-scoped and synchronous, removed in `finally`
- [ ] Connections, pools and clients created on the test's own event loop
- [ ] Integration tests marked; no `-m` or `--ignore` in `addopts`; no skip for a missing Docker
- [ ] Start retried only for containers, bounded and logged; no test retried or rerun

## Tests
- [ ] Test written first and seen to fail
- [ ] Rollback unless a named reason needs a commit; commit tests own their keys or database
- [ ] `scoped` called before the first write and lists every table written
- [ ] Expected database errors run in a savepoint
- [ ] No fixed sleep; polls have a deadline and report what was waited for
- [ ] Duplicate and "nothing happened" assertions come after proof of consumption
- [ ] Redelivery test drives the real consumer, waits for offset and event id within one deadline, filters by event id, and finds the dead letter topic empty
- [ ] Isolation, deduplication and refusal tests went red with the code broken (deduplication: result ignored, SQL kept)
- [ ] Relay and global readers have their own database and topic
- [ ] Tenant denial (if any) goes through the product's code, with an allowed read in the same test; row-level security also tested without a filter, as the application role
- [ ] Changed migration: down, up, and previous release's statements on the new schema over seeded rows
- [ ] Every documented API promise and error branch asserted with its stored effect; no invented limits

## Run
- [ ] `validate-python-integration-tests.sh` has no FAIL; each WARN judged
- [ ] The full `pytest` run passes with Docker
- [ ] Line and branch gate run on the full suite; counts and exit code recorded
- [ ] Report lists the test support under `tests/`; nothing that ships is there or imports it
- [ ] Any gap is tested or a pending exclusion; none called passing
- [ ] No container left running
- [ ] Anything not run is called unverified
