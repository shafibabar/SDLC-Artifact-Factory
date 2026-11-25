# Wave 3 Findings: Testing Skills (issue #1451)

- **Scope:** 24 skills. Methodology (6): acceptance-criteria, bdd-feature-file, example-mapping, test-pyramid, test-fixture-design, mock-generation. Go (8) and Python (8): unit, integration, contract, e2e, mutation, load, performance, chaos. React (2): react-component-testing, react-e2e-testing.
- **Inputs:** the four batch audits in `discovery/fresh-eyes/wave-3/` (about 200 findings: W3A-1 to 52, W3B-1 to 58, W3C-1 to 50, W3D-1 to 42). Read those for line-level evidence; this file merges them, checks the claims that matter and puts the decisions in one list.
- **Evidence marks:** "verified" means re-checked in this synthesis by reading the cited file or running it. **[GK]** means general knowledge, not text in this repository or a run.
- **Discovery only.** No skill, agent, hook or script was changed. No evals, git or gh commands, or installs.
- **State of all 24 (verified):** no declared research sources, no "Gotchas" section, no "Use when" wording in the description, no eval suite.

---

## Narrative: what I found

**1. The plugin's own safety check blocks the code these skills tell agents to write.** The "test first" hook (`scripts/tdd-gate.sh`) refuses any Go or TypeScript file that has no test file with exactly the matching name. I ran it: it refused shared test helpers, fake and mock files, end-to-end and chaos support files, front-end test setup files, tool configuration files, and application entry files. It also refused a component whose test sits in a `__tests__` folder or is named `.a11y.test.tsx`, and a Go repository that has only an integration test. Agents are told never to write files any other way, so they have no sanctioned route. In the other direction, the hook ignores Python completely.

**2. Several quality gates give the wrong answer, including false passes.** A false pass is worse than no gate, because the product owner is told something was proven.

| Gate | What happens as written |
|---|---|
| Acceptance-criteria checker | Passes a file with empty sections, an empty example block and open questions (ran) |
| Feature-file checker | Passes the blank template; rejects "wants to get a refund" as technical language; rejects standard `@` tags (ran) |
| Python load test | Counts "too many requests" refusals as success, so a system serving a fraction of the load can pass |
| Go load test | One test user hits the per-user rate limit, so the soak run is bound to fail [GK for how the tool counts refusals] |
| Go and Python "message delivered twice" tests | Pass without waiting for the second delivery |
| Python tenant-isolation test | Tests its own database query, never the product's code |
| Python performance gate | Always errors: the saved baseline is never found (ran) |
| Python mutation gate | Scores 0% on the skill's own "82% PASS" sample; the committed configuration crashes the current tool (crash ran) |
| Python contract job | Selects zero tests and fails (ran) |
| Go performance gate | The script that decides pass or fail does not exist |
| React cross-screen journey | Can pass on data left over from an earlier run |

**3. Following some instructions would cause damage.** In both end-to-end skills the setup script deletes the test cluster before the tests run. The Go "smoke" command, meant to be a harmless check against live environments, also runs the journeys that create and delete data ([GK] Go build tags only add files). The only Python smoke example changes data and is labelled non-destructive. The Python database test fixture overrides the throwaway database address with whatever `DATABASE_URL` points at, which could migrate a developer's real database.

**4. Much of the example code was never run.** Go and Python examples call methods that do not exist, use wrong constructor shapes, or do not compile. The Python test examples were not written against the Python code skills they are meant to test: names differ for the domain object, the repository, the database table for processed messages, and the migration setup. Those neighbouring skills also disagree with each other.

**5. The same rule is stated differently in different places.** Flaky tests (three policies), mutation score (60% monthly against 70% nightly), coverage (branch gate claimed, line gate enforced, while the configuration reference says there is no fixed percentage), database test isolation (default stated backwards in one skill), test-double tool (two defaults), where browser tests run (three answers), and what the test-first hook checks (agents and skills say timestamps; it checks only that the file exists).

**6. Small products are asked for the same testing as large ones.** The phase plan says small ("lean") products get no chaos or mutation runs. No testing skill knows this. A lean product also cannot finish Ideate cleanly: acceptance criteria are required, and the skill demands an example map that the plan marks optional.

**7. The testing work is invisible to approvals.** The Implement phase registers no artifact at all, so the test strategy and feature files are never approved. Test reports are written outside `artifacts/`, so no hook validates them.

**8. Parts of the chain have no owner or reader.** No agent loads any of the eight Python test skills. The frontend agent says another agent writes the React test standards; the skills say the frontend agent owns them. The frontend agent relies on a "remote screen fails to load" journey that the browser-test skill does not contain.

**9. The first product leaks into the rules.** Data-classification vocabulary and a one-database-per-customer model appear as rules. The Go performance skill quotes the multi-tenancy skill as setting that model; that skill says there is no default (verified).

---

## Verification of consequential claims

Verdicts: **V** verified; **P** the repository text is as claimed but the tool behaviour it rests on was not run; **R** refuted or partly refuted; **U** not verified here (carried from the batch).

