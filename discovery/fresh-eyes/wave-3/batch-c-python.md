# Wave 3 Discovery, Batch C: Python Testing Skills

- **Scope:** `python-unit-test`, `python-integration-test`, `python-contract-test`, `python-e2e-test`, `python-mutation-test`, `python-load-test`, `python-performance-test`, `python-chaos-test` (issue #1451).
- **Read:** every file of the eight skills and their contract tests; `CLAUDE.md`; `skill-authoring-standards/SKILL.md`; batches A and B; `scripts/tdd-gate.sh`; the research listed under "What I could not verify"; the neighbouring Python skills, agents and `phase-requirements.json` passages cited below.
- **Executed:** `lint-skill-layout.py --skill` and `validate-skill-structure.sh` for all eight; `tdd-gate.sh` with synthetic `.py` input; and, in a throwaway virtual environment in the session scratch directory (Python 3.14.4, pytest 9.2.0, pytest-asyncio 1.5.0, pytest-benchmark 5.3.1, pytest-cov 7.1.0, mutmut 3.8.1, locust 2.47.0, toxiproxy-python 0.1.1, jsonschema 4.26.0, referencing 0.37.0), small probes of individual claims.
- **Evidence marks:** **[Ran]** reproduced by a probe. **[GK]** rests on general knowledge, not on text in this repository or on a probe. Unmarked findings come from reading the files against each other.
- File paths in the tables are relative to `skills/`. `ref/x.md` means `<skill>/references/x.md`; the skill is named in the row.

## Narrative

**1. Several gates cannot give a true verdict as written, and one gives a false pass.**

| Gate | What happens |
|---|---|
| Load (sync SLO) | One token means one subject; the limiter allows 10 requests per second, burst 20 (`python-middleware/references/auth-ratelimit-cors.md:149,169`). The locustfile counts a `429` with `Retry-After` as **success** on the classification route (`ref/locust-load-profiles.md:74-77`), the only row the gate reads (`ref/criteria-and-analysis.md:78-82`). At 30 requests per second most requests are rejected quickly, the error rate stays low and the p99 looks better. The gate passes a system that served a third of the load. |
| Load (threshold) | The SLI is 99.5% under 800ms and the table says P99.5; the script gates p99, which is weaker (`ref/criteria-and-analysis.md:23,79-81`). [Ran] locust's CSV reports no 99.5 percentile. |
| Mutation | The wrapper counts lines starting `Killed` and `Survived`. Run on the skill's own sample output it scores **0%** where the same file claims 82% PASS (`ref/mutmut-setup-and-score.md:111-116,226-236`). [Ran] With mutmut 3.8.1 the committed config crashes before any command (`tests_dir` is a string), and `junitxml` and `html` do not exist. |
| Performance | [Ran] `--benchmark-compare=baseline` matches no file, because saving "baseline" writes `0001_baseline.json`. The run exits 4 with a usage error, so the gate fails every time. |
| Contract | The CI job runs `pytest -m contract`, but no test carries the marker. [Ran] pytest exits 5 with everything deselected. [Ran] The provider test's `$ref` resolution raises `PointerToNowhere`. |
| Coverage (all subsets) | `python-makefile/references/toolchain-and-ci.md:76-79` puts `--cov-fail-under=80` in `addopts`. [Ran] Any subset run then fails on coverage even when every test passes. That covers the contract, integration, e2e, chaos, benchmark and mutation commands in these skills. |

**2. The unit skill's central warning is false.** It says an un-awaited async test "is reported as passed" and calls this load-bearing (`python-unit-test/SKILL.md:45-48,100-102,166,182,195`; `ref/fakes-async-coverage.md:153-158`). [Ran] pytest 9.2 **fails** such a test ("async def functions are not natively supported"), with or without the asyncio plugin. [GK] Older releases skipped it with a warning. The advised guard, a deliberately failing async test in CI, would keep CI red.

**3. The TDD hook does not cover Python at all.** `scripts/tdd-gate.sh` selects `.go`, `.ts` and `.tsx` only. [Ran] A write of `app/domain/foo.py` with no test is allowed. The unit skill says "the `tdd-gate` hook verifies it" (`SKILL.md:171,187`). This is the opposite of the Go problem (batch B narrative 6).

**4. The worked code was not written against the Python code it tests.**

| Test code assumes | The owning skill defines |
|---|---|
| `DataAsset.create(tenant_id, name, source)`, `.rename()`, `.outranks()`, `.tenant_id`, `classify(level)` | `register(id, tenant_id, source_id, now)`, `is_higher_than`, no `tenant_id` accessor, `classify(level, by, now)` (`python-domain-model/references/aggregate-and-value-objects.md:51-92,132`) |
| `FakeUnitOfWork` with `assets` and `committed` | The use case calls `uow.commands.already_processed` first (`python-service-layer/references/service-layer-and-uow.md:217`): `AttributeError` |
| `repo.get(asset_id, tenant_id)` | `get(asset_id)`; tenant from a context variable (`python-repository-pattern/references/asyncpg-adapter.md:73`) |
| Ledger `processed_messages(message_id)`, `DataAssetConsumer(pool, bootstrap_servers, topic)` with `start`/`stop` | `processed_events(consumer_name, event_id)`, `(consumer, pool, dlq, name)` with `run`; the envelope needs `event_id`, `occurred_at`, `payload` (`python-event-consumer/references/consumer-loop-and-idempotency.md:12,55-59,106-113`) |
| Fixture sets `sqlalchemy.url` then calls `command.upgrade` | `env.py` overwrites the URL from `DATABASE_URL` and calls `asyncio.run` (`python-migration/references/alembic-setup-and-revisions.md:87,128`) |
| A Circuit Breaker raising `ServiceUnavailableError` | No other Python skill builds one (search of `python-*`; the publisher forbids one on the relay) |
| Roots `src.`, `app.`, bare `domain.`, `classification.`; tests in `tests/domain`, `tests/application` | `src/<pkg>/{domain,service_layer,adapters,entrypoints}`, `tests/unit/` (`python-project-structure/SKILL.md:67,139`) |

The Alembic row is the dangerous one: the fixture either raises on the nested event loop [Ran, for `asyncio.run` inside an async fixture] or, once that is fixed, migrates whatever database `DATABASE_URL` names instead of the throwaway container. The neighbouring implementation skills also disagree among themselves (`asset.version`, `sensitivity_level`, `events` in the adapter against `version_number`, `sensitivity`, `pull_events` in the model). Those are outside this batch but block it.

**5. Proofs that prove nothing.** The redelivery test polls for a ledger count that is already 1, so it passes before the duplicate is consumed (`python-integration-test/references/isolation-and-assertions.md:225-246`). The tenant-isolation test runs its own `WHERE tenant_id` SQL and never calls the repository (`:267-275`). Both chaos experiments can pass with the pattern absent (`python-chaos-test/references/toxiproxy-fault-injection.md:183-262`). The "open model" load recipe is still closed: [Ran, source] `constant_throughput` sets the wait to 0 and falls behind when a task runs long.

**6. Tenancy is stated as physical isolation.** The plugin has no default (`multi-tenancy-design` 3.0.1). The old wording is in load (`SKILL.md:63-67,149,162`; `ref/locust-load-profiles.md:30,209-211`), integration (`ref/testcontainers-setup.md:9-10`; `ref/isolation-and-assertions.md:7-8,65,259-263`, which also calls a shared schema "physical multi-tenancy"), contract (`ref/schema-contract-tests.md:159`), e2e (`ref/flake-and-scope.md:144-146`) and chaos (`ref/experiment-design.md:64,68-70`, which cites `multi-tenancy-design` for a boundary it does not hold). Assumed `tenant_id` everywhere also appears in unit (`ref/fixtures-and-parametrize.md:87,154-160`), integration (`SKILL.md:74-82`), e2e (`SKILL.md:79,137`; `ref/e2e-setup-and-flow.md:55,192`) and chaos (`SKILL.md:58,177`). Mutation and performance state no tenancy model.

**7. Nobody loads these skills.** Each description says "Teaches the backend-engineer", but `backend-engineer` is declared a Go agent and neither it nor any other agent lists a `python-*` test skill in `skills:`. `phase-requirements.json:907-918` registers no test artifact (`implement` is empty; `quality` holds one compliance report).

**8. Shared structure gaps.** All eight: no `sources:`, `## Gotchas`, `templates/`, `resources/`, `examples/`, `scripts/` or eval suite; no numbered procedure for composing the work; no lean / standard / enterprise rule; descriptions (325 to 412 characters) list contents and never say "Use when"; a non-standard `tools: [Bash]` frontmatter key. Layout lint and the structure validator pass all eight, which shows neither checks behaviour.

## Findings table

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| W3C-1 | Accuracy | `python-unit-test/SKILL.md:45-48,100-102,166,182,195`; `ref/fakes-async-coverage.md:153-158` | "Silent pass" claim and guard are wrong | State that it fails (or skips on old pytest); require pinned pytest and `asyncio_mode` | Defect | H | S | High [Ran] |
| W3C-2 | Mechanics | `scripts/tdd-gate.sh`; unit `SKILL.md:171,187` | `.py` writes are not gated | Decision C-1 | Defect (cross-component) | H | M | High [Ran] |
| W3C-3 | CI | `python-makefile/references/toolchain-and-ci.md:76-79` against every subset command | Coverage floor fails all subset runs. [GK] A mutmut 2 runner would then count every mutant killed | Move coverage flags to the `make test` target | Defect (cross-component) | H | S | High [Ran]; mutation effect [GK] |
| W3C-4 | CI | `python-makefile/references/makefile-targets.md:73`; `testpaths = ["tests"]` | `make ci` collects e2e (asserts `E2E_BASE_URL`), chaos, benchmarks | One marker and directory scheme (decision C-3) | Defect | H | S | High |
| W3C-5 | Config | unit `ref/fakes-async-coverage.md:143-151`; integration `ref/testcontainers-setup.md:32-37,150-152`; contract `ref/schema-contract-tests.md:309-312`; e2e `ref/e2e-setup-and-flow.md:287-294`; makefile | Five partial pytest blocks, none merged; `chaos` never registered although unit sets `--strict-markers` | One owned `pyproject.toml` template | Contradiction | H | S | High |
| W3C-6 | Layout | narrative 4, last row; mutation `ref/mutmut-setup-and-score.md:42-43` | Package and test paths differ; mutation targets `tests/unit/`, which the unit skill never creates, and `service_layer`, which it calls `application` | Follow `python-project-structure` | Contradiction | H | M | High |
| W3C-7 | Code | unit `ref/fixtures-and-parametrize.md:95-112,135-146,189,200,229-234`; `ref/fakes-async-coverage.md:99-121` | Worked tests call methods that do not exist; the fake lacks `commands` | Rewrite against the owners; compile in a tested example | Defect | H | M | High |
| W3C-8 | False proof | unit `ref/fakes-async-coverage.md:111-114`; `ref/fixtures-and-parametrize.md:227-235` | The fake never rolls back and returns the same object, so the state assertion passes with no save and no commit; only the flag catches a missing commit | Fake copies on load and publishes on commit | Defect | M | S | High |
| W3C-9 | Architecture | unit `ref/fakes-async-coverage.md:175-188` | Interaction mock patches a direct publish from the application layer, against the Transactional Outbox; function undefined | Mock a real unmanaged port; assert outbox state for events | Contradiction | H | S | High |
| W3C-10 | Research gap | unit body; `software-testing-craftsman-jorgensen.md:9-11,19-25`; `python-backend-development-halstead.md:47`; integration `SKILL.md:98` | No way to derive cases; no Hypothesis; the "complexity quadrants" others cite are never defined here | Case-derivation step, property-based option, quadrant table | Augment | H | M | High |
| W3C-11 | Safety | integration `ref/testcontainers-setup.md:107-115`; migration `env.py:87,128` | Migration fixture raises, and its URL override is ignored in favour of `DATABASE_URL` | Sync session fixture; set `DATABASE_URL` for the call; refuse a non-container host | Defect | H | S | High (read); nested loop [Ran] |
| W3C-12 | Async | integration `ref/testcontainers-setup.md:140-153` | [Ran] Session fixture and test run on different loops with only the fixture loop scope set | Set the test loop scope too [GK setting name]; one config | Defect | H | S | High [Ran] |
| W3C-13 | Deps | integration `ref/testcontainers-setup.md:22-29,113` | URL forced to `psycopg`, which is not a dependency; owner uses the asyncpg dialect | Follow `python-migration` | Defect | M | S | High |
| W3C-14 | Code | integration `ref/isolation-and-assertions.md:105-165,201-243` | Repository, column, ledger, envelope, table and constructor names wrong (narrative 4) | Rewrite; a template that runs | Defect | H | L | High |
| W3C-15 | False pass | integration `ref/isolation-and-assertions.md:225-246` | Redelivery assertion is vacuous | Wait for the second offset or a duplicate counter, then assert | Defect | H | S | High |
| W3C-16 | False pass | integration `ref/isolation-and-assertions.md:267-275` | Isolation test queries raw SQL, not the code under test | Call the repository under another tenant's context; model from tenancy design | Defect | H | S | High |
| W3C-17 | Code | contract `ref/schema-contract-tests.md:47-52,135` | Sub-schema validated alone cannot resolve `#/components/...` | Validate `{"$ref": "urn:openapi#/paths/..."}` through the registry | Defect | H | S | High [Ran] |
| W3C-18 | CI | contract `ref/provider-consumer-ci.md:115,129`; no `pytestmark` in either reference | Contract job selects zero tests, exit 5 | Add module markers | Defect | H | S | High [Ran] |
| W3C-19 | Code | contract `ref/schema-contract-tests.md:107-122` | Seed fixtures undefined; [Ran] `getfixturevalue` of an async fixture inside an async test raises | Indirect parametrization | Defect | H | S | High [Ran] |
| W3C-20 | Logic | contract `ref/schema-contract-tests.md:248-286` | Defines BACKWARD as old readers (the owner says new readers read old events, `event-schema-design/SKILL.md:73`). [Ran] Passes optional-to-required, enum value removal and closed-schema property removal; fails a harmless relaxation | Delete the hand-written checker; use the owner's mode and gate | Defect | H | M | High [Ran] |
| W3C-21 | Overclaim | contract `ref/schema-contract-tests.md:201`; `ref/provider-consumer-ci.md:134-143` | `format: uuid` is not enforced by default [Ran]; matrix cells do not match the tests; "provider free to add fields" is false for the `additionalProperties: false` event schema | Add a format checker; rebuild the matrix from runs | Defect | M | S | High |
| W3C-22 | Design | contract `ref/schema-contract-tests.md:151-177`; `ref/provider-consumer-ci.md:13-15,63-88` | The consumer test imports the provider app, so it cannot run in the consumer's repository; the pinned test ignores `endpoint`; old pins accumulate with no removal rule | Consumer validates against the vendored spec; pin test routes by endpoint | Defect | H | M | High |
| W3C-23 | Overlap | `python-openapi-codegen/references/contract-conformance-check.md:100-101`; `halstead:50,86` | The neighbour says this skill uses `schemathesis`; it never mentions it, and does not use the neighbour's `oasdiff` breaking-change gate | Decision C-6 | Contradiction | M | M | High |
| W3C-24 | Teardown | e2e `ref/e2e-setup-and-flow.md:45-62`; `ref/flake-and-scope.md:223-225` | `trap ... EXIT` deletes the cluster before pytest runs | One script owns provision, test, teardown | Defect | H | S | High |
| W3C-25 | Setup | e2e `ref/e2e-setup-and-flow.md:51-62`; `ref/flake-and-scope.md:224` | No database, broker, mesh or ingress installed; no broker port-forward; [GK] `tee -a $GITHUB_ENV` would append tool output and break the env file | Complete script with a test; write only `KEY=value` | Defect | H | M | High; env file [GK] |
| W3C-26 | Safety | e2e `ref/e2e-setup-and-flow.md:175-186,292`; `ref/flake-and-scope.md:236-241` | The only `smoke` example creates a source and reclassifies, then runs against real environments labelled "non-destructive" | Read-only smoke example; destructive marker excluded by the runner | Defect | H | S | High |
| W3C-27 | Consistency | e2e `ref/e2e-setup-and-flow.md:191-200`; `ref/flake-and-scope.md:149-157`; envelope `UUID(d["tenant_id"])` | Tenant sent as a client header and as a non-UUID string; fixture `_admin_pool` undefined and unused; e2e writes the database directly | Tenant from the token; seed through the API | Defect | M | S | High |
| W3C-28 | Flake | e2e `ref/flake-and-scope.md:24-35,59-69,89-94,128,169-173`; `ref/e2e-setup-and-flow.md:267-277` | `--only-rerun ""` with advice contradicting the policy; detection record, janitor, quarantine workflow step and plugin dependencies absent; `trace_headers` never called | Tested script and workflow template | Defect | M | M | High |
| W3C-29 | Gate | load `ref/locust-load-profiles.md:31,74-77`; `ref/criteria-and-analysis.md:78-82` | False pass: one subject, `429` counted as success on the gated row, fast rejections in the percentile. [Ran] other rows count `429` as failure | Many subjects; report accepted, shed and failed separately; gate latency on accepted requests with a shed ceiling | Defect | H | M | High |
| W3C-30 | Threshold | load `ref/criteria-and-analysis.md:23,79-81` | p99 gates a 99.5% objective | Count requests over 800ms and gate the ratio | Defect | H | S | High [Ran] |
| W3C-31 | Model | load `SKILL.md:80-103`; `ref/locust-load-profiles.md:149-167` | `constant_throughput` is not open-model; the Soak claim is false when it matters | k6 arrival-rate executor (decision C-4) | Defect | H | M | High [Ran source] |
| W3C-32 | Tool | load `ref/locust-load-profiles.md:99-135,186-197` | [Ran] no `--shape` option; shapes sit in a file the command does not load; [GK] a shape overrides `--users`, and two shapes in one file need a picker | Rewrite and run each command | Defect | H | S | High / [GK] |
| W3C-33 | Arithmetic | load `ref/locust-load-profiles.md:111-135` | Ramp reaches 50 users in 50s, not 2 min; 50 to 500 takes 90s, not 5 min; Spike is users with think time, not 30 requests per second; the 10,000-document burst and 500 documents per minute are never scripted | Compute stages; script the pipeline feed | Defect | H | M | High |
| W3C-34 | Gate | load `ref/criteria-and-analysis.md:70-83` | The only sync gate script reads the Ramp run, which is designed to breach; it is not in Output Format | Gate Smoke, Soak, Spike recovery; Ramp reports a ceiling | Defect | H | S | High |
| W3C-35 | Overlap | python-chaos `SKILL.md:26-28`; load `SKILL.md:130` | Circuit Breaker assumed but built by no Python skill | Add it to an implementation skill or make rows conditional | Pipeline gap | H | M | High (search) |
| W3C-36 | Code | perf `ref/pytest-benchmark-setup.md:153-164` | `pedantic` example asserts `pii-high` for input scoring `none` | Fix the fields | Defect | M | S | High [Ran] |
| W3C-37 | Gate | perf `ref/throughput-and-ci.md:77-81,108-120,157-162` | `compare=baseline` always errors; baseline directory is keyed by OS and Python version | Benchmark base and head in one job (batch B B-4) | Defect | H | S | High [Ran] |
| W3C-38 | CI | perf `ref/pytest-benchmark-setup.md:31-39`; `ref/throughput-and-ci.md:143-144` | "Never in the fast loop" is not implemented in the owned Makefile; the weekly "baseline honesty check" only compares, and no refresh job exists | Covered by C-3 | Defect | M | S | High |
| W3C-39 | Tool | mutation `ref/mutmut-setup-and-score.md:32-49,71-86,193-198` | Unpinned install gets 3.x: config crashes, `runner` unused, `paths_to_mutate` deprecated, `junitxml` and `html` gone | Pin a major version; commit a tested config | Defect | H | M | High [Ran] |
| W3C-40 | Script | mutation `ref/mutmut-setup-and-score.md:100-123,226-236` | Gate script scores 0% on the sample; ignores timeouts; `mutmut run \|\| true` hides a crash | Script in the skill, reading `export-cicd-stats` [GK format], with a test | Script | H | M | High [Ran] |
| W3C-41 | Triage | mutation `ref/mutmut-setup-and-score.md:61-65` | A default page size of 50 versus 51 is observable, so the "equivalent" example teaches the wrong judgment the sibling reference warns against | Replace with a true equivalent | Defect | H | S | High |
| W3C-42 | Chaos code | chaos `ref/toxiproxy-fault-injection.md:74-109,183-262` | `app_client`, `redpanda`, `outbox`, `projection`, `poll.py` undefined; no Redpanda in the stack; [GK] container hostname does not resolve on the default bridge, and restart changes the mapped port | Compiling harness on a shared network | Defect | H | M | High on absences; [GK] network |
| W3C-43 | False proof | same | One call after the sever cannot show a breaker opening; the recovery poll passes if it never opened; the outbox count is read straight after insert; redelivery checked without waiting | Drive past the threshold; observe open, half-open, closed; wait for the duplicate | Rewrite | H | M | High |
| W3C-44 | Abort | chaos `SKILL.md:145-149`; `ref/experiment-design.md:94-114`; worked tests | `run_with_abort` is used by neither experiment; the header cites a deadline that does not exist; [Ran] `add_toxic` returns nothing, so `toxic.destroy()` cannot work | Fixture that runs observation and watchdog together | Defect | H | M | High |
| W3C-45 | Research gap | `halstead:51` | A stalled event loop makes the whole process look hung under injected latency; no chaos, load or performance skill tests or mentions it | Add the experiment and an event-loop lag signal | Augment | M | M | High on absence |
| W3C-46 | Leakage | narrative 6 | Physical isolation stated as fact; tenant everywhere | Read the model from the tenancy design; single-tenant variant | Leakage | H | M | High |
| W3C-47 | Ownership | `agents/backend-engineer.md:2-17,52-78`; `agents/test-strategist.md:27-38` | No agent preloads or is described as using any of the eight | Decision C-5 | Agent gap | H | S | High |
| W3C-48 | Pipeline | `phase-requirements.json:907-918`; output formats | No Python test artifact or report registered; reports in `docs/quality/` with no template or frontmatter | Same family as batch B W3B-53 | Pipeline gap | H | M | High |
| W3C-49 | Frontmatter | all eight frontmatter blocks | No usage condition in descriptions; `tools: [Bash]` [GK ignored; if honoured, an allow-list of one]; 21 skills carry it | Rewrite descriptions; drop the key | Description | M | S | High / [GK] |
| W3C-50 | Contract tests | `tests/skills/python-*.contract.sh` | One substring each; they pin the nonexistent `outranks` case id and tool flags under repair | Retire when evals pass | Test | L | S | High |

## Per-skill sections

Go-mirror lines use batch B IDs. "Applies" means verified in the Python text.

### python-unit-test

1. **Sources**
   - `python-testing-with-pytest-okken.md`: assert rewriting (`:10`), fixtures and factories (`:11-13`), parametrize (`:14`), markers and xfail (`:15`), plugins (`:16`), fakes over mocks (`:18`), mechanics only (`:53`).
   - `unit-testing-khorikov.md`: pillars (`:7`), unit of behaviour (`:9`), mock vs stub (`:10`), managed vs unmanaged (`:11`), quadrants (`:12`), coverage (`:14`).
   - `architecture-patterns-with-python-percival-gregory.md`: fake repository and UoW (`:13-15`), high-gear testing (`:23`).
   - `halstead:47` (Hypothesis, xdist). `software-testing-craftsman-jorgensen.md:9-11` (case derivation).
2. **Gaps and errors:** W3C-1, 2, 5 to 10. `SKILL.md:26` defines the unit as a function or Aggregate, narrower than Khorikov's unit of behaviour. xfail, `monkeypatch`, `tmp_path`, time control and fake-to-real equivalence are absent. `ref/fixtures-and-parametrize.md:24-25` speaks of `-p no:randomly` without introducing the plugin. Per-layer coverage floors (`ref/fakes-async-coverage.md:208-212`) compete with the Makefile's single 80% (batch A D-3).
3. **Go mirror:** apply: W3B-35, W3B-58. Variant: W3B-31 (broken example calls, here many more), W3B-32 (hook claim, here wholly false). Do not apply: W3B-33 and 34 (fake and mock wording is consistent; the mock example is the fault).
4. **Folder moves:** `conftest.py`, fakes and parametrize skeletons to `templates/`; worked domain and service tests to `examples/`; managed/unmanaged text to a pointer at the one owner (W3A-34); checklist to `resources/`.
5. **Example ideas:** (a) lean: a loyalty-points rule, boundaries then a table; (b) standard: a subscription Aggregate with guarded transitions and a fake UoW with a command log; (c) enterprise: a tariff engine with injected clock, Hypothesis properties, concurrent use cases against a version-checking fake.
6. **Eval ideas:** (a) "Our async test passes but asserts nothing; why?" without assuming the silent-pass story. (b) "Assert `save` was called once". (c) "Mock the broker publish from the service" where the product uses an outbox. (d) Three boolean conditions: trap is three happy rows. (e) State assertion on a shared in-memory object with no commit.
7. **Overlaps:** `python-repository-pattern` and `python-service-layer` (two more fakes), `python-domain-model` test table, `python-error-handling` test sections, `test-fixture-design`, `mock-generation`.
8. **Size:** M.

### python-integration-test

1. **Sources**
   - `okken:17,23` (testcontainers; per-test rollback). `khorikov:11` (end state).
   - `percival:13-15` (small integration suite behind ports). `halstead:48`.
   - `testing-web-apis-winteringham.md:11,14` (workflow tests, bounded polling).
   - `continuous-delivery-humble-farley.md:15` (migrations on the same path; N and N-1).
2. **Gaps and errors:** W3C-3, 5, 11 to 16, 46. `pytest-xdist` guidance gives no `-n` sizing or marker split. No migration downgrade or N-1 test, no dead-letter round trip, no Docker image pinning policy beyond two tags, no non-PostgreSQL route although `python-mongodb-repository` cites this skill as the harness owner.
3. **Go mirror:** apply: W3B-27 (vacuous duplicate), W3B-28 (shared topic and group between tests; cleanup lists three tables by hand), W3B-40 (no behaviour checks). Variant: W3B-25 and 26 (signatures and fixtures wrong). Do not apply: W3B-29 (marker deselection, no process exit; the Makefile never uses it), W3B-30 (no retry helper). Batch A D-1: the Python text already has rollback as default and the savepoint account is sound [GK].
4. **Folder moves:** `conftest.py` pair and poll helper to `templates/`; three round trips to `examples/`; strategy table stays one reference.
5. **Example ideas:** (a) lean: one repository, rollback only, no broker; (b) standard: outbox plus idempotent consumer with an observed duplicate; (c) enterprise: pooled tenancy with row-level security proving cross-tenant denial, expand/contract migration test, xdist shards.
6. **Eval ideas:** (a) Migration fixture review where `DATABASE_URL` points at a developer database. (b) "Write the redelivery test": needs proof the second copy was consumed. (c) Tenant test that queries SQL directly. (d) "Attached to a different loop" diagnosis. (e) Single-tenant product: no invented `tenant_id`.
7. **Overlaps:** `python-repository-pattern`, `python-migration`, `python-event-consumer`, `python-event-publisher`, `test-fixture-design`.
8. **Size:** L.

### python-contract-test

1. **Sources**
   - `contract-testing-in-action-cruz-prescott.md`: schema vs contract (`:7`), consumer mock (`:8`), provider states (`:9`), Broker (`:10`), pending (`:11`), versioning (`:12`), paid bi-directional (`:13`), message contracts (`:14`), placement (`:15`).
   - `winteringham:10,22,30` (behaviour beyond shape). `halstead:50,86` (`schemathesis`). `okken:37`.
2. **Gaps and errors:** W3C-17 to 23. No numbered procedure. Escalation trigger is "team or repository line"; for a one-person build state it as independent deployment. No error-status cases, no gRPC route.
3. **Go mirror:** apply: W3B-38 (the Python text states the limit honestly at `SKILL.md:48-50`, but still overclaims what Pact replay would catch), W3B-39 (presence and type only, one 200), W3B-40, W3B-41 (BACKWARD hardcoded, and here wrong), W3B-37 in part (`ref/provider-consumer-ci.md:169-180` names `can-i-deploy` with no recorded deployment step). Do not apply: W3B-36.
4. **Folder moves:** harness and workflows to `templates/`; Pact tier to one reference behind the trigger; consumer-field example to `examples/`.
5. **Example ideas:** (a) lean: modular monolith, spec conformance only; (b) standard: three services, `oasdiff` against the deployed spec plus event compatibility; (c) enterprise: partner consumer, Broker, provider states, message pact.
6. **Eval ideas:** (a) "Is making this optional field required BACKWARD safe?" (b) CI green with "1 deselected": spot that nothing ran. (c) `$ref` resolution error. (d) Consumer repository asked to import the provider app. (e) Enum widened and "schema tests pass".
7. **Overlaps:** `python-openapi-codegen` conformance gate, `event-schema-design`, `api-contract-design`.
8. **Size:** L.

### python-e2e-test

1. **Sources**
   - `agile-testing-crispin-gregory.md:11,14`. `winteringham:11,14`. `khorikov:16`.
   - `continuous-delivery:8,10,16`. `halstead:49` (calls it thin, with `playwright-python`; the skill declines the browser surface, which is reasoned).
2. **Gaps and errors:** W3C-24 to 28. No journey-selection step from acceptance criteria. "Nightly failure opens an issue and blocks promotion" (`ref/flake-and-scope.md:245-247`) has no workflow step. `e2e_test_cadence` is not in the config field reference. "Same digest" is claimed; no digest is set. Compose "for authoring" has no stated limit.
3. **Go mirror:** apply: W3B-1, 3, 23, 50, 51, 53. Variant: W3B-2 (`-m smoke` selects correctly; the smoke example itself is destructive), W3B-4 (janitor claimed, not shown), W3B-5 (rerun is a plugin flag; the record is never written), W3B-7 (helper never called; no exporter shown), W3B-24 (unregistered key, no wrong parent key). Do not apply: W3B-6.
4. **Folder moves:** script to `scripts/` with a test; workflow, quarantine issue and `conftest.py` to `templates/`; journey to `examples/`.
5. **Example ideas:** (a) lean: one service and database run locally, Must journeys only (batch B B-3); (b) standard: `kind`, two services and a broker, nightly plus read-only smoke; (c) enterprise: ring smoke with synthetic identity, quarantine in use, trace-linked failure.
6. **Eval ideas:** (a) Workflow review with the EXIT trap. (b) "Mark the whole journey smoke". (c) "Use `ASGITransport` to make e2e faster". (d) "Retry three times". (e) Lean product asks for a cluster on every pull request.
7. **Overlaps:** `react-e2e-testing`, `cd-pipeline`, `go-e2e-test` (script, teardown, quarantine policy).
8. **Size:** L.

### python-mutation-test

1. **Sources**
   - `khorikov:14,25,54`. `jorgensen:33,53`. `halstead:52,90`. `testing-vv-dictionary-quigley.md:25-29`.
2. **Gaps and errors:** W3C-3, 6, 39 to 41. `SKILL.md:45` defines score as killed/(total minus equivalent); the script computes killed/(killed plus survived). No baseline-then-ratchet route, no handling of timeout or uncovered mutants, no report template. cosmic-ray config omits worker addresses for its HTTP distributor [GK]. The first parametrize listing (`ref/interpreting-survivors.md:49-55`) uses a sliced tuple nobody should copy. The Go comparison (`ref/mutmut-setup-and-score.md:58,90-93`) repeats Gremlins claims batch B marked doubtful.
3. **Go mirror:** apply: W3B-20 (as W3C-39), 21, 22, 23, 50, 53, batch A W3A-9. Batch B B-7 applies ("proven achievable" at `SKILL.md:59` has no evidence).
4. **Folder moves:** config and workflow to `templates/`; gate to `scripts/` with a test; two dispositions to `examples/`; report to `templates/`.
5. **Example ideas:** (a) lean: do not run; boundary review instead; (b) standard: first run on one critical package, three survivors; (c) enterprise: billing rules, distributed run, recorded equivalents and trend.
6. **Eval ideas:** (a) "100% coverage, done?" (b) A changed default constant called equivalent. (c) Gate reports 0% with survivors listed: find the parsing fault. (d) "Run on every pull request". (e) Lean product asks for a gate.
7. **Overlaps:** `python-unit-test` coverage, `python-makefile`, `test-pyramid`, `go-mutation-test`.
8. **Size:** M.

### python-load-test

1. **Sources**
   - `site-reliability-engineering...md:7,10,27` (SLO; golden signals; split latency by outcome).
   - `continuous-delivery:16` (capacity as a stage).
   - `halstead:53,89`: k6 as the one tool, "rather than introducing Locust". The skill adopts both. `accelerate:51` weakly. No research on load method.
2. **Gaps and errors:** W3C-29 to 35, 46. No k6 code although offered; no seed-data volume, warm-up, generator saturation check or step from NFR figures to profile. Profile numbers (50 and 500 users, 30 requests per second, 500 and 10,000 documents) have no source. `verify-async-slos.sh` is promised and absent; backpressure assertions are prose only; Smoke "every change" runs against staging with no workflow.
3. **Go mirror:** apply: W3B-8 (as a false pass, not a breach), W3B-10, W3B-11 (`ref/criteria-and-analysis.md:106-112`), W3B-12, W3B-19, W3B-48, W3B-50, W3B-53. Do not apply: W3B-9 (Python states Ramp as closed consistently), W3B-13.
4. **Folder moves:** scenarios to `templates/`; both verify scripts to `scripts/` with tests; report template.
5. **Example ideas:** (a) lean: one stated NFR, one local constant-rate run marked indicative; (b) standard: soak with many subjects and shed ceiling; (c) enterprise: spike with async drain and noisy-neighbour check per the tenancy design.
6. **Eval ideas:** (a) "p99 improved and errors are low" with most requests `429`. (b) "`constant_throughput` makes it open-model": refute. (c) p99 offered for a 99.5% objective. (d) No NFR: refuse to invent. (e) `increase()` on a depth gauge.
7. **Overlaps:** `go-load-test` (scenarios, SLO gate, PromQL can be one owner), `slo-definition`, `python-middleware`, `python-performance-test`.
8. **Size:** L.

### python-performance-test

1. **Sources**
   - `halstead:54,91` (`pytest-benchmark`, `asv`). `continuous-delivery:16`. `software-architecture-in-practice-bass.md:69` and `fundamentals-of-software-architecture-richards-ford.md:12` (fitness functions, as batch B found).
2. **Gaps and errors:** W3C-36 to 38, 3. No step for choosing what to track or for the first baseline; budgets file promised, no template and no budget; 12% unsupported; `COVER_MIN`-style override has no registered key; allocation regressions are handed to a skill that states it only measures by hand (boundary table `SKILL.md:34-38`), so nothing gates them.
3. **Go mirror:** apply: W3B-15 (committed baseline from another machine; "dedicated, quieter" job is a shared hosted runner), W3B-19, W3B-53. Variant: W3B-14 (the gate exists as a flag but is broken), W3B-24 (unregistered override). Do not apply: W3B-16, 17, 18.
4. **Folder moves:** workflow to `templates/`; base-and-head runner to `scripts/` with a test; two benchmarks to `examples/`.
5. **Example ideas:** (a) lean: no gate; one benchmark for a stated NFR; (b) standard: base-and-head comparison of three hot paths; (c) enterprise: pinned runner, allocation check, recorded trade-off approval.
6. **Eval ideas:** (a) Gate errors "requires valid compare". (b) Baseline from a laptop. (c) "Update the baseline so CI passes". (d) Benchmark that opens a database connection. (e) Perf job failing on coverage.
7. **Overlaps:** `python-performance-optimization`, `python-makefile`, `python-load-test`.
8. **Size:** M.

### python-chaos-test

1. **Sources**
   - `halstead:51,88`. `devops-handbook...md:15,56` (origin; names the missing chaos book). `site-reliability-engineering...md:18,77`. `building-microservices-newman.md:12`. The Go concurrency research does not transfer.
2. **Gaps and errors:** W3C-35, 42 to 46. Steady state "60s pre-fault window" is a single call in code and uses metric names (`classify_duration_seconds`, `requests_total{status}`) that differ from the metrics design. `toxiproxy-python` 0.1.1 is what installs; [GK] it is old and lightly maintained. Dependency list omits `testcontainers[redpanda]`. `disaster-recovery-plan/SKILL.md:107` bridges only to `go-chaos-test`. No result template.
3. **Go mirror:** apply: W3B-45, 47, 48, 49, 50, 51, 53. Variant: W3B-44 (watchdog has a timeout but is unused). Do not apply: W3B-42, 46; W3B-43 (templates target an ephemeral stack, which is better than Go).
4. **Folder moves:** header and harness to `templates/`; experiments to `examples/`; safety checklist to `resources/`; report template.
5. **Example ideas:** (a) lean: do not run; one dependency-timeout integration test; (b) standard: breaker through open, half-open, closed plus broker kill; (c) enterprise: event-loop stall and isolation-between-tenants experiment per the tenancy model, then a wider non-production stage.
6. **Eval ideas:** (a) One-call breaker test claimed as proof. (b) Experiment with no numeric abort. (c) Resilience pattern that the code does not have. (d) Production first run. (e) Lean product asks for a suite.
7. **Overlaps:** `disaster-recovery-plan`, `python-load-test`, `go-chaos-test`, `python-integration-test`.
8. **Size:** L.

## Contradictions needing a product-owner decision

| ID | Question | Options | Recommendation | Duplicates |
|---|---|---|---|---|
| C-1 | Does the TDD gate cover Python | (a) extend the hook to `.py`, with the same exemptions chosen for Go (`tests/**`, `conftest.py`, `__init__.py`, migrations, sibling or mirrored test paths); (b) state in the skill that Python relies on review and history | (a), decided together with B-1 so one rule serves both languages | New; extends B-1 and A D-9 |
| C-2 | Which Python pytest configuration and layout is canonical | (a) `python-project-structure` layout and one `pyproject.toml` template owned by `python-makefile`, coverage flags on the make target; (b) each test skill keeps its own block | (a) | New |
| C-3 | Keeping slow suites out of `make ci` | (a) markers plus `-m "not e2e and not chaos"` and `--ignore=tests/benchmarks`; integration stays in `ci`; (b) separate directories selected by path only | (a) | Python form of B-2 |
| C-4 | Python load tool | (a) k6 only, scenarios shared with Go (`halstead:53,89`; native open model); (b) locust default with k6 alternative (today); (c) both | (a); it removes W3C-31 and 32 and one duplicate | New |
| C-5 | Who owns and loads the Python test skills | (a) `test-strategist` owns, `backend-engineer` applies unit and integration, retrieved when the stack override is Python rather than preloaded; (b) preload all in `backend-engineer`; also decide whether that agent is stack-neutral | (a) | Extends B-9 with the stack-conditional question (`halstead:102`) |
| C-6 | Contract compatibility mechanism | (a) `oasdiff` (already used by `python-openapi-codegen`) for HTTP, the registry or the event design's CI gate for events, `jsonschema` for conformance; `schemathesis` only if B-6 places behaviour checks; (b) keep hand-written checkers | (a) | New; touches B-6 |
| C-7 | mutmut major version | (a) pin 3.x and rebuild config and gate; (b) pin 2.x as written; (c) cosmic-ray default | (a), verified against its documentation at build time | New |
| C-8 | Shape of the Python mirrors | (a) one owner per language-neutral method (k6, SLO gate, experiment header, journey selection, triage), Python skills hold code and config; (b) full mirrors | (a) | Formalizes batch B's shared-structure note |
| C-9 | Order of repair | (a) first reconcile `python-domain-model`, repository, service layer, consumer and migration names, then rebuild tests; (b) rebuild tests against today's text | (a) | New |

Batch decisions that apply unchanged, so no new ruling is needed: A D-1 (rollback default; Python complies), A D-2 (one retry at e2e only), A D-3 (coverage floor), A D-4 and B B-7 (mutation threshold), B B-3 (e2e environment), B B-4 (base-and-head performance gate, strongly supported by W3C-37), B B-5 (chaos cadence), B B-6 (behaviour checks), B B-8 (chaos tooling; Python already follows the recommended rule).

## Missing books

| Book or source | Why it came up | Needed? |
|---|---|---|
| Official documentation for locust or k6, mutmut, pytest-asyncio, pytest-benchmark, testcontainers-python, toxiproxy, jsonschema | Most Python defects are tool behaviour | Required at build time; not books |
| Hypothesis documentation | Named by the research, used nowhere | Documentation suffices |
| Rosenthal and Jones, *Chaos Engineering* | Same gap as batch B | Useful, not blocking |
| A load-testing method text | No research on workload models or coordinated omission | Optional |

No new book blocks these rebuilds. The two Python research files say they were written from working knowledge (`okken:5`; `percival:5`), so cite them for patterns, not for tool behaviour; W3C-1 shows why.

## What I could not verify

- No PostgreSQL, Redpanda, Docker, `kind`, Toxiproxy server or GitHub Actions run. Testcontainers, `aiokafka`, `asyncpg`, Alembic, cosmic-ray, pytest-rerunfailures, pytest-timeout and `httpx` were not installed or exercised; claims about them come from reading or are marked [GK].
- Probes used the latest releases on Python 3.14.4. The skills mostly give lower bounds only, so older releases may behave differently (mutmut 2.x in particular; W3C-40 on the sample output is independent of version).
- The mutation gate script was reproduced by running its two `grep` patterns and arithmetic on the skill's sample output, not with a live mutmut 2.x.
- The compile claims in narrative 4 compare snippets across skills; no worked test was executed end to end.
- Research read in full: `okken`, `percival`, `halstead`, Khorikov, Cruz and Prescott, Winteringham, Jorgensen, SRE, Continuous Delivery, Accelerate, Crispin and Gregory. Hendrickson, Adzic and Quigley were read in part (outside these eight). The DevOps Handbook, Newman, Bass, and Richards and Ford lines are taken from batch B's citations and were not reread. UAT research was not read. The three excluded requirements books were not opened.
- `wave-2-findings.md` was read for its header, narrative opening and section list.
- Neighbouring skills and agents were read only at the passages cited. No evals, contract tests, model calls, git or gh commands were run.
