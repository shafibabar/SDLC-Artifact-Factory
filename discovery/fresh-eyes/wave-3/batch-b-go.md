# Wave 3 Discovery, Batch B: Go Testing Skills

- **Scope:** `go-unit-test`, `go-integration-test`, `go-contract-test`, `go-e2e-test`, `go-mutation-test`, `go-load-test`, `go-performance-test`, `go-chaos-test` (issue #1451).
- **Read:** every file of the eight skills and their contract tests; `CLAUDE.md`; `skill-authoring-standards/SKILL.md`; batch A; `scripts/tdd-gate.sh`; research listed under "What I could not verify"; the parts of preloading agents, `phase-requirements.json` and neighbouring skills cited below; short passages of the eight `python-*-test` bodies.
- **Executed:** `lint-skill-layout.py --skill` and `validate-skill-structure.sh` for all eight; `scripts/tdd-gate.sh` with synthetic input (files created only in the scratch directory). No Go, k6, Gremlins, Pact or Chaos Mesh run.
- **[GK]** marks a claim resting on general knowledge of Go or a tool, not on text in this repository. Confirm it against official documentation before the rebuild.
- File paths in the tables are relative to `skills/`. `ref/x.md` means `<skill>/references/x.md`.

## Narrative

**1. Following the e2e procedure as written cannot work, and the smoke path can damage a real environment.**
- `provision-kind.sh` sets `trap cleanup EXIT` and ends after the Helm rollout (`go-e2e-test/references/environment-provisioning-standard.md:39-50`). The nightly workflow runs the script as its own step and runs `go test` in the next step (`ci-placement-and-trigger-standard.md:39-40`). The cluster is therefore deleted before any journey runs. The `script && go test` form (`test-data-seeding-and-teardown-standard.md:52`) has the same fault, because the trap fires when the script process exits.
- The smoke subset is selected with `-tags smoke` over `./tests/e2e/...` against real dev, staging and tenant environments (`go-e2e-test/SKILL.md:77,103`; `ci-placement...md:76-80`). [GK, certain] Go build tags are additive: untagged files always compile. The command runs every untagged journey, including the ones that seed and tear down data, plus the smoke files. A file tagged `smoke` is also left out of the nightly full run, which passes no tag.
- The script installs three product charts only. It installs no Linkerd, ingress, PostgreSQL or Redpanda, and so cannot show the mesh handshake, ingress or data path the body promises (`SKILL.md:50`).
- Teardown layer 3 reads a `created-at` field from the kubeconfig that nothing writes, so it deletes nothing (`test-data-seeding...md:61-72`). [GK] A janitor on another hosted runner cannot see that runner's `kind` clusters anyway.

**2. The load gate cannot give a true verdict.**
- The scripts send every request with one `__ENV.TOKEN` (`load-profile-standard.md:121-125`). The service rate limiter allows 10 requests per second per subject, burst 20 (`go-middleware/SKILL.md:118`). Soak runs at 30 requests per second.
- The availability threshold is `http_req_failed: rate<0.005`. [GK] k6 counts a 429 as failed. The SLI it claims to copy counts non-5xx as good (`slo-gate-standard.md:25`). So Soak breaches by construction, and the Ramp run asks for rising 429s under the same threshold (`backpressure-and-reporting-standard.md:56-60,79`).
- Ramp is declared closed-model `ramping-vus` (`load-profile-standard.md:80,138`; `backpressure...md:28-30`) while the only Ramp script is open-model `ramping-arrival-rate` (`load-profile-standard.md:102`).
- The backpressure "assertions" are `check()` calls with no `checks` threshold, so they never fail a run [GK]; the one added threshold is `count>0`.
- The correctness query applies `increase()` to `pipeline_dlq_depth` (`slo-gate-standard.md:107-109`), which is a gauge (`prometheus-metrics-design/references/cardinality-and-histograms.md:51`).
- Smoke runs "on every change" and in the PR loop (`load-profile-standard.md:85`; `SKILL.md:175`) against `staging`, which does not hold the PR's build.

**3. Several gates gate nothing.**
- `scripts/check-perf-regression.sh` is the whole pass/fail logic of the performance gate (`benchmark-and-regression-gate-standard.md:177-180`). It does not exist and no file says how to write it. The 5 ms and 32 allocation budgets are checked by nothing, and a Go benchmark reports no p99 [GK], so "p99-equivalent" is not measurable.
- [GK] The Gremlins configuration uses a flat `threshold-efficacy` key and an `excludes` list, the body tells the agent to use a `//gremlins:disable-next-line` comment, and the workflow uploads `gremlins.json` without any flag that writes it. I believe none of the three exists in that form. In the text, the two exclusion mechanisms already contradict each other (`go-mutation-test/SKILL.md:90` against `tool-configuration-and-targeting.md:36-40`), and `threshold-mcover: 0` means uncovered code does not lower the gated figure [GK].
- "Pre-release" runs trigger on `release: types: [published]` in mutation and e2e, that is after the release is out (`tool-configuration...md:103-104`; `ci-placement...md:30-31,49`).
- Pact: `can-i-deploy --to-environment` and the `Deployed` selector need a recorded deployment [GK]; no step records one (search for `record-deployment` found none). Pending and WIP Pacts are told to be enabled but no code or flag enables them.
- `make ci` runs `go test $(PKG)` with `PKG := ./...` (`go-makefile/references/quality-gate-targets.md:21`). The e2e, chaos and Pact-provider tests carry no build tag or skip guard, so they would run on every PR against nothing.

**4. Copy-ready code that does not compile, or passes without proving anything.**
- Integration: `postgres.NewDataAssetRepo(tx)` appears twice, but the repository constructor takes `*pgxpool.Pool` and rebinds with `WithTx` (`go-repository-pattern/references/error-translation-and-transactions.md:116-123`). `TestMain` declares an unused `t` and calls an undefined `dummyT` (`testcontainers-setup-standard.md:92-94`).
- The duplicate-delivery test asserts `countProcessed == 1` immediately after republishing, with no consumer wired and no wait for the second delivery (`repository-and-event-testing.md:49-59`). It passes whether or not the consumer deduplicates. The body calls this assertion essential.
- `-short` handling calls `os.Exit(0)` in `TestMain` (`testcontainers-setup-standard.md:88-91`), which silently skips every test in that package, unit tests included.
- Unit: the fuzz example calls `level.rank()` (`go-unit-test/SKILL.md:133`); `go-domain-model` defines no such method, only a `sensitivityRank` map.
- Contract: a package-level `providerStateHandlers` map refers to an undeclared `t` (`provider-state-setup-standard.md:13-17`).
- Chaos: the breaker tests make one request and never read breaker state, half-open or closed (`go-chaos-test/SKILL.md:69-83`); the pool test bounds elapsed time by `HealthCheckPeriod+2s`, which is unrelated to acquisition [GK default 1 minute, so the bound is vacuous], and relies on an "AcquireTimeout" pool setting that [GK] pgxpool does not have. The deadlock experiment injects its own reversed locks and asserts that they deadlock, so it never exercises the shipped lock order.

**5. The first product's tenancy model is stated as fact, and the cited source says the opposite.** `go-performance-test/references/performance-budgets.md:73-81` says `multi-tenancy-design` "establishes this product on Model 3: Physical Isolation" and quotes it. `multi-tenancy-design` 3.0.1 says "There is no plugin default" and contains neither phrase. The budgets and the skill description (`SKILL.md:15-18`) derive from it. The same assumption appears as per-tenant stamps in load, e2e and chaos. #1438 corrected platform and security components; these testing skills were not covered.

**6. The TDD hook blocks the declared output files, and more than batch A found.** Synthetic runs denied `internal/test/containers.go`, `tests/e2e/seed.go`, `tests/e2e/trace.go`, `tests/chaos/toxiproxy.go`, `internal/test/faults/publisher.go` and `.../provider/state_handlers.go`. It also denied `internal/infrastructure/postgres/dataasset_repo.go` when only `dataasset_repo_integration_test.go` existed. These skills say a repository or thin handler gets no unit test and an `*_integration_test.go` file instead; the hook accepts only `<name>_test.go`. This extends W3A-1: exempting `internal/test/**` (batch A D-9) is not enough.

**7. Shared structure gaps.** All eight: no `sources:`, no `## Gotchas`, no `templates/`, `resources/`, `examples/` or `scripts/`, no eval suite, no lean / standard / enterprise rule, descriptions of 1087 to 1604 characters that list contents and never say "Use when". Lean guidance forbids chaos and mutation runs (`phase-requirements.json:982`); neither skill knows. Layout lint is clean for all eight; the structure validator fails `go-performance-test` (2) and `go-chaos-test` (1) on cross-skill `references/...` mentions. No test artifact or report is in the manifest, and every report path is `docs/quality/*.md`, outside `artifacts/`, with no frontmatter template, so no hook validates or registers it.

## Findings table

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| W3B-1 | Mechanics | `go-e2e-test/ref/environment-provisioning-standard.md:39-50`; `ref/ci-placement...md:39-40`; `ref/test-data-seeding...md:52` | Cluster deleted before tests run | One script owns provision, test, teardown; or no trap in the provisioning step | Defect | H | S | High |
| W3B-2 | Safety | `go-e2e-test/SKILL.md:77,103`; `ref/ci-placement...md:70-80` | `-tags smoke` runs the destructive journeys against real environments | Separate smoke directory, or `-run` prefix; tag destructive files `//go:build e2e && !smoke` | Defect | H | S | High [GK certain] |
| W3B-3 | Completeness | env-provisioning `:42-50`; `SKILL.md:50` | No mesh, ingress, database or broker installed | Dependency install step, or narrow the claim per profile | Defect | H | M | High |
| W3B-4 | Teardown | `ref/test-data-seeding...md:39-72` | Janitor deletes nothing; wrong runner | Delete the layer on ephemeral runners; keep it only for persistent resources | Defect | M | S | High |
| W3B-5 | Retry | `ref/flakiness...md:15-17`; `ref/ci-placement...md:40-41` | Rerun builds `-run` from failed names; an empty list reruns all; subtest slashes break the pattern [GK]; flaky record never written; quarantine run recompiles all tests | Replace with a tested script | Script | M | M | Medium |
| W3B-6 | Determinism | `ref/journey-test...md:24` vs `ref/test-data-seeding...md:9-11` | Run id includes `uuid.NewString()`; upsert-from-run-id claim defeated | Run id from CI | Contradiction | L | S | High |
| W3B-7 | Tracing | `ref/journey-test...md:80-85` | Span never ended; no exporter or propagator set up [GK no trace id] | Show setup or send an explicit test-id header | Defect | M | S | Medium |
| W3B-8 | Gate | `go-load-test/ref/load-profile...md:121-125`; `go-middleware/SKILL.md:118`; `ref/slo-gate...md:25` | One subject hits the limiter; 429 counted as unavailability | Many subjects; `expectedStatuses` or a custom 5xx metric; split latency by outcome (SRE research) | Defect | H | M | High (limit, mapping); [GK] k6 default |
| W3B-9 | Consistency | `ref/load-profile...md:80,102,138` | Ramp is both open and closed | Open-model (arrival rate) for ramp and breakpoint; correct the reasoning | Contradiction | H | S | High |
| W3B-10 | Gate | `ref/backpressure...md:56-72` | Checks never gate; backpressure unproven mechanically | Thresholds on `checks` and a 429 metric; post-run script | Defect | H | S | Medium [GK] |
| W3B-11 | Query | `ref/slo-gate...md:105-110` | `increase()` on a gauge | Ratio of `outcome` counter values | Defect | H | S | High |
| W3B-12 | CI | `go-load-test/SKILL.md:175`; `ref/load-profile...md:85` | PR smoke tests staging, not the PR build; no workflow YAML for it; shared staging also takes e2e | Smoke against a PR-local instance, or after deploy | Defect | H | M | High |
| W3B-13 | Tool | `ref/backpressure...md:102-106` | [GK] `--env` sets script variables, not output settings; remote-write receiver must be enabled | Verify and correct | Defect | M | S | Low |
| W3B-14 | Script | `go-performance-test/ref/benchmark...md:177-180` | Gate script missing | Write `scripts/check-perf-regression` in the skill with a test | Script | H | M | High |
| W3B-15 | Method | `ref/benchmark...md:64-83,95,120,140`; `SKILL.md:61` | Baseline from another machine compared on shared runners; "dedicated runner" and "shared runners" both claimed; 12% unsupported; release refresh has no workflow | Benchmark base and head in the same job; decision B-4 | Rewrite | H | M | High on text; [GK] noise |
| W3B-16 | Accuracy | `ref/benchmark...md:99-105` | [GK] Old `benchstat` output shape; the B/op row is malformed; Go 1.24 `b.Loop` not mentioned | Regenerate from a real run | Defect | M | S | Medium |
| W3B-17 | CI | `ref/benchmark...md:161-162` | `paths: internal/**` misses `go.mod`; [GK] a required check with a path filter stays pending | Run always, skip inside the job | Defect | M | S | Medium |
| W3B-18 | Leakage / false citation | `go-performance-test/ref/performance-budgets.md:73-92`; `multi-tenancy-design/SKILL.md` | Cites a tenancy model the cited skill does not hold | Budgets from the product's SLO and tenancy design; data-estate numbers move to an example | Defect | H | M | High |
| W3B-19 | Invented numbers | `ref/performance-budgets.md:35,66`; `go-load-test/ref/load-profile...md:80-83` | 5 ms, 32 allocs, 4 KB, 50/500 VUs, 30 req/s, 10,000 documents are defaults with no source | Derive from NFR IDs; never default a number (matches W3A-14) | Defect | H | M | High |
| W3B-20 | Tool config | `go-mutation-test/ref/tool-configuration...md:26-41,116-125`; `SKILL.md:90` | Config keys, exclusion mechanisms and report upload doubtful or contradictory | Verify against Gremlins docs; commit a tested config template | Defect | H | M | High on contradiction; [GK] keys |
| W3B-21 | Definition | `SKILL.md:60,74` | Score formula subtracts equivalents; [GK] the tool computes killed/(killed+lived) and ignores uncovered | State what the tool gates and what triage adjusts; set mutant-coverage floor | Defect | M | S | Medium |
| W3B-22 | Tool | `ref/tool-configuration...md:54-62,117` | [GK] two path arguments to `unleash`; `@latest` unpinned; "removes a statement" operator in `SKILL.md:52` | Pin a version; verify | Defect | M | S | Low |
| W3B-23 | CI timing | mutation `:103-104`; e2e `:30-31` | Pre-release gate runs after publication | Trigger on tag push or release-candidate before publishing | Defect | H | S | High |
| W3B-24 | Config | `go-e2e-test/ref/ci-placement...md:63`; `schemas/sdlc-config.schema.json:68`; `config-field-reference.md:116` | Uses `methodology_overrides`; the key is `methodology_parameters`. `e2e_test_cadence` and `perf_regression_threshold_pct` are claimed documented but are not | Fix key; register parameters | Defect | M | S | High |
| W3B-25 | Compile | `go-integration-test/ref/repository...md:21`; `ref/test-isolation...md:35` | Constructor signature wrong | `NewDataAssetRepo(pool).WithTx(tx)` or change the owner | Defect | H | S | High |
| W3B-26 | Compile / lifecycle | `ref/testcontainers-setup...md:81-103` | `TestMain` broken; the shim it defers to is never shown; helpers need a real `*testing.T` | Error-returning start functions, complete `TestMain` template | Defect | H | S | High |
| W3B-27 | False pass | `ref/repository...md:44-60` | Dedup assertion vacuous; no consumer | Wait for the second delivery to be observed (offset or counter), then assert | Defect | H | S | High |
| W3B-28 | Isolation | `ref/repository...md:77-84,109-124`; `ref/timeout...md:78-85` | Cleanup deletes one table; relay drains every tenant's outbox; `awaitEvent` reads any event on a shared topic; tenant scoping does not make parallel relay tests safe | Per-test topic or event-id filter; no parallelism for relay tests | Defect | H | M | High |
| W3B-29 | Skip | `ref/testcontainers-setup...md:89-91`; `ref/timeout...md:86-90` | `-short` exits the whole package | `t.Skip` per integration test, or a build tag (decision B-2) | Defect | M | S | High |
| W3B-30 | Hardening | `ref/timeout...md:18-47` vs setup `:21,39` | Retry helper never wired; 30 s covers three attempts and a cold pull | Wire it; bound each attempt | Defect | L | S | High |
| W3B-31 | Compile | `go-unit-test/SKILL.md:129-137` | `rank()` does not exist; [GK] CI needs `-fuzz` with `-fuzztime`, one target per run, otherwise only seeds run | Fix example; show the CI step | Defect | M | S | High |
| W3B-32 | Hook claim | `go-unit-test/SKILL.md:91`; `scripts/tdd-gate.sh` | Says the hook compares file age; it checks existence (extends W3A-12) | State what it does | Defect | M | S | High |
| W3B-33 | Consistency | `go-unit-test/SKILL.md:188` vs `ref/mocking-philosophy.md:29` | Output format says "mocked ports"; philosophy says fakes for managed ports | "Fakes for managed ports, mocks for unmanaged" | Contradiction | M | S | High |
| W3B-34 | Wrong pointer | `ref/mocking-philosophy.md:29` | Calls `go-repository-pattern.contract.sh` (a plugin skill probe) the integration suite | Remove | Defect | M | S | High |
| W3B-35 | Research gap | `go-unit-test` body; `software-testing-craftsman-jorgensen.md:19-25,31` | No method for deriving cases; the boundary/edge section the research cites is gone | Add a risk-graded step: boundaries, equivalence classes, decision table, state transitions | Augment | H | M | High |
| W3B-36 | Compile | `go-contract-test/ref/provider-state...md:13-26` | `t` undefined; teardown story is confused | Handlers built in a function taking `t` | Defect | M | S | High |
| W3B-37 | Pact | `ref/pact...md:59-90`; `ref/contract-versioning...md:36-43` | No record-deployment, no pending/WIP flags; `{Latest: true}` described as main-branch latest; provider never started; native library setup absent [GK]; v2 selector and state-handler types unverified | Rebuild this reference from official pact-go docs | Defect | H | M | High on absences; [GK] API |
| W3B-38 | Overclaim | `go-contract-test/SKILL.md:45`; `ref/schema...md:7` | [GK] Replaying one seeded response does not detect an enum widened to free text unless the state exercises a new value; the research phrasing is looser than the mechanism | State what replay proves | Defect | M | S | Medium |
| W3B-39 | Weak default | `ref/schema...md:28-36` | The "consumer test" only checks that a field exists in the provider's spec; type or enum changes pass; one 200 response verified | Check type, required and enum; cover error statuses; breaking-change diff against the deployed spec | Augment | H | M | High |
| W3B-40 | Research gap | `testing-web-apis-winteringham.md:8,22,29-31,37-38`; `contract-testing...md:14` | No test of idempotency replay, 429, deprecation header, error branches anywhere in the eight; no message pacts; no endpoint risk rating (W3A-17 passes it here) | Decision B-6 | Augment | H | M | High |
| W3B-41 | Drift | `ref/schema...md:44-52`; `event-schema-design/SKILL.md:73` | Hardcodes BACKWARD; owner allows FORWARD, FULL and transitive modes | Read the mode from the event schema design | Defect | M | S | High |
| W3B-42 | Tool | `go-chaos-test/ref/fault-injection...md:51-52,196-197` | [GK] Chaos Mesh 2.x removed `spec.scheduler`; a separate `Schedule` resource replaced it | Verify; set `duration` as a hard bound | Defect | H | S | Medium |
| W3B-43 | Safety | `ref/safety-rails...md:12-17` vs `ref/fault-injection...md:41-49,88-98,175-181` | First run must be synthetic and ephemeral; every template targets `tenant-acme` or the shared broker | Templates default to the ephemeral namespace | Contradiction | H | S | High |
| W3B-44 | Abort | `ref/safety-rails...md:50-72` | Watcher loops for ever if no breach and never deletes the fault; rule file lacks `apiVersion`/`kind`; in-process abort polling claimed, never shown | Script with timeout and unconditional delete | Script | H | M | High |
| W3B-45 | False proof | `go-chaos-test/SKILL.md:69-83`; `ref/fault-injection...md:126-153`; `ref/deadlock...md:44-72` | One call, no breaker state, ignored `AddToxic` error, vacuous bound, no header on the toxiproxy example | Drive past the failure threshold; assert open, half-open, closed; deadlock experiment must exercise production ordering | Rewrite | H | M | High; [GK] pgxpool |
| W3B-46 | Compile | `ref/deadlock...md:33,48,59,75-83` | Untagged test calls a symbol that exists only under a build tag [GK will not compile]; goroutine baseline taken after pool start, then expects baseline+poolSize | Tag the test file; fix the signal | Defect | M | S | High |
| W3B-47 | Coverage | `go-chaos-test/SKILL.md:92-101,123` | Poison message, duplicate, graceful shutdown, retry rows have no template; pointer to a "Frugality Note" that does not exist (`ref/fault-injection...md:19,24`) | Add or drop rows; fix pointer | Defect | M | M | High |
| W3B-48 | Metrics | `ref/experiment-design...md:19-21` vs `go-load-test/ref/backpressure...md:79` | Different metric and label names for the same signals | Use the metrics design's names | Defect | L | S | High |
| W3B-49 | Cadence | `disaster-recovery-plan/SKILL.md:80,109-127`; `phase-requirements.json:982,989` | Weekly chaos required there; none at lean, optional at standard; chaos skill silent on cadence | Decision B-5 | Contradiction | H | S | High |
| W3B-50 | Scaling | all eight bodies; `phase-requirements.json:981-996` | Every tier mandated at every size (kind cluster, Pact Broker rules, chaos, mutation) | Profile table in each body, starting with "do not run" where the plan says so | Augment | H | M | High |
| W3B-51 | Mechanics | `quality-gate-targets.md:21`; output formats | Non-PR suites run in `make ci` | One build-tag scheme for e2e, chaos, pact (decision B-2) | Defect | H | S | High |
| W3B-52 | TDD hook | synthetic runs; narrative 6 | Helpers and integration-only files denied | Extend batch A D-9 (decision B-1) | Defect (cross-component) | H | M | High (ran hook) |
| W3B-53 | Pipeline | `phase-requirements.json:907-910`; output formats | No test suite or report registered; `docs/quality/` outside artifacts | One `quality/test-report` artifact family with templates (extends W3A-19) | Pipeline gap | H | M | High |
| W3B-54 | Stack | all eight; `ref/contract-versioning...md:11`; `go-contract-test/SKILL.md:37` | "This repo", data-estate names and `estate-scanner` throughout rules, not only examples | Generic rules; domain into `examples/` | Leakage | H | L | High |
| W3B-55 | Description | frontmatter of eight | Over 1024 characters (all; [GK] platform limit), content lists with file names | Rewrite as usage conditions; MAJOR bump | Description | H | S | Measured; limit [GK] |
| W3B-56 | Preload | `agents/test-strategist.md` `skills:` | Preloads all eight (16 skills) on every run, whatever the profile or stack; no Python equivalents | Keep `go-unit-test`, `go-integration-test`, contract preloaded; retrieve the rest | Agent change | M | S | High |
| W3B-57 | Agent drift | `agents/test-strategist.md` directives 1, 3, 5 | "Timestamps", per-tenant parallel safety, "branch focus" repeat claims the skills or hook contradict | Fix with the rebuild | Defect | M | S | High |
| W3B-58 | Contract tests | `tests/skills/go-*.contract.sh` | One substring each; they pin `IsLastPage`, `unclassified is lowest`, `pegged` | Retire when evals pass | Test | L | S | High |

## Per-skill sections

### go-unit-test

1. **Sources**
   - `unit-testing-khorikov.md`: pillars (`:7`), refactoring resistance (`:8`), classical school (`:9`), mock vs stub (`:10`), managed vs unmanaged (`:11`), quadrants (`:12`), Humble Object (`:13`), coverage not a target (`:14`), overspecification (`:15`), one act per test (`:28`), C# caveat (`:52-53`).
   - `software-testing-craftsman-jorgensen.md`: boundary values (`:9`, `:19`), equivalence classes (`:10`), decision tables (`:11`, `:21`), state-transition coverage (`:25`, `:54`), apply selectively (`:51`).
   - `100-go-mistakes-harsanyi.md`: loop capture and `t.Cleanup` (`:12`, `:18`). `the-go-programming-language-donovan-kernighan.md`: table-driven lineage, `httptest` (`:14`).
2. **Gaps and errors:** W3B-31 to 35, 52. No procedure at all: nothing says "1. classify, 2. derive cases, 3. write failing test, 4. run, 5. check". No coverage of `t.Parallel` with `t.Setenv` [GK panics], `go test -fuzz` in CI, time-dependent concurrent code ([GK] `testing/synctest` in recent Go). `math/rand/v2` and auto-seeding not addressed [GK]. `go.mod` Go version assumed for loop-variable semantics [GK]. `related:` omits `go-chi-handler`, which the quadrant table relies on.
3. **Folder moves:** table and fuzz skeletons to `templates/`; `worked-example.md` to `examples/`; `coverage-by-quadrant.md` folds into the body table plus one reference shared with the pyramid; mocking philosophy reduced to a pointer once `mock-generation` owns "how" (W3A-34: one home for "whether" should be here); `resources/` checklist.
4. **Example ideas:** (a) lean: a loyalty-points calculation, boundaries then table; (b) standard: a subscription Aggregate with guarded transitions and a decision table; (c) enterprise: a tariff engine with an injected clock, fuzzed parser, concurrent evaluator under `-race`.
5. **Eval ideas:** (a) "Test this thin handler to 90%": trap is mocking everything. (b) "Verify `Save` was called once". (c) Parent `defer` with parallel subtests. (d) A rule with three boolean conditions: trap is three happy rows. (e) "Our pre-1.22 habit `tt := tt`". (f) Fuzz target that "runs in CI" with plain `go test`.
6. **Overlaps:** `mock-generation`, `test-fixture-design`, `go-domain-model` unit standard, `go-error-handling/references/testing-error-paths.md`, `go-integration-test`.
7. **Size:** M.

### go-integration-test

1. **Sources**
   - `unit-testing-khorikov.md:11,13` (managed dependencies verified by end state).
   - `testing-web-apis-winteringham.md`: bounded polling with correlation (`:14`, `:23`, `:31`), workflow tests (`:11`, `:21`).
   - `software-testing-craftsman-jorgensen.md:15,32,52` (build order; limited fit).
   - `concurrency-in-go-cox-buday.md:11` (context deadlines).
   - `continuous-delivery-humble-farley.md:15` (migrations through the same path; N and N-1).
2. **Gaps and errors:** W3B-25 to 30, 52. Duplicate retry, poll and `time.Sleep` rules across files. Startup budget figures unsupported; the "400-test package" arithmetic gives postgres alone 7 to 20 minutes and both containers more, so the stated 10 to 30 is loose. [GK] Concurrent open transactions can block or deadlock on unique keys, so `t.Parallel` "is the norm" overstates it. No migration up/down or N-1 test; no DLQ or poison-message round trip although the consumer skill cites this skill as the source; no non-Postgres store (MongoDB, graph) route; Docker availability and image pinning for the Redpanda tag not discussed beyond a fixed `v24.1.1`.
3. **Folder moves:** `containers.go`, `withTx`, `awaitEvent`, `freshTenant` to `templates/` as compiling files; round-trip tests to `examples/`; isolation decision table stays one reference and becomes the single owner of isolation (W3A-21); `resources/` checklist.
4. **Example ideas:** (a) lean: one repository, rollback default, no broker; (b) standard: outbox plus consumer with a duplicate that is proven observed; (c) enterprise: pooled tenancy with row-level security proving cross-tenant denial, expand/contract migration, parallel CI shards.
5. **Eval ideas:** (a) Outbox atomicity inside rollback. (b) "Write the redelivery test": grader requires evidence the second delivery was consumed. (c) `time.Sleep` for the relay. (d) `-short` skip placement in a mixed package. (e) Single-tenant product: no invented `tenant_id`.
6. **Overlaps:** `test-fixture-design`, `go-repository-pattern`, `go-event-consumer`, `go-contract-test` provider states.
7. **Size:** L (code must be made to compile).

### go-contract-test

1. **Sources**
   - `contract-testing-in-action-cruz-prescott.md`: schema vs contract (`:7`), consumer mock (`:8`), provider states (`:9`), Broker and can-i-deploy (`:10`), pending/WIP (`:11`), versioning (`:12`), bi-directional is paid (`:13`), message contracts (`:14`, `:23`), placement (`:15`), not Go-specific (`:54`).
   - `building-microservices-newman.md:10,13` (Tolerant Reader).
   - `testing-web-apis-winteringham.md:10,22,30` (behaviour beyond shape).
2. **Gaps and errors:** W3B-36 to 41. No numbered procedure for "list consumers, pick the tier, write, wire the gate". Decision table triggers on team lines, which a one-product-owner build rarely has; state the trigger as independent deployment. gRPC contracts absent (`grpc-contract-design` exists). No breaking-change diff of the OpenAPI file. Frontend consumer (`react-api-client`) not covered. The bi-directional and PactFlow warning is repeated three times. Output paths mix two layouts without saying one replaces the other.
3. **Folder moves:** schema tier stays near the body; whole Pact tier into `references/` behind the escalation trigger; consumer, provider and CI YAML to `templates/`; tier-choice example to `examples/`.
4. **Example ideas:** (a) lean: modular monolith plus React client, generated types only, no contract suite beyond spec conformance; (b) standard: three services in one repository, breaking-change diff against the deployed spec plus event compatibility; (c) enterprise: partner-owned consumer, Broker, provider states, pending pacts, message pact.
5. **Eval ideas:** (a) Lean single repo asks for Pact. (b) Enum changed to free string "and schema tests pass". (c) Provider state seeded in a rolled-back transaction. (d) can-i-deploy with no recorded deployment. (e) "Use the hosted broker".
6. **Overlaps:** `api-contract-design`, `event-schema-design`, `context-map-patterns`, `integration-design`.
7. **Size:** L.

### go-e2e-test

1. **Sources**
   - `unit-testing-khorikov.md:16` (shape as outcome).
   - `agile-testing-crispin-gregory.md:11,14` (checks; brittle top layer).
   - `testing-web-apis-winteringham.md:11,14` (workflow tests, polling).
   - `testing-vv-dictionary-quigley.md:33-34` (smoke vs sanity; low confidence per `:7`).
   - `continuous-delivery-humble-farley.md:8,10` (exact artifact, acceptance stage).
   - `site-reliability-engineering...md` and `building-microservices-newman.md:12` (semantic checks after deploy).
2. **Gaps and errors:** W3B-1 to 7, 23, 24, 51 to 53. Direct SQL seeding into the cluster conflicts with a black-box journey; no port-forward or base-URL setup. No journey selection procedure from acceptance criteria. Cost arithmetic cites `go-mutation-test` but gives no numbers. [GK] Behaviour of `if: always()` on a job timeout is not guaranteed as stated. Playwright files listed here and owned by `react-e2e-testing`. `kind` cluster is overbuild for a lean single binary.
3. **Folder moves:** script, workflow and janitor into `scripts/` and `templates/` with a `bash -n` plus behaviour test; quarantine issue template (promised at `SKILL.md:89`, absent) into `templates/`; journey test into `examples/`.
4. **Example ideas:** (a) lean: one binary and a database started by compose or locally, three Must journeys (decision B-3); (b) standard: `kind` with two services and a broker, nightly plus smoke; (c) enterprise: per-ring smoke on real environments, read-only, synthetic tenant, quarantine in use.
5. **Eval ideas:** (a) "Add a smoke tag so promotion runs only smoke": trap is the additive tag. (b) Review a workflow with the EXIT trap. (c) "Retry until green". (d) Lean product asks for e2e on every PR with a cluster. (e) A "journey" that imports another service's package.
6. **Overlaps:** `react-e2e-testing`, `cd-pipeline`, `disaster-recovery-plan`, `environment-config`, batch A flaky policy.
7. **Size:** L.

### go-mutation-test

1. **Sources**
   - `unit-testing-khorikov.md`: coverage gameable (`:14`), survivor as regression gap (`:25`), mutation lightly covered (`:54`).
   - `software-testing-craftsman-jorgensen.md:33,53` (subsumption vocabulary only; not for mechanics).
   - `testing-vv-dictionary-quigley.md:25-29` (coverage terms).
2. **Gaps and errors:** W3B-20 to 23, 50, 53. No research on mutation mechanics exists, so tool behaviour must come from official docs. "60% is a floor proven achievable" has no evidence. No baseline-then-ratchet route for a first run below 60%. No triage procedure for timed-out or not-covered mutants. Report has a field list but no template. Triage "prove equivalence" method is good and should be kept.
3. **Folder moves:** `.gremlins.yaml` and workflow to `templates/`; the two dispositions to `examples/`; report to `templates/`; a script that reads the tool's JSON into the report.
4. **Example ideas:** (a) lean: do not run it; show the answer and the cheaper boundary review; (b) standard: first run on one critical package, triage three survivors; (c) enterprise: billing rules at a raised threshold, equivalents recorded, trend.
5. **Eval ideas:** (a) "100% coverage, are we done?" (b) A survivor that is equivalent: trap is writing a contrived test. (c) "Run it on every PR". (d) "Mutate the repositories too". (e) Lean product asks for a mutation gate.
6. **Overlaps:** `go-unit-test` coverage, `go-makefile`, `test-pyramid` (W3A-9).
7. **Size:** M.

### go-load-test

1. **Sources**
   - `site-reliability-engineering...md`: SLI, SLO, budget (`:7`), golden signals and failed-request latency (`:10`, `:27`), saturation (`:26`).
   - `continuous-delivery-humble-farley.md:8,16,27` (capacity as a pipeline stage).
   - `accelerate...md:51` (gaming one metric); otherwise little.
   - `concurrency-in-go-cox-buday.md:33` (livelock is not saturation).
   - No research on load-test method or k6.
2. **Gaps and errors:** W3B-8 to 13, 19. No procedure from NFR load figures to a profile; no step for load-generator capacity (VU starvation, `dropped_iterations` [GK]); no seed-data volume; no warm-up; one hardcoded asset id measures one row; journey mix described, never scripted. `verify-async-slos.sh` is promised and absent. Report has no template. 28-day window caveat is good and should be kept.
3. **Folder moves:** scenario files to `templates/`; verify script to `scripts/` with test; reporting plumbing to `references/`; report template.
4. **Example ideas:** (a) lean: one stated NFR, one smoke plus one constant-rate run on a local deployment, declared as indicative; (b) standard: ramp and soak with many subjects, 429 handled, report; (c) enterprise: spike with an async drain, per-tier tenants, noisy-neighbour check.
5. **Eval ideas:** (a) Soak shows 66% "errors" with one token: find the limiter. (b) Closed-model run used for a rate claim. (c) No NFR given: refuse to invent targets. (d) "Run it against production on Friday". (e) Average latency presented as passing.
6. **Overlaps:** `slo-definition`, `nfr-specification`, `go-chaos-test`, `go-performance-test`, `prometheus-metrics-design`.
7. **Size:** L.

### go-performance-test

1. **Sources**
   - `100-go-mistakes-harsanyi.md:19` (measure first, allocations).
   - `the-go-programming-language-donovan-kernighan.md:14` (benchmarks).
   - `continuous-delivery-humble-farley.md:16` (non-functional gate).
   - `software-architecture-in-practice-bass.md:69` (a response measure is the test's pass condition).
   - `fundamentals-of-software-architecture-richards-ford.md:12` (fitness functions).
2. **Gaps and errors:** W3B-14 to 19, 24. No procedure for choosing what to track; no first-baseline step; outbox "Budget 3" refers to a field of another skill's code and states no budget. Three-way boundary is described in the description, body and reference. Two structure-validator failures.
3. **Folder moves:** gate script to `scripts/`; workflow and budget table to `templates/`; benchmark to `examples/`; delete data-estate budgets from `references/`.
4. **Example ideas:** (a) lean: no gate; one benchmark only for a stated NFR; (b) standard: base-vs-head comparison of three hot paths; (c) enterprise: pinned runner, allocation and time gates, deliberate trade-off with a recorded approval.
5. **Eval ideas:** (a) One-run comparison showing +20%. (b) +30% marked `~`. (c) "Update the baseline so CI passes". (d) "Our p99 budget is checked by this benchmark". (e) Baseline recorded on a laptop.
6. **Overlaps:** `go-performance-optimization`, `go-makefile`, `go-load-test`, `slo-definition`.
7. **Size:** M.

### go-chaos-test

1. **Sources**
   - `devops-handbook-kim-humble-debois-willis.md:15,49,56` (origin only; names the missing chaos book).
   - `concurrency-in-go-cox-buday.md:13-14,19-20,45` (partial deadlock, livelock, heartbeat).
   - `site-reliability-engineering...md:77` (thin on chaos), hypothesis troubleshooting (`:18`), postmortem actions (`:17`).
   - `building-microservices-newman.md:12` (testing in production).
2. **Gaps and errors:** W3B-42 to 49. No result artifact fields beyond a pointer; no corrective-action step although `disaster-recovery-plan` requires one (Python mirror has a section for it). `toxiproxy.go` setup, `startStack`, `requireSteadyState` never shown. Steady state "60 s pre-fault window" cannot be met by an in-process test as written. Chaos Mesh versus Litmus choice rests on no source. Installing Chaos Mesh needs privileged daemon access [GK], not mentioned as a security trade-off.
3. **Folder moves:** manifests, abort rule and header block to `templates/`; watcher to `scripts/`; experiments to `examples/`; safety checklist to `resources/`.
4. **Example ideas:** (a) lean: do not run; answer with a single dependency-timeout integration test; (b) standard: toxiproxy breaker experiment driving open, half-open, closed, plus duplicate delivery; (c) enterprise: broker loss in an ephemeral cluster, then canary scope with automatic abort and tenant-isolation check.
5. **Eval ideas:** (a) "Kill pods in prod to see what happens". (b) First run targeted at a real tenant. (c) One-request breaker test claimed as proof. (d) Experiment header with no numeric abort. (e) Lean product asks for a chaos suite. (f) Toxic left in place on failure.
6. **Overlaps:** `disaster-recovery-plan`, `go-concurrency-patterns` runbook, `go-load-test`, `canary-deployment`.
7. **Size:** L.

## Contradictions needing a product-owner decision

| ID | Question | Options | Recommendation |
|---|---|---|---|
| B-1 | What satisfies the TDD gate for Humble Object files and test-support code (extends batch A D-9) | (a) hook accepts any sibling `<name>*_test.go` and exempts `internal/test/**`, `tests/**`; (b) require `<name>_test.go` always | (a), with a hook test. (b) forces empty unit tests that these skills call wrong |
| B-2 | How slow suites are kept out of `make ci` | (a) build tags `e2e`, `chaos`, `pact`; integration stays in `make ci` with per-test `t.Skip` under `-short`; (b) `-short` everywhere | (a). Smoke becomes its own directory or name prefix |
| B-3 | e2e environment per profile | (a) `kind` for every profile; (b) lean runs the built binary or image with real dependencies locally, standard and enterprise use `kind`; (c) compose allowed at lean only | (b), with the parity limit stated. Python allows compose only for authoring |
| B-4 | Performance gate method and applicability | (a) committed baseline (today, shared with Python); (b) base and head benchmarked in the same CI job; (c) both, committed file as trend only | (b); no gate at lean unless an NFR asks |
| B-5 | Chaos cadence | (a) `phase-requirements` governs (none at lean, optional at standard) and `disaster-recovery-plan` scopes weekly runs to enterprise; (b) weekly everywhere | (a) |
| B-6 | Home for API behaviour checks (idempotency, 429, deprecation, error branches) | (a) section in `go-integration-test` against the real router; (b) section in `go-contract-test`; (c) new `api-behavior-test` skill | (a): these are the service's own behaviour against real dependencies; carry the risk rating in `test-pyramid` |
| B-7 | Default mutation threshold | (a) keep 60% as a starting floor over the tool's own figure; (b) no number: baseline on first run, then ratchet | (b) with 60% offered as a suggested target. Differs from batch A D-4 only in not calling it proven; ownership by `go-mutation-test` is agreed |
| B-8 | Chaos tooling parity | Go uses Chaos Mesh; Python deliberately does not (`python-chaos-test/SKILL.md`, Fault Mechanisms) | Same rule for both: toxiproxy and containers by default, cluster faults at enterprise only, language-independent |
| B-9 | Ownership of Python test skills | Go test skills are owned and preloaded by `test-strategist`; Python ones by `backend-engineer` | One rule: `test-strategist` owns the standard, `backend-engineer` applies unit and integration (matches `agents/backend-engineer.md` test boundary) |

Batch A: I agree with D-1 (rollback default), D-2 (one retry at e2e only), D-5, D-9 and D-11. D-1 needs W3B-25 to 28 fixed or the default cannot be followed. D-3 should also say the 80% floor must not force unit tests onto quadrant 3. "Existing research is enough" does not hold for this batch (below).

## Missing books

| Book or source | Why it came up | Needed? |
|---|---|---|
| Rosenthal and Jones, *Chaos Engineering* | The repo's own research names it as the missing methodology source (`devops-handbook...md:56`) | Useful, not blocking. The four-part experiment shape is sound; mark chaos method as ungrounded until then |
| A load and performance testing method text, or the k6 documentation | No research covers workload models, coordinated omission or k6 behaviour; most load defects are here | Official k6 docs at build time are required; a book is optional |
| Gremlins, Pact (`pact-go` v2, Broker), Chaos Mesh, Testcontainers-go, `benchstat`, `kind` official docs | Every [GK] tool finding | Required to verify at build time; not books |
| *SRE Workbook* (2018) | Alerting arithmetic only | Not needed for this batch |
| Mutation-testing text | Mechanics thin in all sources | Not needed; docs suffice |

## Shared structure with Python mirrors

The Python skills copy the Go shape almost section for section (staging, SLO numbers, 12% threshold, 60% score, one retry, four-part chaos header, schema-first contracts). So each defect in a shared *method* very likely exists twice; batch C should check W3B-2, 8, 12, 15, 23, 27, 43, 49 and 50 against them.

- **Share research once per pair:** unit (Khorikov, Jorgensen), contract (Cruz and Prescott), load (SRE, Continuous Delivery), chaos (concurrency research applies to Go only), e2e (Winteringham, Crispin).
- **Share language-neutral content, one home each.** A skill cannot point into another skill's folder, so name one owning skill per method and let the other load it by skill name, or add a neutral owner. Candidates: k6 scenarios, SLO gate, async PromQL and report template (`python-load-test` allows k6 already); journey selection, `kind` provisioning script, teardown, quarantine and retry script, e2e workflow (Playwright-free API surface only differs); contract tier decision, can-i-deploy and pending rules, event compatibility; chaos experiment header, safety rails, abort watcher; mutation triage method; isolation strategy table.
- **Language-only content:** test code, runner flags, tool configs, parallelism cost (goroutines against `pytest-xdist` workers), significance testing (Python's gate has none), allocation tracking, Python's savepoint behaviour.
- **Folder shape for every pair:** `SKILL.md` (profile table, numbered procedure, Gotchas), `references/` (one lookup per file), `templates/` (code, config, workflow, report), `examples/01-lean`, `02-standard`, `03-enterprise`, `resources/checklist.md`, `scripts/` only where deterministic.
- **Eval design:** one trap list per pair, same scenario with the language swapped; freeze Go and Python suites from one author brief. Traps that need a real toolchain should be graded on the reasoning (additive tags, vacuous assertion, gauge misuse).
- **Order:** unit and integration first (others cite them), then contract, e2e, load with chaos, then performance with mutation. Decisions B-1, B-2 and batch A D-1, D-2, D-5 precede all of them.

## What I could not verify

- No Go toolchain or tool was run. Compile claims rest on reading the snippets against each other; those marked [GK] about build tags, k6, Gremlins, Pact, Chaos Mesh, pgxpool, `benchstat` and GitHub Actions need checking.
- Read in full: all eight skills' files and contract tests; `skill-authoring-standards/SKILL.md`; batch A; research files Khorikov, Cruz and Prescott, Jorgensen, Winteringham, Crispin and Gregory, Quigley, 100 Go Mistakes, Donovan and Kernighan, Cox-Buday, Edwards, Campbell, Newman, Continuous Delivery, Accelerate, SRE. Edwards and Campbell (middleware, server, layout) bear little on testing.
- Not read in full: `explore-it`, `specification-by-example`, `python-testing-with-pytest` and the UAT research (searched by pattern; their subject is outside these eight, and batch A or C covers them); devops-handbook, Bass, Richards and Ford, node and python backend research (matching lines only). The three excluded requirements books were not opened or cited.
- `wave-2-findings.md` was read only for its header, narrative opening and section list, for format.
- Neighbouring skills, agents, `phase-requirements.json` and Python mirrors were read only at the passages cited; `test-strategist.md` mostly, `backend-engineer.md` around the test boundary.
- No evals, contract tests, model calls, git or gh commands were run.