| # | Claim (batch IDs) | Verdict | How |
|---|---|---|---|
| 1 | Hook denies Go test-support files (W3A-1, W3B-52) | V | ran hook |
| 2 | Hook denies integration-only repository file (W3B-52) | V | ran hook |
| 3 | Hook denies TS setup, config, entry, `__tests__`, `.a11y.test` cases (W3D-30) | V | ran hook |
| 4 | Hook allows untested Python (W3C-2) | V | ran hook |
| 5 | Skills and agents say the hook compares file age; it checks existence (W3A-12, W3B-32, W3D-31) | V | read |
| 6 | Lean requires criteria but not the example map they depend on (W3A-2) | V | read plan, skill, agent |
| 7 | `EM-` reference does not exist; real map path fails the checker (W3A-3) | V | ran |
| 8 | Template `AC-001` incompatible with the UAT checker's `AC-US-n` (W3A-4) | V | read both |
| 9 | Scaffold script usage wrong and file name differs from agent's (W3A-5, 6) | V | ran |
| 10 | Criteria checker false pass; "as well" false fail (W3A-7) | V | ran |
| 11 | Feature checker passes template, false HTTP hit, rejects tags (W3A-8) | V | ran |
| 12 | Two mutation thresholds and cadences (W3A-9) | V | read |
| 13 | Two flaky policies (W3A-10, W3D-11) | V | read |
| 14 | Branch gate claimed, line gate enforced (W3A-11) | V | read |
| 15 | Isolation default stated backwards (W3A-21) | V | read |
| 16 | mockery default against moq elsewhere; freshness pattern matches nothing (W3A-28, 29) | V | read |
| 17 | The "mockery" examples show moq's output shape (W3A-28) | U | [GK] |
| 18 | "Archived" test object is not archived (W3A-23) | V | read |
| 19 | No research backs the 70/20/10 ratio (W3A-15) | V | searched `research/testing` |
| 20 | Implement phase registers no artifact (W3A-19) | V | read |
| 21 | End-to-end setup deletes the cluster before tests, Go and Python (W3B-1, W3C-24) | V | read scripts and workflows |
| 22 | Go smoke tag also runs destructive journeys (W3B-2) | P | Go tag behaviour [GK] |
| 23 | Go load: one subject against a 10/s limiter (W3B-8) | P | tool counting of 429 [GK] |
| 24 | Go "ramp" declared both open and closed (W3B-9) | V | read |
| 25 | Counter query applied to a gauge (W3B-11) | V | read |
| 26 | Go performance gate script missing (W3B-14) | V | searched |
| 27 | Performance skill cites a tenancy model the cited skill does not hold (W3B-18) | V | read |
| 28 | Mutation exclusion methods contradict (W3B-20); tool keys doubtful | P | keys [GK] |
| 29 | Pre-release runs trigger after publication (W3B-23) | V | read |
| 30 | Wrong configuration key in e2e override (W3B-24) | V | read schema |
| 31 | Go repository constructor misused; `TestMain` cannot compile (W3B-25, 26) | V | read |
| 32 | Go redelivery test asserts without waiting (W3B-27) | V | read (consumer is only a comment) |
| 33 | `-short` exits the whole package (W3B-29) | V | read |
| 34 | Fuzz example calls a method that does not exist (W3B-31) | V | searched |
| 35 | No record-deployment or pending-contract step (W3B-37) | V | searched |
| 36 | Chaos templates target a tenant namespace against the safety rail (W3B-43) | V | read |
| 37 | Breaker test makes one call, reads no breaker state (W3B-45) | V | read |
| 38 | Connection-pool timeout setting does not exist (W3B-45) | U | [GK] |
| 39 | Chaos Mesh scheduler field removed (W3B-42) | U | [GK] |
| 40 | Slow suites have no build tag, so `make ci` would run them (W3B-51) | V | read |
| 41 | Python un-awaited async test fails, not "silently passes" (W3C-1) | V | ran |
| 42 | Coverage floor fails every partial test run (W3C-3) | V | ran |
| 43 | Contract marker selects nothing, exit 5 (W3C-18) | V | ran and read |
| 44 | Performance baseline never found, exit 4 (W3C-37) | V | ran |
| 45 | mutmut 3.8.1 crashes on the committed configuration (W3C-39) | V | ran |
| 46 | Mutation gate arithmetic gives 0% on the sample (W3C-40) | V | read and counted |
| 47 | Python load counts 429 as success on the gated route (W3C-29) | V | read limiter, script, gate |
| 48 | Tool reports no 99.5 percentile; p99 gates a 99.5% goal (W3C-30) | V | ran |
| 49 | "Open model" recipe is closed (W3C-31) | V | read tool source |
| 50 | Migration fixture URL ignored for `DATABASE_URL` (W3C-11) | V | read both |
| 51 | Python redelivery and tenant tests prove nothing (W3C-15, 16) | V | read |
| 52 | Compatibility checker's logic is wrong (W3C-20) | V | read, not executed |
| 53 | "Equivalent mutant" example is observably different (W3C-41) | V | read |
| 54 | Python test code does not match the code skills (narrative 4, basis of C-9) | V | searched all owners |
| 55 | Schema reference and fixture errors (W3C-17, 19); event-loop mismatch (W3C-12) | U | not re-run |
| 56 | React e2e describes a compose stack the owner forbids; only three backend charts installed (W3D-1, 2) | V | read |
| 57 | React journey can pass on leftover state; config lacks retries, setup, sign-in (W3D-4, 7) | V | read |
| 58 | Saved browser state cannot hold an in-memory token (W3D-8) | V | read both rules |
| 59 | Quarantine offers `test.skip` (W3D-10) | V | read |
| 60 | "A search finds nothing on remote failure, seeding, teardown, smoke, Gherkin" (W3D-12) | R | "smoke" and "seeding" are mentioned in passing. The core holds: no remote-failure journey, no seeding or teardown standard, no smoke rules, no Gherkin |
| 61 | Shell-to-remote contract test required but unowned (W3D-13) | V | read |
| 62 | Wrong pagination shape in mocked responses (W3D-24) | V | read |
| 63 | jsdom cannot check contrast; disabled click does not throw (W3D-20, 21) | P | text verified; [GK] |
| 64 | Micro-frontends are a recorded decision the testing skills assume (R-4) | V | read D023 and research |

**Totals (64 claims): 55 verified, 4 partly (text only), 1 partly refuted, 4 unverified.** Rows 5, 21, 31, 51, 56 and 57 bundle closely related claims. Python runs used the throwaway environment batch C left in the session scratch folder (pytest 9.2.0, mutmut 3.8.1, locust 2.47.0); nothing was installed.

**Added by this synthesis**
- **S-1:** `sdlc-config-management/references/config-field-reference.md` says the coverage minimum has "no fixed factory-wide percentage", against the 80% gate elsewhere. A third coverage answer.
- **S-2:** Batch D recommends the frontend agent own the React standards, while B-9 and C-5 give standards to `test-strategist`. Resolved in W3-D16.
- **S-3:** A D-4 keeps a 60% mutation floor; B-7 says baseline first. Resolved in W3-D19.
- **S-4:** Nobody owns the contract test for the React app as a consumer of the HTTP API (the research places this discipline with the contract skill, `contract-testing-in-action-cruz-prescott.md`, "Applies To"). Handled in W3-D22. Shell-to-remote contracts are a different thing (W3-D16).
- **S-5:** `research/micro-frontends/building-micro-frontends-mezzalira.md` says module boundaries inside one app are "sufficient" without multiple teams, which supports W3-D3 option (b).
- **S-6:** Eval spend in Wave 2 was about double the plan (see Cost).

---

## Findings table (merged themes)

| ID | Theme | Batch findings | Impact |
|---|---|---|---|
| T1 | Test-first hook blocks support files and ignores Python | W3A-1, W3B-6/52, W3C-2, W3D-30 | H |
| T2 | Gates that false-pass, always fail, or do not exist | W3A-7/8, W3B-8/10/11/14/27/45, W3C-15/16/18/29/30/37/40/44, W3D-4/23 | H |
| T3 | Instructions that destroy or hit real environments | W3B-1/2/43/44, W3C-11/24/26, W3D-16 | H |
| T4 | Example code that cannot run | W3B-25/26/31/36/46, W3C-7/14/17/19/42, W3D-5/6/27 | H |
| T5 | Third-party tool behaviour wrong or unverified | W3A-28, W3B-16/20/22/37/42, W3C-1/31/32/39, W3D-20 to 22 | H |
| T6 | Same rule, different answers | W3A-9 to 12/21/29/45, W3B-9/33/41/49, W3C-5/6/20, W3D-10/11/15 | H |
| T7 | No lean / standard / enterprise scaling | W3A-13, W3B-50, W3D-7, all batch narratives | H |
| T8 | Test artifacts unregistered; lean Ideate chain broken | W3A-2 to 5/19/41/43, W3B-53, W3C-48, W3D-14/41 | H |
| T9 | Ownership and loading gaps | W3A-35, W3B-56, W3C-47, W3D-36 | H |
| T10 | First-product and tenancy leakage; invented numbers | W3A-14/22/36, W3B-18/19/54, W3C-46, W3D-39 | H |
| T11 | Research not used: case derivation, risk rating, quadrants, API behaviour checks | W3A-16/17, W3B-35/40, W3C-10/45, W3D-33 to 35 | M |
| T12 | Folder spec, descriptions, contract tests, resident noise | W3A-20/27/52, W3B-55/58, W3C-49/50, W3D-38/40/42 | M |

---

## Live bugs in shipped plugin mechanics

These affect the plugin as installed today, separate from the advice inside skills.

| ID | Bug | Where | Verified | Fix before the rebuilds? |
|---|---|---|---|---|
| L1 | Hook refuses legitimate test-support, configuration and entry files, and common test layouts | `scripts/tdd-gate.sh` | ran | **Yes** (after W3-D1). Rebuilt skills cannot produce their own outputs otherwise |
| L2 | Hook does not cover Python | same | ran | **Yes**, same change |
| L3 | Lean product cannot satisfy acceptance criteria without an optional artifact | `skills/artifact-manifest/resources/phase-requirements.json`, `agents/requirements-analyst.md` | read | **Yes** (after W3-D4) |
| L4 | Test strategy and feature files have no manifest entry, so cannot be approved | same plan file (`implement: []`) | read | **Yes** (after W3-D5) |
| L5 | Criteria template IDs rejected by the downstream UAT checker | `acceptance-criteria` template against `uat-scenario/scripts/check-uat-scenarios.py` | read | **Yes**. It breaks the pipeline between two shipped parts; the checker is right |
| L6 | Criteria checker passes empty files and rejects real map paths | `acceptance-criteria/scripts/validate-criteria.sh` | ran | With that skill's rebuild; fix tests first |
| L7 | Scaffold script writes a file name the agent and backlog do not expect; documented usage fails | `acceptance-criteria/scripts/scaffold-criteria.sh` | ran | With that rebuild |
| L8 | Feature checker passes the blank template, false-fails business wording and tagged files | `bdd-feature-file/scripts/validate-bdd-feature-file.sh` | ran | With that rebuild |
| L9 | Agents and the project standards describe a timestamp check the hook does not do | `agents/test-strategist.md`, `backend-engineer.md`, `frontend-engineer.md`; CLAUDE.md Phase Gate Rules | read | With L1 (change the words, not the behaviour) |
| L10 | `e2e_test_cadence` and the performance threshold override are claimed as configuration keys but not documented; one example uses the wrong parent key | `sdlc-config-management` and e2e/performance skills | read; schema rejection not tested | With the pipeline sub-issue |

Not counted as bugs: the structure validator fails `go-performance-test` (2) and `go-chaos-test` (1) for pointing at other skills' files. The message ("does not exist") is misleading, but the pointers should be removed in the rebuild. The layout linter and validator pass skills whose code cannot run; that is outside what they check.

---

## Decisions

Numbered by how much they block within each list. "Source" shows the batch questions each one replaces (38 batch questions, now 31 including two new ones).

### A. Needs the product owner (scope, cost, policy, product behaviour)

| ID | Question in plain language | Options | Recommendation | Source | Skills affected |
|---|---|---|---|---|---|
| **W3-D1** | Which files may the plugin write before a test exists, and does "test first" apply to Python? | (a) accept any matching test (same-name variants, `__tests__`, mirrored Python paths); exempt named test-support folders, configuration, type declarations, entry and index files, `conftest.py`, `__init__.py`, migrations; add Python. (b) exempt test support only; leave Python ungated and say so. (c) keep as is | **(a)**, with hook tests. Keep it an existence check and correct the "timestamp" wording. Note: adding Python is a new block users will notice; the entry-file exemption must not become a hiding place for logic | A D-9, B-1, C-1, R-2 | fixtures, mocks, bdd, Go unit/integration/contract/e2e/chaos, all Python, both React |
| **W3-D2** | How much testing does each product size get? | (a) the phase plan governs: lean runs journeys against the locally built app, load and speed checks only for stated targets, no chaos or mutation; standard adds an ephemeral cluster nightly, chaos optional; weekly chaos only at enterprise. (b) every tier at every size | **(a)**. It changes the disaster-recovery skill's weekly-chaos rule | B-3, B-4, B-5, R-1 | pyramid, all e2e, load, performance, chaos, mutation, disaster-recovery-plan |
| **W3-D3** | Does a small product get several independently deployed screen modules (micro-frontends)? | (a) yes at every size (current record, 2026-07-22). (b) lean builds one app with module-shaped folders; testing skills carry a single-app variant | **(b)**. The research gates the pattern on several teams. This reopens a recorded decision, so only the product owner can change it | R-4 | react-e2e, react-component, microfrontend-architecture, frontend agent |
| **W3-D4** | How does a lean product write acceptance criteria without a separate example map? | (a) a short map inside the criteria file (rules, one example each, open questions). (b) make example maps required. (c) derive from the story's one example | **(a)** | A D-6 | acceptance-criteria, example-mapping, requirements agent |
| **W3-D5** | Should the product owner approve the test strategy, feature files and test reports? | (a) register strategy and feature files in Implement (short at lean; scenarios for every criterion of every Must Have story) and one test-report family in Quality. (b) leave unregistered | **(a)**. Adds approval steps | A D-10, W3B-53, W3C-48, W3D-41 | pyramid, bdd, every suite that writes a report |
| **W3-D6** | What is the coverage rule? | (a) one 80% line/statement floor for the whole repository, called what it is, generated code excluded, not forced on thin wiring code, adjustable per product. (b) 80% branch coverage with an added tool. (c) no percentage gate | **(a)**, backed by mutation testing. Fix the configuration reference (S-1) and the Python setting that fails partial runs | A D-3, S-1, W3C-3 | pyramid, Go/Python unit and mutation, react-component, both makefile skills |
| **W3-D7** | May the wave also repair the five Python build skills that the Python tests are written against? | (a) yes first: domain model, repository, service layer, event consumer, migration. (b) rebuild tests against today's text | **(a)**. Otherwise the test examples cannot run. Adds about five non-testing skills of scope | C-9 | 8 Python tests |
| **W3-D8** | May the rebuild install and run the real toolchains to prove examples work? | (a) yes, in a throwaway environment; anything not run is labelled unverified. (b) read-through only | **(a)**. Most serious defects here would have been caught by running the code. No Go, Docker, cluster or load tool is on this machine. The campaign record mentions a Go compile check decided 2026-10-12; I did not find its wording, so confirm it | new | the 21 code-bearing skills |
| **W3-D9** | What eval spending ceiling for this wave? | (a) $450 with a check-in after the first four skills. (b) hold to $7 per skill total. (c) no ceiling | **(a)**. See Cost | new, S-6 | all 24 |

### B. Engineering defaults we will take unless objected to

| ID | Question | Default taken (alternative) | Source | Skills affected |
|---|---|---|---|---|
| **W3-D10** | How are slow suites kept out of the fast check? | Go build tags, Python markers; integration stays in. Browser tests are not inside `npm run ci`: quick mocked journeys as a separate pull-request job, full suite nightly and pre-release. Live-environment smoke is read-only, separately selected, and destructive tests refuse a non-throwaway address. (Alt: path or `-short` selection only) | B-2, C-3, R-3 | Go/Python e2e, chaos, contract, performance; React; makefiles; ci-pipeline; frontend agent |
| **W3-D11** | One flaky-test policy | One retry for end-to-end only, none lower; tagged, non-blocking quarantine with a deadline; deletion allowed only with a record. Stated once in `test-pyramid`. (Alt: never retry, never delete) | A D-2 | pyramid, all e2e |
| **W3-D12** | Default database test isolation | Roll back each test; scoped data only when a real commit is needed. (Alt: per-tenant everywhere) | A D-1 | fixtures, Go/Python integration |
| **W3-D13** | Go test-double generator | moq; coverage filter matches its file names. (Alt: mockery) | A D-5 | mocks, go-makefile, go-unit |
| **W3-D14** | Who owns the end-to-end environment? | `go-e2e-test`'s one script provisions every app and dependency the plan names (including the web shell), runs tests, then tears down; other skills point to it. (Alt: separate front-end stack) | B-3, R-1 | e2e x3, ci-pipeline, cd-pipeline |
| **W3-D15** | One Python layout and test configuration | `python-project-structure` layout; one configuration template owned by `python-makefile`; coverage flags on the make target. (Alt: each skill its own) | C-2 | 8 Python tests |
| **W3-D16** | Who owns and loads test skills? | `test-strategist` owns cross-stack policy and the Go and Python standards; `backend-engineer` applies unit and integration; Python loaded only on a Python stack; stop preloading all suites. React skills stay with `frontend-engineer`, and shell-to-remote contract tests become a reference in `react-component-testing`. (Alt: strategist owns React too; a new contract skill) | B-9, C-5, R-6, S-2 | agents, all Python, React |
| **W3-D17** | How do language mirrors share content? | One named owner per language-neutral method (journey selection, quarantine, experiment safety, load gate, mutation triage); others load it by name and hold code only. A skill cannot point into another's folder. (Alt: full mirrors) | C-8, batch B | Go/Python pairs, React e2e |
| **W3-D18** | Python load tool | k6 only, scenarios shared with Go. This changes what Python products receive. (Alt: keep locust) | C-4 | python-load, go-load |
| **W3-D19** | Mutation threshold and timing | `go-mutation-test` owns it: measure a baseline, then ratchet; 60% a suggested target; monthly and before (not after) release. (Alt: fixed 60% or 70% nightly) | A D-4, B-7, S-3 | pyramid, both mutation |
| **W3-D20** | mutmut version | Pin 3.x; rebuild configuration and gate from its documentation. (Alt: pin 2.x) | C-7 | python-mutation |
| **W3-D21** | Speed-regression method | Compare old and new code in the same job; any saved baseline is trend only. (Alt: saved baseline) | B-4 | both performance |
| **W3-D22** | How are contracts checked? | HTTP: standard spec-diff tool (`oasdiff` in Python, equivalent in Go) plus conformance; events: the mode set by the event design, replacing hand-written checkers; web app uses types generated from the same spec for its mocks; Pact only on the escalation trigger. (Alt: keep checkers) | C-6, S-4 | both contract, react-component, react-e2e |
| **W3-D23** | Where do API behaviour checks live (repeat-request safety, rate limit, deprecation, errors)? | In each language's integration test skill; risk rating in `test-pyramid`. (Alt: contract skill, or new skill) | B-6 | integration x2, pyramid |
| **W3-D24** | Criterion naming | `AC-US-n.m`; file `US-n.md`; example map referenced by story or path | A D-7 | acceptance-criteria, example-mapping, bdd, React |
| **W3-D25** | Pyramid percentages | Drop 70/20/10; keep the shape and "lowest layer that proves it" | A D-8 | pyramid |
| **W3-D26** | Edge-case scenario | Required, with a recorded "no meaningful edge" escape at lean | A D-11 | acceptance-criteria, bdd |
| **W3-D27** | How do criteria reach browser tests? | Plain browser tests tagged with criterion IDs plus a coverage check; Must Have journeys. (Alt: Gherkin binding library) | R-8 | react-e2e, bdd |
| **W3-D28** | What may front-end component tests fake? | Only outside edges (network, clock, telemetry, missing browser features), never the app's own modules | R-5 | react-component, react-observability |
| **W3-D29** | How do browser tests sign in? | One real sign-in; saved refresh cookie; no test hook in production code | R-7 | react-e2e |
| **W3-D30** | Screenshot comparison | Off by default; named pages only at standard or enterprise, mocked data, pinned image. Drop the PDF justification | R-9 | react-e2e |
| **W3-D31** | Chaos tooling | Same rule in both languages: network-fault proxy and containers by default; cluster faults at enterprise only | B-8 | both chaos |

---

## Missing books and official documentation

**No new book blocks any rebuild.**

| Source | Need | Verdict |
|---|---|---|
| Rosenthal and Jones, *Chaos Engineering* | The repository's own research names it as the missing method source | Useful, optional. Without it, mark chaos method as ungrounded |
| A load-testing method text | No research on workload models | Optional; k6 documentation required |
| Meszaros *xUnit Test Patterns*; Freeman and Pryce; a Gherkin or Example Mapping source; a mutation or front-end testing text; *SRE Workbook* | Attribution or syntax only | Not needed. Drop or reword attributions |

**Official documentation needed, as research sub-issues** (a cited framework must trace to a research file, `skill-authoring-standards`, "Grounding"):

1. **Go test tools:** Go build tags and fuzzing, `benchstat`, godog and Gherkin syntax, moq, Testcontainers-go, Gremlins, pact-go v2 and the Pact Broker, Chaos Mesh, kind.
2. **Python test tools:** pytest-asyncio, pytest-benchmark, coverage, testcontainers-python, mutmut 3, jsonschema, oasdiff, Hypothesis.
3. **Front-end test tools:** Testing Library, user-event, MSW, Vitest, jest-axe and axe-core, Playwright, WCAG 2.1 and the ARIA authoring practices.
4. **Shared tools:** k6, Toxiproxy, GitHub Actions trigger and required-check behaviour.

The two Python research files and the two front-end files say they carry limited certainty on book detail; cite them for patterns, never tool behaviour (the false "silent pass" claim shows why).

---

## Per-skill sections

Paths are under `research/`. "Key gaps" reference the batch IDs. Size: S, M, L.

### acceptance-criteria (M)
- **Sources:** requirements-and-user-stories/lean-agile-atdd-pugh, user-stories-applied-cohn, it-requirements-lean-agile-hathaway, software-requirements-wiegers-beatty; testing/specification-by-example-adzic.
- **Gaps:** W3A-2 to 7, 42 to 46; L3, L5 to L7. Fit criteria and business rules never read in; no lean route.

### bdd-feature-file (L)
- **Sources:** testing/specification-by-example-adzic, agile-testing-crispin-gregory, software-testing-craftsman-jorgensen; requirements-and-user-stories/lean-agile-atdd-pugh.
- **Gaps:** W3A-1, 8, 36 to 41, 45; L8. First product's glossary stated as the rule; no criterion-to-scenario traceability; step layout contradicts the review command.

### example-mapping (M)
- **Sources:** requirements-and-user-stories/lean-agile-atdd-pugh, user-stories-applied-cohn; testing/specification-by-example-adzic, agile-testing-crispin-gregory.
- **Gaps:** W3A-3, 43, 46 to 49. No agent-run procedure for putting open questions to the user; time box meaningless; attribution to Wynne unbacked.

### test-pyramid (L)
- **Sources:** testing/unit-testing-khorikov, agile-testing-crispin-gregory, testing-vv-dictionary-quigley, software-testing-craftsman-jorgensen, testing-web-apis-winteringham, explore-it-hendrickson, contract-testing-in-action-cruz-prescott; software-architecture/building-microservices-newman.
- **Gaps:** W3A-9 to 20; W3D-11. Becomes the single owner of flaky, coverage, layers and size profiles; stop inventing performance numbers.

### test-fixture-design (L)
- **Sources:** testing/unit-testing-khorikov, python-testing-with-pytest-okken, testing-web-apis-winteringham; software-architecture/pragmatic-programmer-hunt-thomas; domain-driven-design/versioning-event-sourced-system-young.
- **Gaps:** W3A-1, 21 to 27. Wrong isolation default, broken reference code, single tenancy model, description too long [GK limit].

### mock-generation (M)
- **Sources:** testing/unit-testing-khorikov, software-testing-craftsman-jorgensen, python-testing-with-pytest-okken, contract-testing-in-action-cruz-prescott; software-architecture/architecture-patterns-with-python-percival-gregory.
- **Gaps:** W3A-28 to 35. Tool default and examples; nothing keeps fakes honest; backend agent does not load it.

### go-unit-test (M)
- **Sources:** testing/unit-testing-khorikov, software-testing-craftsman-jorgensen; software-architecture/100-go-mistakes-harsanyi, the-go-programming-language-donovan-kernighan.
- **Gaps:** W3B-31 to 35. No procedure and no way to derive test cases.

### go-integration-test (L)
- **Sources:** testing/unit-testing-khorikov, testing-web-apis-winteringham, software-testing-craftsman-jorgensen; software-architecture/concurrency-in-go-cox-buday; devops-and-delivery/continuous-delivery-humble-farley.
- **Gaps:** W3B-25 to 30, 40. Code must be made to compile; add behaviour checks (W3-D23).

### go-contract-test (L)
- **Sources:** testing/contract-testing-in-action-cruz-prescott, testing-web-apis-winteringham; software-architecture/building-microservices-newman.
- **Gaps:** W3B-36 to 41. Weak default check; Pact tier rebuilt from documentation; no procedure.

### go-e2e-test (L)
- **Sources:** testing/unit-testing-khorikov, agile-testing-crispin-gregory, testing-web-apis-winteringham, testing-vv-dictionary-quigley; devops-and-delivery/continuous-delivery-humble-farley; software-architecture/building-microservices-newman; devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.
- **Gaps:** W3B-1 to 7, 23, 24. Owns the shared environment (W3-D14); most urgent safety fixes.

### go-mutation-test (M)
- **Sources:** testing/unit-testing-khorikov, software-testing-craftsman-jorgensen, testing-vv-dictionary-quigley.
- **Gaps:** W3B-20 to 23. Mechanics depend entirely on tool documentation.

### go-load-test (L)
- **Sources:** devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy; devops-and-delivery/continuous-delivery-humble-farley; software-architecture/concurrency-in-go-cox-buday.
- **Gaps:** W3B-8 to 13, 19. Gate cannot give a true verdict; no route from stated targets to a profile.

### go-performance-test (M)
- **Sources:** software-architecture/100-go-mistakes-harsanyi, the-go-programming-language-donovan-kernighan, software-architecture-in-practice-bass, fundamentals-of-software-architecture-richards-ford; devops-and-delivery/continuous-delivery-humble-farley.
- **Gaps:** W3B-14 to 19. Write the missing gate script; remove the false tenancy citation and invented budgets.

### go-chaos-test (L)
- **Sources:** devops-and-delivery/devops-handbook-kim-humble-debois-willis; software-architecture/concurrency-in-go-cox-buday, building-microservices-newman; devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.
- **Gaps:** W3B-42 to 49. Experiments do not prove the pattern; unsafe default targets.

### python-unit-test (M)
- **Sources:** testing/python-testing-with-pytest-okken, unit-testing-khorikov, software-testing-craftsman-jorgensen; software-architecture/architecture-patterns-with-python-percival-gregory; software-architecture/python-backend-development-halstead.
- **Gaps:** W3C-1, 5 to 10. Central warning is false; examples call missing methods.

### python-integration-test (L)
- **Sources:** testing/python-testing-with-pytest-okken, unit-testing-khorikov, testing-web-apis-winteringham; software-architecture/architecture-patterns-with-python-percival-gregory, python-backend-development-halstead; continuous-delivery-humble-farley.
- **Gaps:** W3C-11 to 16, 46. Database safety fix first.

### python-contract-test (L)
- **Sources:** testing/contract-testing-in-action-cruz-prescott, testing-web-apis-winteringham, python-testing-with-pytest-okken; software-architecture/python-backend-development-halstead.
- **Gaps:** W3C-17 to 23. Wrong compatibility logic; CI runs nothing.

### python-e2e-test (L)
- **Sources:** testing/agile-testing-crispin-gregory, testing-web-apis-winteringham, unit-testing-khorikov; continuous-delivery-humble-farley; software-architecture/python-backend-development-halstead.
- **Gaps:** W3C-24 to 28.

### python-mutation-test (M)
- **Sources:** testing/unit-testing-khorikov, software-testing-craftsman-jorgensen, testing-vv-dictionary-quigley; software-architecture/python-backend-development-halstead.
- **Gaps:** W3C-3, 6, 39 to 41.

### python-load-test (L)
- **Sources:** devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy; continuous-delivery-humble-farley; software-architecture/python-backend-development-halstead (names k6).
- **Gaps:** W3C-29 to 35.

### python-performance-test (M)
- **Sources:** software-architecture/python-backend-development-halstead; continuous-delivery-humble-farley; software-architecture-in-practice-bass; fundamentals-of-software-architecture-richards-ford.
- **Gaps:** W3C-36 to 38.

### python-chaos-test (L)
- **Sources:** software-architecture/python-backend-development-halstead; devops-and-delivery/devops-handbook-kim-humble-debois-willis; devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy; building-microservices-newman.
- **Gaps:** W3C-35, 42 to 46. Needs a circuit breaker that no Python build skill provides.

### react-component-testing (L; batch D said M to L)
- **Sources:** frontend-engineering/react-design-patterns-roldan, learning-react-banks-porcello; testing/unit-testing-khorikov, agile-testing-crispin-gregory, specification-by-example-adzic.
- **Gaps:** W3D-20 to 31, 33, 34. Setup templates, "what this test environment cannot check", contrast claim (also in react-accessibility); receives shell contract tests.

### react-e2e-testing (L)
- **Sources:** micro-frontends/art-of-micro-frontends-rappl, building-micro-frontends-mezzalira, micro-frontends-in-action-geers; testing/testing-web-apis-winteringham, agile-testing-crispin-gregory, explore-it-hendrickson, unit-testing-khorikov, testing-vv-dictionary-quigley.
- **Gaps:** W3D-1 to 19, 32, 35, 37 to 40.

**Size totals:** L 15, M 9, S 0.

Every rebuild also gets: numbered procedure, size-profile table, Gotchas, folder spec, lean / standard / enterprise examples, "Use when" description (major version bump), separately authored frozen evals, retirement of the old one-line contract test. Batch sections hold example and eval ideas.

---

## Proposed implementation order

| Step | Work | Depends on |
|---|---|---|
| 0 | Product-owner answers to W3-D1 to D9 | this file |
| 1 | **Pipeline and mechanics sub-issue:** hook and its tests (L1, L2, L9); phase plan (L3, L4); criterion ID in the template (L5); configuration keys (L10); agent ownership and preload changes | D1, D4, D5, D16, D24 |
| 2 | Four **research notes** from official documentation (can run alongside step 3; each is needed before its language) | D8, D18, D20 |
| 3 | Methodology: test-pyramid (owns shared policy) → example-mapping → acceptance-criteria (L6, L7) → bdd-feature-file (L8) → test-fixture-design → mock-generation | steps 0, 1 |
| 4 | **Pilot checkpoint** after four skills: report actual cost and eval pass rate | D9 |
| 5 | Python build-skill repair (five skills) | D7; before step 6's Python halves |
| 6 | Pairs, Go first then its Python twin: unit → integration → contract → e2e → load → chaos → mutation → performance | steps 2, 3; D10, D14, D15, D17 |
| 7 | React: component → e2e | pyramid, go-e2e (environment), D3 |
| 8 | Close-out: agents, catalog, retired contract tests, cross-skill checks | all |

**Edits outside the 24 skills** (plan them into steps 1, 5 and the skill that triggers them): go-makefile, python-makefile, coverage-by-quadrant (inside go-unit-test), react-accessibility, react-observability, ci-pipeline, cd-pipeline, disaster-recovery-plan, methodology-review, microfrontend-architecture, sdlc-config-management, go-project-structure, five Python build skills, four agents.

**Sharing to cut cost across Go, Python and React**
- Read research once per pair (unit: Khorikov, Jorgensen; contract: Cruz and Prescott; load: SRE, Continuous Delivery; e2e: Winteringham, Crispin).
- Decide each method once in its owner skill (W3-D17): flaky and coverage policy, journey selection, environment script, quarantine, load gate and k6 scenarios, experiment safety rails and abort, mutation triage, isolation table.
- Reuse one lean / standard / enterprise example domain per pair, swapping only the code.
- One trap list and one eval-author brief per pair; two separate frozen suites.
- Language-only: test code, runner settings, tool configuration, significance testing and allocation tracking.
- React shares policy and environment, not code.

---

## Cost estimate for the rebuild round

**Observed (local eval result files, verified):**
- Wave 2: 25 skills, about **$363** in recorded eval cost, **$14.50 per skill on average**, about 3.8 recorded runs each (range 1 to 10; $3.81 to $37.86 per skill). The Wave 2 plan assumed about $175.
- All 48 skills with saved results: 151 runs, median $3.70 and maximum $7.03 per run; per skill median $7.47, mean $10.86.
- The brief's $4 to $7 per run matches; most skills needed more than one run.

**Estimate for 24 skills (evals only):**

| Case | Assumption | Cost |
|---|---|---|
| Low | About 2 runs per skill, $7.50 | about $180 |
| Expected | 9 M skills at $10, 15 L skills at $17 | about $345 |
| High | $20 per skill (harder code, tool traps, re-runs) | about $480 |

**Plan on $250 to $450**; ceiling in W3-D9. Assumptions: three cases, three repetitions, with and without the plugin; the $7 per-run cap unchanged; no baseline-beating failures that force a skill redesign. L skills here carry runnable code and tool traps, so the upper half is likelier than in Wave 2.

**Not included:** rewrite and eval-author subagent usage, research notes, the pipeline sub-issue, five Python build skills (about $50 to $75 more in evals if they are also rebuilt to the standard; a defect-only repair needs none), and any compute for real toolchains.

**Time and limits:** at about 20 minutes per run and 2 to 5 runs per skill, expect 16 to 40 hours of sequential eval time. The account has hit both 5-hour and weekly usage limits (a saved smoke-test log shows the weekly limit). Run one subagent at a time, checkpoint after each skill, and expect the wave to span several weekly windows. I cannot estimate how many.

---

## What could not be verified

- No Go, Node, Docker, Kubernetes, database, broker, k6, Playwright or CI run. All Go and front-end compile and tool-behaviour claims rest on reading, or are [GK]: build tags, k6 counting and executors, Gremlins keys, pact-go calls, Chaos Mesh fields, pgx pool settings, jsdom, user-event, MSW, Playwright, mockery and moq output, the 1024-character description limit.
- Python runs used current tool releases on Python 3.14; skills mostly give minimum versions only, so older releases may differ. W3C-12, 17, 19, the nested-event-loop half of W3C-11 and the Docker networking claims were not re-run.
- The many lower-ranked batch findings not in the verification table were not re-checked.
- Batch D read batches A to C and several research files only in part. I checked its overlaps (hook, flaky policy, environment, ownership, contracts) and the Cruz and Prescott and micro-frontend passages that decisions depend on; I did not reread Jackson and Herrington, Hambling, Adzic, Quigley or Jorgensen in full.
- Research source lists above are carried from the batches; I did not open every listed file.
- Eval costs come from result files kept on this machine (not committed), which may be incomplete; they exclude token use outside the runner.
- Whether the configuration schema rejects the wrong override key was not tested.
- The wording of the 2026-10-12 Go compile check decision was not found.
- Eval ideas in the batch files are untested.
