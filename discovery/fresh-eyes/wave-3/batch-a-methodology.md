# Wave 3 Discovery, Batch A: Methodology Testing Skills

- **Scope:** `acceptance-criteria`, `bdd-feature-file`, `example-mapping`, `test-pyramid`, `test-fixture-design`, `mock-generation` (issue #1451).
- **Read:** every file of the six skills and their contract tests; `CLAUDE.md`; `skill-authoring-standards` and its quality rubric; all of `research/testing/`; the Pugh, Cohn and Adzic research in full; targeted lines of Wiegers, Hathaway and other research files that name these skills or topics; the preloading agents; `phase-requirements.json`; the neighbouring skill passages cited below.
- **Executed (scratch directory only):** `validate-criteria.sh`, `scaffold-criteria.sh`, `validate-bdd-feature-file.sh`, `scaffold-bdd-feature-file.sh`, `scripts/tdd-gate.sh` with synthetic input, `lint-skill-layout.py` per skill.
- Claims marked **[GK]** rest on general knowledge, not on text in this repository.
- Research line numbers are line numbers inside the named research file.

## Narrative

1. **The test-support code these skills tell agents to write is blocked by the TDD hook.** `scripts/tdd-gate.sh` denies any Write or Edit of a `.go` file that has no sibling `_test.go` (suffix check only). Synthetic runs denied `internal/test/builders/order.go`, `internal/test/fakes/order_repo.go`, `internal/test/golden.go` and `internal/test/bdd/steps_order.go`. These are the declared output paths at `test-fixture-design/SKILL.md:230-232`, `mock-generation/SKILL.md:213` and `bdd-feature-file/SKILL.md:195`. Agents are told never to write through the shell (`agents/test-strategist.md:143`), so there is no sanctioned way to produce them.

2. **The Ideate chain is broken in three places.**
   - **Lean profile.** `example-maps` is optional at lean while `acceptance-criteria` is required (`phase-requirements.json:288-319`). The skill forbids criteria without a completed map (`acceptance-criteria/SKILL.md:118-119,180`), the validator fails without an `EM-` reference (`validate-criteria.sh:68-76`), and the agent's completion criteria demand both at every profile (`agents/requirements-analyst.md:344`).
   - **Map reference.** Criteria must cite `EM-[ID]` (`assets/acceptance-criteria-template.md:18`), but an example map has no `EM-` ID. It is keyed by `story-id: US-[ID]` (`example-mapping/SKILL.md:173,182`). Citing the real file path `ideate/example-maps/US-9.md` fails the validator (verified).
   - **Criterion IDs.** The template numbers criteria `AC-001` (`:22`). Downstream, the UAT checker requires `AC-US-<n>` and rejects anything else (`uat-scenario/scripts/check-uat-scenarios.py:122-124`).

3. **Both mechanical validators give wrong verdicts (verified by running them).**
   - `validate-criteria.sh` passes a freshly scaffolded file with every `[precondition]` placeholder still unfilled (only `EM-` filled), and passes a file with three empty angle sections, an empty gherkin block and "5 open question cards". The comment at `:49-51` claims content is checked under each heading; the loop at `:52-58` checks headings only.
   - `validate-bdd-feature-file.sh` passes the unfilled template. It fails a business-language feature containing "wants to get a refund" and "delete the post" (HTTP-verb regex `:56`). It fails a feature that uses Gherkin tags `@happy/@negative/@edge`, because it wants trailing `# happy` comments (`:44-50`). [GK] Gherkin comments must start their own line, so the convention at `bdd-feature-file/SKILL.md:94-96` puts the text into the scenario name.
   - Usage is documented as `scaffold-criteria.sh <story-id> <story-title>` (`SKILL.md:212`, `references/output-format-template.md:6`); the script requires `<product> <story-id> <story-title>` (`:20-23`). The documented call exits 1.

4. **`test-pyramid` contradicts the skills that own each mechanism.**

   | Topic | `test-pyramid` says | Owner says |
   |---|---|---|
   | Mutation threshold and cadence | at least 70%, nightly (`references/test-strategy-template.md:63,120-121`) | 60%, monthly and pre-release (`go-mutation-test/SKILL.md:74,80`) |
   | Flaky tests | no retries, `TestFlaky_` prefix, never deleted (`SKILL.md:127-130`; template `:127-136`) | one automatic retry, `quarantine` build tag, two-week deadline, deliberate deletion allowed (`go-e2e-test/references/flakiness-budget-and-quarantine-standard.md:9,21,44,63-68`) |
   | Coverage gate | at least 80% **Branch** Coverage, enforced by `make ci` (`SKILL.md:115`) | `make cover` enforces 80% **line** coverage with `go tool cover` (`go-makefile/SKILL.md:114`; `references/coverage-and-benchmark-standard.md:67`); a uniform percentage gate is rejected (`go-unit-test/references/coverage-by-quadrant.md`, "How to Use a Coverage Tool") |
   | TDD gate | blocks on modification timestamps, pre-commit (template `:59`; same claim `agents/test-strategist.md:94`) | `tdd-gate.sh` is a PreToolUse hook that only checks the test file exists |

   The contract test probes the "70" value (`tests/skills/test-pyramid.contract.sh`), so it locks in the contradiction. [GK] Go's coverage tool measures statements only, so the Branch gate cannot be enforced as written.

5. **`test-fixture-design` states the isolation default backwards.** `go-integration-test` makes transaction rollback the default and names commit behaviour as the one case rollback cannot serve (`references/test-isolation-standard.md` sections 2-3; `SKILL.md:72-81`). `test-fixture-design` calls per-tenant scoping the default (`references/fixture-patterns-catalogue.md:409`) and says to use rollback **for** testing commit behaviour (`SKILL.md:150-152`; heading "Transaction rollback (for tests that need real commits)" at catalogue `:429`).

6. **Reference code that would mislead an agent copying it.**
   - `MakeArchivedAsset` never sets an archived state; it returns a Restricted asset at version 5 (`fixture-patterns-catalogue.md:162-170`), so the access-denial test at `:176-180` tests the wrong thing.
   - `SetupTestDB` truncates every table in cleanup (`:254-257`) while parallel tests share the database (`:416-418`).
   - The builder uses `uuid.New()` (`:50-51`) while `SKILL.md:121-122` says builders assign known IDs.
   - The "mockery" examples show Func fields and `PublishCalls()` (`go-mock-implementation.md:49-65`). [GK] That is moq's output shape; mockery generates testify-style mocks.
   - The CI freshness check diffs `*.mock.go` and `*.moq.go` (`go-mock-implementation.md:248`) while the files are named `*_mock.go` and `*_moq.go` (`:31,130`), so the Makefile gate matches nothing.

7. **First-product leakage is a rule, not only an example.** `bdd-feature-file/SKILL.md:128` tells every product to use "data asset", "sensitivity level", "classify" and bans "file", "label", "tag". Rule text should be "use this product's glossary". Leakage also runs through `acceptance-criteria/SKILL.md:67-93`, the pyramid tables (`test-pyramid/SKILL.md:98-103`), the strategy template (`:55-56,73-74,101-104,115`), and all fixture and mock code.

8. **Structural gaps shared by all six:** no `sources:`, no `## Gotchas`, no `examples/` or `resources/` folder, no profile (lean / standard / enterprise) scaling in the body, no eval suite, descriptions that read as topic summaries (none contains "Use when"). The test strategy has no manifest entry at all: `implement` is `[]` (`phase-requirements.json:907`), although `/sdlc-implement` step 3 and `agents/test-strategist.md:151` order one to be produced, and the agent is told to produce only what the plan requires (`:148`). It therefore has no canonical path and no approval.

## Findings table

| ID | Lens | Evidence (file:line) | Observation | Proposal | Kind | Impact | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| W3A-1 | Mechanics | `scripts/tdd-gate.sh`; output paths in narrative 1 | Builders, fakes, golden helper and godog step files are denied | Decide D-9; then align every output path | Defect (cross-component) | H | M | High (ran hook) |
| W3A-2 | Pipeline | `phase-requirements.json:288-319`; `agents/requirements-analyst.md:344` | Lean cannot satisfy AC without an optional artifact | D-6 | Contradiction | H | M | High |
| W3A-3 | Traceability | AC template `:18`; `example-mapping/SKILL.md:169-185`; `validate-criteria.sh:69` | `EM-` ID does not exist | Cite the map path or `US-n`; fix validator and both templates | Defect | H | S | High |
| W3A-4 | Traceability | AC template `:22-59`; `check-uat-scenarios.py:122-124` | `AC-001` is incompatible with `AC-US-<n>` | Adopt `AC-US-n.m` | Defect | H | S | High |
| W3A-5 | Naming | `scaffold-criteria.sh:39`; `agents/requirements-analyst.md:153`; `user-story-writing/templates/user-story-backlog.md:74` | Script writes `US-9-slug.md`; agent and backlog expect `US-9.md` | Write `US-n.md` | Defect | M | S | High |
| W3A-6 | Docs | `acceptance-criteria/SKILL.md:212`; output-format `:6` | Wrong script usage | Add `<product>` | Defect | M | S | High |
| W3A-7 | Validator | `validate-criteria.sh:43-76` | Passes placeholders, empty sections, open questions; fails rules-only stories (`:60-64` requires gherkin); `well` flags "as well" | Per-section content check, placeholder check, open-question count, accept Rule blocks | Defect | H | M | High (ran; "as well" by regex reading) |
| W3A-8 | Validator | `validate-bdd-feature-file.sh:44-91` | Passes template; false HTTP hits; rejects tags; checks tags per file, not per feature content; `And` after `When` not counted | Use `@` tags, step-line verb+path patterns, placeholder check, count And-after-When | Defect | H | M | High |
| W3A-9 | Consistency | `test-pyramid` template `:63,120-121`; `go-mutation-test/SKILL.md:74,80` | Two mutation thresholds and cadences | D-4; pyramid points to owner | Contradiction | H | S | High |
| W3A-10 | Consistency | narrative 4 | Two flaky policies | D-2 | Contradiction | H | M | High |
| W3A-11 | Consistency | `test-pyramid/SKILL.md:113-115`; template `:112-115`; `go-makefile/SKILL.md:114` | Branch gate claimed, line gate enforced; "Statement is subsumed, measuring it adds nothing" while it is what is measured | D-3 | Contradiction | H | S | High |
| W3A-12 | Accuracy | template `:59`; `agents/test-strategist.md:94`; `CLAUDE.md` Phase Gate Rules | Hook described as date/timestamp check; it checks existence | State what it does (or change the hook) | Defect | M | S | High |
| W3A-13 | Scaling | template `:81-106`; `phase-requirements.json:982,989,996` | Template mandates load, weekly chaos, nightly mutation at every size; lean guidance says no chaos or mutation runs, standard chaos optional | Profile columns taken from the plan's guidance | Defect | H | M | High |
| W3A-14 | Defaults | template `:73-104` | Invented numbers (p99 200 ms, 500 ms, error rates, 30 s) as defaults | Cite NFR / SLO IDs; never default a number | Defect | H | S | High |
| W3A-15 | Research | `test-pyramid/SKILL.md:48-53`; template `:42-47`; `unit-testing-khorikov.md:16` | 70/20/10 has no research backing (search of `research/testing/` found none); Khorikov: shape is an outcome, not a target; contract is "small" outside the 100% | D-8 | Research conflict | M | S | High |
| W3A-16 | Research gap | `agile-testing-crispin-gregory.md:7,11,31` | No quadrants lens, no checking-vs-testing; Q3 mentioned only as one pointer (`SKILL.md:88`); split exists only in agent files (`test-strategist.md:87`) | Add short quadrant map and "checks, not testing" line | Augment | M | S | High |
| W3A-17 | Research gap | `testing-web-apis-winteringham.md:8,12,32,37-38` | No risk-based depth choice; no home for behaviour checks (idempotency, 429, deprecation) | Add impact x likelihood step to the strategy procedure; behaviour-check home is out of batch | Augment | M | M | High |
| W3A-18 | Scope | `test-pyramid/SKILL.md:46-51,68-86,115` | Frontend layers (component, `react-e2e-testing`) absent from tables and `related:`; owners are Go-only | Stack-neutral layer table with per-stack skill column | Defect | M | S | High |
| W3A-19 | Manifest | `phase-requirements.json:907-909`; `commands/sdlc-implement.md:12` | Test strategy and feature files not registered; strategy template has no path | D-10 | Pipeline gap | H | M | High |
| W3A-20 | Lint | `lint-skill-layout` L5 on `references/test-strategy-template.md:3` | Repo-rooted pointer; also template plus guidance in one file | Split to `templates/` and `references/` | Folder | M | S | High |
| W3A-21 | Isolation | narrative 5 | Default contradicts `go-integration-test`; rollback advice inverted | D-1; one owner, the other points | Defect | H | S | High |
| W3A-22 | Tenancy | catalogue `:205-216,261-272,409-420`; `SKILL.md:146-149`; `multi-tenancy-design/SKILL.md:4-11` | Assumes pooled `tenant_id` everywhere ("physical multi-tenancy model scopes every row", self-contradictory); #1438 made the model a per-product choice | Isolation key read from the tenancy design; single-tenant and silo variants | Leakage | H | M | High |
| W3A-23 | Code | catalogue `:162-180` | Archived mother is not archived | Set lifecycle state | Defect | M | S | High |
| W3A-24 | Code | catalogue `:254-257,416-418`; `:267-270` | TRUNCATE in per-test cleanup breaks parallel tests; `FreshTenant` deletes only one table; cleanup errors ignored | Remove truncate; delete all owned tables, report errors | Defect | M | S | High |
| W3A-25 | Code | catalogue `:50-51`; `SKILL.md:121-122` | Random IDs contradict determinism rule | Fixed or seeded defaults, or reword | Defect | L | S | High |
| W3A-26 | Code | catalogue `:355,367` | [GK] `go test ./... -update` fails in packages that do not define the flag | Scope the command to the package | Defect | L | S | Medium |
| W3A-27 | Frontmatter | `test-fixture-design/SKILL.md:3-18` | Description is 1122 characters and lists content, not triggers. [GK] platform limit is 1024 | Rewrite as usage condition | Description | M | S | Measured; limit Medium |
| W3A-28 | Tooling | `go-mock-implementation.md:17-58,248` | mockery examples are moq-shaped; `go generate` needs a directive that is never shown; freshness glob wrong; `@latest` installs (`:82,127`) are unpinned | D-5, then rewrite the guide and pin versions | Defect | H | M | High on glob; Medium on [GK] |
| W3A-29 | Consistency | `mock-generation/SKILL.md:121`; `agents/test-strategist.md:108`; `go-unit-test/references/mocking-philosophy.md:44`; `go-project-structure/references/package-layout-standard.md:68`; `go-makefile/SKILL.md:117` | Skill defaults to mockery; others say moq/mockgen; coverage filter excludes `_mock.go` but not `_moq.go` | D-5 | Contradiction | H | S | High |
| W3A-30 | Taxonomy | `test-double-taxonomy.md:54-69`; `go-mock-implementation.md:51-64` | Mock is defined as up-front expectations, yet the "mock" example asserts afterwards, which is the file's own spy definition (`:40-43`) | Define by role (verifies interaction), note both styles | Defect | M | S | High |
| W3A-31 | Self-contradiction | `go-mock-implementation.md:135-150` | moq example call-counts a repository, then a note says that violates the rule | Replace with an unmanaged port | Defect | M | S | High |
| W3A-32 | Grounding | `test-double-taxonomy.md:11-13` | Credits Meszaros (no research file) and says Khorikov "extended" the five types; research file supports only mock vs stub (`unit-testing-khorikov.md:10`) | Drop or reword | Attribution | M | S | High |
| W3A-33 | Gap | `go-mock-implementation.md:176-214`; `test-double-taxonomy.md:111` | Fake ignores tenant scoping and concurrency; nothing keeps fake behaviour equal to the real adapter; boundary for another service of the same product is undefined | [GK] shared contract test run against fake and real; add the sibling-service row | Augment | M | M | Medium |
| W3A-34 | Duplication | `mock-generation/SKILL.md:44-61`; taxonomy `:105-128`; `go-unit-test/references/mocking-philosophy.md` | Managed/unmanaged table in three places | One home (`go-unit-test` for "whether", this skill for "how") | Overlap | M | S | High |
| W3A-35 | Preload | `agents/test-strategist.md:168`; `agents/backend-engineer.md` skills list | backend-engineer applies `mock-generation` and `test-fixture-design` but preloads neither | Add to its `skills:` or state the retrieval step | Agent gap | M | S | High |
| W3A-36 | Leakage | `bdd-feature-file/SKILL.md:55-75,128,184`; template-free rules | First product's glossary is stated as the rule | Generic rule; move domain to examples | Leakage | H | S | High |
| W3A-37 | Mechanics | `bdd-feature-file/SKILL.md:193-196`; `methodology-review/SKILL.md:136` | Steps live in `internal/test/bdd/`, but review runs `go test ./features/...` | One layout with a runnable command | Contradiction | H | S | High |
| W3A-38 | Unbacked | `bdd-feature-file/SKILL.md:150-151`; `react-e2e-testing/SKILL.md` (no Gherkin mention) | "Same scenarios drive Playwright" has no binding tool or downstream support | Name a binding approach or drop | Defect | M | M | High on absence |
| W3A-39 | Completeness | `bdd-feature-file/SKILL.md:159`; reference `:23` | Living-documentation report tool deferred to "whoever implements" | Pick a default report step and path | Gap | M | M | High |
| W3A-40 | Syntax | template `:26-32`; SKILL `:51-85` | Outline has no Given; no `Rule:` grouping although the DoR is one rule per example (reference `:12`) [GK `Rule:` is Gherkin 6] | Group scenarios under rules; tag with AC IDs | Augment | M | S | Medium |
| W3A-41 | Traceability | `bdd-feature-file/SKILL.md:167`; no tag or ID convention anywhere | "Every criterion has a scenario" cannot be checked | `@AC-US-n.m` tags and a coverage check script | Script | H | M | High |
| W3A-42 | Consistency | `acceptance-criteria/SKILL.md:150-158`; `user-story-writing/SKILL.md:92` | Count table keys on S/M/L story size; stories have no size field | Replace with a split signal (rules per story) | Contradiction | M | S | High |
| W3A-43 | Upstream | `requirements-analysis/references/requirement-shell-and-fit-criteria.md:41`; `user-story-writing/SKILL.md:89`; AC and example-mapping bodies | Fit criteria, seed example, BR-n and NFR citations are never consumed | Add an input step to both procedures | Gap | H | S | High |
| W3A-44 | Declarative | `acceptance-criteria/SKILL.md:89-93,145`; `:198`; `bdd:93-96` | Good examples name Redpanda, AES-256 and stdout, against the skill's own observable-outcome rule and Pugh `lean-agile-atdd-pugh.md:11` | Business-language rules; technical verification goes to NFR | Defect | M | S | High |
| W3A-45 | Golden Triangle | `acceptance-criteria/SKILL.md:106` vs `bdd-feature-file/SKILL.md:91` | Edge case "required for complex stories" vs required for every feature; validator requires it always | One rule | Contradiction | M | S | High |
| W3A-46 | Key examples | `example-mapping/SKILL.md:126,149`; `acceptance-criteria/SKILL.md:164`; `specification-by-example-adzic.md:10` | Every green card becomes a scenario, against the minimality principle bdd teaches | Cards that teach nothing new are pruned or become outline rows | Contradiction | M | S | High |
| W3A-47 | Procedure | `example-mapping/SKILL.md:100-109,157` | Agent-run mode has no step for who answers red cards (product owner), when to stop, or re-mapping; 25-30 minute box is meaningless for an agent (`:163`) | Procedure: draft, ask the user, update, readiness; replace time box with rule/question counts | Rewrite | H | M | High |
| W3A-48 | Example | `example-mapping/SKILL.md:62-64,74` | Worked map turns a performance target into a rule, which stories forbid (`user-story-writing/SKILL.md`, splitting section) | Cite the NFR | Defect | L | S | High |
| W3A-49 | Mechanics | `example-mapping/SKILL.md:167-210` | No template file, checklist or checker; "sprint" language (`:107-108,179`) for an agent-built product | `templates/`, script (red count, counter-example per rule), readiness wording | Folder/script | M | M | High |
| W3A-50 | Glossary | `ubiquitous-language.md` search | No headwords for test double, mock, stub, fake, coverage criteria | Hand to `glossary-management` | Out of batch | L | S | Medium (pattern search) |
| W3A-51 | Stack | all code in `bdd-feature-file`, `test-fixture-design`, `mock-generation`; `python-testing-with-pytest-okken.md:18,89-91` | Go only; no instruction for a stack override or the React side (`mock-generation/SKILL.md:157-162` is two sentences) | Make bodies stack-neutral, Go in references; state the override behaviour | Scope | M | M | High |
| W3A-52 | Contract tests | `tests/skills/*.contract.sh` | Each probes one substring; two probe content that should change (`70`, `with-expecter`) | Retire after evals pass | Test | L | S | High |

## Per-skill sections

### acceptance-criteria

1. **Sources**
   - `research/requirements-and-user-stories/lean-agile-atdd-pugh.md`: collaborative triad (`:7`), acceptance test as Confirmation (`:9`), examples before rules (`:10`), declarative style (`:11`), readiness diagnostic (`:12`), contract changed only by agreement (`:14`), solo-agent honesty (`:48`). Already used in prose.
   - `research/requirements-and-user-stories/user-stories-applied-cohn.md`: Three Cs (`:7`), no Gherkin attribution (`:51`).
   - `research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md`: testability gate (`:12`).
   - `research/requirements-and-user-stories/software-requirements-wiegers-beatty.md`: fit criterion (`:16`, `:30`), alternative and exception flows as a source of negative cases (`:12`), conceptual tests (`:21`).
   - `research/testing/specification-by-example-adzic.md`: definition of ready (`:9`), key examples (`:10`).
2. **Gaps and errors:** W3A-2 to 7, 42 to 46. No mapping from FR fit criteria or cited BR-n / NFR. No lean / standard / enterprise rule. No Gotchas, no checklist, no examples. Rule-based format has no ID or traceability field. Edge list (`:128-132`) has no tenant-isolation edge [GK it matters for multi-tenant products]. The `acceptance-criteria-document` produces-name differs from the manifest artifact `acceptance-criteria`. `related:` omits `bdd-feature-file`, `uat-plan`, `uat-scenario`, `user-story-writing`, all named in prose or adjacent.
3. **Folder moves:** `assets/acceptance-criteria-template.md` to `templates/`; merge `references/output-format-template.md` (a duplicate of the template) into a short `references/` field guide or delete it; testability table to `resources/` with a checklist; keep scripts (tests exist in `tests/scripts/`).
4. **Example ideas:** (a) lean: a community tool-lending app, one story, criteria with an inline mini map; (b) standard: a clinic appointment reminder, rules with a counter-example and a cited BR-n and NFR; (c) enterprise: a multi-tenant expense-approval product with delegation, concurrency, tenant isolation and a regulatory rule.
5. **Eval ideas:** (a) user asks for criteria for a story with no examples: trap is writing abstract rules at once instead of producing or requesting examples and recording open questions. (b) Lean product with no example-maps artifact: must proceed by the decided lean route, not invent an `EM-` ID. (c) A rule needing "within 2 seconds": trap is stating a number nobody agreed, or burying it in the criterion instead of citing the NFR. (d) A user asks to relax a criterion to match the built behaviour: must route it back as a change needing approval.
6. **Overlaps:** `example-mapping` (rules and examples restated), `bdd-feature-file` (Golden Triangle, declarative style, observable Then), `uat-scenario` (translation), `requirements-analysis` (fit criteria).
7. **Size:** M.

### bdd-feature-file

1. **Sources**
   - `specification-by-example-adzic.md`: living documentation (`:7`), workshops (`:8`), definition of ready (`:9`), key examples (`:10`), specification refactoring (`:11`), Given/When/Then as rule illustration (`:12`).
   - `agile-testing-crispin-gregory.md`: quadrant Q2 (`:7`), three-amigos collaboration (`:15`).
   - `lean-agile-atdd-pugh.md`: declarative style (`:11`), translation waste (`:13`).
   - `software-testing-craftsman-jorgensen.md`: decision tables for rules with three or more conditions (`:11`, `:21`), the completeness complement to key examples (Adzic caveat `:52`).
2. **Gaps and errors:** W3A-1, 8, 36 to 41, 45. The reference cites research paths in prose but there is no `sources:` field. The attribution of Specification by Example to the Golden Triangle chain is fine, but "Three Amigos (see the canonical glossary; played solo...)" gives an agent no concrete review step between requirements-analyst and test-strategist (`SKILL.md:47`). Hermeticity relies on an unshown `reset` and [GK] a godog hook signature that may not compile as written (`:144`). Description is a summary with file names in it; stale `assets/bdd-feature-file-template.md` name in description (`:14`) while the file is `.feature`. No Gotchas, no profile scaling (is every criterion a scenario at lean? `:34` says yes).
3. **Folder moves:** `assets/bdd-feature-file-template.feature` to `templates/`; Go binding code to `references/godog-bindings.md`; add `examples/`; a definition-of-ready checklist in `resources/` (split out of the reference).
4. **Example ideas:** (a) lean: a food-truck pre-order cancel rule, three scenarios; (b) standard: a library loan-renewal rule set grouped by rule with an outline and pruned rows; (c) enterprise: a multi-tenant payments approval limit with role and amount conditions (decision table first), event-driven eventual outcome, isolation scenario, journey bound at API and UI.
5. **Eval ideas:** (a) Criteria for a non-data product (booking): trap is leaking "data asset" vocabulary or inventing synonyms instead of the product's glossary. (b) Request phrased as clicks and endpoints: must rewrite declaratively. (c) Eleven near-identical Examples rows: prune to those that change what is proven. (d) "Are our docs living documentation since the features run in CI?": must say half, name the generated report. (e) Criteria containing an invented rule gap: must send it back rather than fill it.
6. **Overlaps:** `acceptance-criteria`, `example-mapping`, `uat-scenario`, `go-e2e-test`, `react-e2e-testing`, `methodology-review` BDD checks.
7. **Size:** L (generalise, validator, traceability script, layout decision).

### example-mapping

1. **Sources**
   - `lean-agile-atdd-pugh.md`: examples before rules (`:10`), readiness (`:12`), concrete data (`:19`), one rule per example (`:24`), solo triad (`:48`).
   - `specification-by-example-adzic.md`: facilitation and definition of ready (`:9`), pruning (`:10`); attribution care for Three Amigos and Wynne (`:8`).
   - `agile-testing-crispin-gregory.md`: collaboration before code (`:9`, `:15`).
   - `user-stories-applied-cohn.md`: Conversation leg (`:7`), splitting patterns (`:11`).
2. **Gaps and errors:** W3A-2, 3, 43, 46 to 49. Matt Wynne is named (`:5`) and the research only mentions him in passing; no card-mechanics or 25-minute claim is in the research read, so the time box is unbacked [GK it is Wynne's]. No `related:` field although it names `acceptance-criteria` and (implicitly) `bdd-feature-file`. "Counter-example for every rule" (`:146`) conflicts with nothing but is unchecked. No threshold for "too many rules". BDD Scenario Map (`:206-209`) assigns scenario titles in Ideate, a test-strategist output. No honesty line in the output saying the three perspectives were played by one agent (acceptance-criteria requires it, `:120`; the template here has no field).
3. **Folder moves:** Output Format to `templates/example-map.md`; ASCII worked map and Gherkin conversion to `examples/`; add `resources/` readiness checklist and `scripts/check-example-map` with test.
4. **Example ideas:** (a) lean: allotment-plot waiting list, two rules, one question; (b) standard: parcel-locker pickup expiry with counter-examples and a split signal; (c) enterprise: cross-border subscription refund with tax rules per region, red cards blocking, user answers folded back.
5. **Eval ideas:** (a) Story with an ambiguity: trap is inventing the answer instead of a red card put to the user. (b) User asks to mark it ready with open questions. (c) Green cards that restate rules: must demand data. (d) A story producing eight rules: must propose a split.
6. **Overlaps:** `acceptance-criteria` (the other half; the derivation guidance is written twice), `user-story-writing` (seed example, splitting), `domain-storytelling` (variant stories, `domain-storytelling-hofer-schwentner.md:38`).
7. **Size:** M.

### test-pyramid

1. **Sources**
   - `unit-testing-khorikov.md`: pillars (`:7`), quadrants (`:12`), coverage not a target (`:14`), shape as outcome (`:16`).
   - `agile-testing-crispin-gregory.md`: quadrants (`:7`), checking vs testing (`:11`), Definition of Done (`:13`), automation pyramid (`:14`).
   - `testing-vv-dictionary-quigley.md`: coverage criteria (`:25-29`), regression as purpose (`:30`), smoke vs sanity (`:32-34`). Low-to-moderate confidence per its own note (`:7`).
   - `software-testing-craftsman-jorgensen.md`: stronger criteria for high-risk logic (`:12`, `:35`).
   - `testing-web-apis-winteringham.md`: risk-based depth (`:8`, `:18`).
   - `explore-it-hendrickson.md`: exploration is outside scripted layers (`:19`).
   - `contract-testing-in-action-cruz-prescott.md`: contract layer placement (`:15`).
   - `research/software-architecture/building-microservices-newman.md`: testing in production, semantic monitoring (`:12`).
2. **Gaps and errors:** W3A-9 to 20. "Shift-right" lists performance regression gating that runs at build (`:83`) while the template makes it a merge block (`:87`). Template tools (`kin-openapi`, Gremlins, Playwright, k6, Toxiproxy) are fixed with no override note. No procedure for composing a strategy (read NFRs, risk-rate, choose layers, set gates, validate). `related:` omits `ci-pipeline`, `react-component-testing`, `react-e2e-testing`, `slo-definition`. The diagram places contract below integration; no research states an order [GK orderings vary]. `go-contract-test`'s Pact tier is not mentioned in the template beyond "when multi-repo".
3. **Folder moves:** split `references/test-strategy-template.md` into `templates/test-strategy.md` plus `references/filling-the-strategy.md`; `resources/` checklist; `examples/` per profile.
4. **Example ideas:** (a) lean: a booking widget modular monolith, one page: unit plus journeys for Must stories, performance only against stated NFRs; (b) standard: a B2B invoicing product with three services and a React app, risk-rated endpoints, contract tests, mutation on critical packages; (c) enterprise: a multi-region telemetry platform with pooled and siloed tenants, load, chaos, compliance delegation, quarantine budget.
5. **Eval ideas:** (a) Lean product asks for a strategy: trap is adding load, chaos and mutation. (b) "We have 90% coverage, are we safe?" (c) "Retry the flaky test three times": must apply the decided policy. (d) "Set our p99 target": must refuse to invent and ask for the NFR. (e) "Force 70/20/10": explain shape as outcome.
6. **Overlaps:** `go-unit-test` (coverage, quadrants), `go-e2e-test` (flaky, smoke), `go-mutation-test`, `go-makefile`, `ci-pipeline`, `uat-plan`.
7. **Size:** L.

### test-fixture-design

1. **Sources**
   - `unit-testing-khorikov.md`: maintainability pillar (`:7`, `:36`), no shared state (`:9`), fixture caveat (`:55`).
   - `python-testing-with-pytest-okken.md`: factory fixtures, scopes, per-test rollback (`:11-13`, `:77-80`) if a Python override is supported.
   - `research/software-architecture/pragmatic-programmer-hunt-thomas.md`: programming by coincidence (`:29`, `:49`).
   - `research/domain-driven-design/versioning-event-sourced-system-young.md`: stored old events as fixtures (`:28`).
   - `testing-web-apis-winteringham.md`: black-box test data note (`:54`).
2. **Gaps and errors:** W3A-1, 21 to 27. Test Data Builder and Object Mother carry no research backing (no research file found naming either). `SeedActiveTenant` is a seeding helper presented as an Object Mother (`catalogue:183-218`) and the contract test pins it. No guidance for event or message fixtures, broker topic isolation, time-zone or locale data, or synthetic personal data (never copy production data) [GK]. "Unit fixtures are inline" is also stated in `go-unit-test`. No enterprise scale (large seed sets, load data, silo tenants).
3. **Folder moves:** catalogue split into `references/` per concern (builders and mothers; cleanup and isolation; determinism and golden files) and `templates/` for builder and golden skeletons; `examples/` for the harder isolation cases.
4. **Example ideas:** (a) lean: a recipe app, inline literals and one builder; (b) standard: an order-fulfilment service with Testcontainers, rollback default and an outbox real-commit case; (c) enterprise: a hybrid-tenancy insurance claims platform (pooled plus siloed), event-version fixtures, parallel CI shards.
5. **Eval ideas:** (a) Outbox atomicity test: trap is wrapping it in a rollback transaction. (b) Parallel tests with truncate-in-cleanup: spot the collision. (c) Single-tenant product: trap is inventing `tenant_id`. (d) "Golden test fails, just run -update". (e) `defer` in a helper.
6. **Overlaps:** `go-integration-test` (isolation), `go-e2e-test` (seeding and teardown reference), `go-unit-test` (fixture standard), `go-contract-test` (Provider State fixtures), `mock-generation`.
7. **Size:** L.

### mock-generation

1. **Sources**
   - `unit-testing-khorikov.md`: pillars (`:7`), classical vs London (`:9`), mock vs stub (`:10`), managed vs unmanaged (`:11`), overspecification (`:15`), Go caveat (`:52`).
   - `research/software-architecture/architecture-patterns-with-python-percival-gregory.md`: fakes at ports (`:13`, `:23`, `:33`).
   - `software-testing-craftsman-jorgensen.md`: "stub" has a second meaning (`:34`).
   - `python-testing-with-pytest-okken.md`: mocks at the unmanaged edge (`:18`, `:83`).
   - `contract-testing-in-action-cruz-prescott.md`: consumer mock generated from the contract (`:8`) for cross-service doubles.
2. **Gaps and errors:** W3A-28 to 35. "Rule with no exception" (`taxonomy:115`) leaves no guidance for a managed dependency that is slow or non-deterministic (clock, ID generator, random) [GK]. No error-injection fake pattern, though `go-chaos-test` uses fault decorators. No examples folder; no checklist; no check script (a grep for call-count assertions on repository fakes is a candidate, with judgment). Name says "generation" while most content is double selection; `description` should carry both triggers.
3. **Folder moves:** `references/go-mock-implementation.md` split: generator config to `templates/` (`.mockery.yaml` or moq directive), fake skeleton to `templates/`, worked tests to `examples/`; selection checklist to `resources/`.
4. **Example ideas:** (a) lean: a newsletter sign-up with one fake and one mocked email port; (b) standard: a ride-booking service: fake repository, mocked payment provider, outbox relay; (c) enterprise: a multi-service logistics platform: sibling-service doubles tied to contracts, fault-injecting fake, tenant-aware fake verified against the real adapter.
5. **Eval ideas:** (a) "Assert Save was called once": must switch to state. (b) "Mock the pgx pool". (c) Email provider: interaction mock is correct. (d) Asserting on a stub. (e) Interface changed and CI stayed green: find the missing freshness gate.
6. **Overlaps:** `go-unit-test` (whether to mock), `go-integration-test`, `react-component-testing` (MSW), `go-chaos-test`, `go-project-structure` (generated file naming).
7. **Size:** M.

## Contradictions needing a product-owner decision

| ID | Question | Options | Recommendation |
|---|---|---|---|
| D-1 | Default isolation for database integration tests | (a) transaction rollback, scoped keys only for real-commit and out-of-process tests; (b) per-tenant scoping everywhere | (a). It matches `go-integration-test`, needs no tenancy assumption; `test-strategist.md:105` is reworded |
| D-2 | One flaky-test policy | (a) e2e standard: one detection retry, quarantine tag, deadline, deliberate deletion with a record; (b) pyramid: no retries, never delete | (a) for e2e, no retry for unit and integration; `test-pyramid` states it once and `go-e2e-test` implements it |
| D-3 | Coverage gate | (a) 80% statement/line, called what it is, generated code excluded; (b) branch gate with an added tool; (c) no percentage gate, report plus mutation | (a), as a floor that mutation testing backs, and tell `coverage-by-quadrant` the floor is repo-wide, not per package (or choose (c); the two current texts cannot both stand) |
| D-4 | Mutation threshold and cadence | 60% monthly and pre-release, or 70% nightly | 60%, owned by `go-mutation-test`; the strategy only cites it |
| D-5 | Default Go double generator | (a) moq; (b) mockery | (a). Agents, three neighbouring skills and the existing examples already match it; fix the coverage filter to `_moq.go` |
| D-6 | Lean acceptance criteria | (a) mini map inside the criteria file (rules, one example each, open questions); (b) make example maps required at lean; (c) derive from the story's seed example only | (a). Keeps examples-first with one file |
| D-7 | Criterion ID scheme | `AC-US-n.m` or `AC-nnn` | `AC-US-n.m`; downstream already depends on it |
| D-8 | Pyramid percentages | (a) drop ratios, keep the shape and lowest-layer checks; (b) keep as indicative | (a), per Khorikov `:16` |
| D-9 | Test-support code and the TDD gate | (a) hook exempts a named test-support tree (`internal/test/**`); (b) require all helpers in `_test.go` files (cannot be shared across packages [GK]) | (a), with a hook test |
| D-10 | Is the test strategy (and the feature-file set) a registered artifact | (a) add to `implement` in the manifest with a canonical path, lean short; (b) leave unregistered | (a); also decide whether lean requires a scenario for every criterion or for Must stories |
| D-11 | Edge scenario | required for every feature, or only complex stories | Required, with an explicit recorded "no meaningful edge" escape at lean |

## Missing books

| Book | Why it came up | Needed? |
|---|---|---|
| Meszaros, *xUnit Test Patterns* | Named at `test-double-taxonomy.md:11`; no research file | No. Khorikov covers the decisions; drop the attribution |
| Freeman and Pryce, *Growing Object-Oriented Software* (origin of Test Data Builder [GK]) | Pattern used unattributed | No. Keep unattributed |
| A Gherkin / godog or Example Mapping primary source (Wynne) | Syntax (`Rule:`, tags), card mechanics, time box are unbacked | No book. Verify syntax and godog behaviour against official documentation at build time; Pugh and Adzic cover the practice |
| Mock generator documentation (moq, mockery) | W3A-28 | Not a book; check the official docs during the rebuild |

Existing research is enough for all six rebuilds.

## What I could not verify

- No Go toolchain run: the Go snippets, godog hook signatures, mockery / moq / gomock behaviour and the `-update` flag behaviour were not compiled or executed. Statements about them are marked [GK].
- Gherkin comment and `Rule:` semantics are [GK].
- The platform's description length limit is [GK]; `schemas/skill.schema.json` shows only `minLength` in the lines read.
- No evals, contract tests or model calls were run. No git commands were meant to be run (one `git status` was attempted inside a compound command and was blocked by the permission classifier).
- Research outside `research/testing/` and the files named above was searched by pattern, not read in full; Wiegers and Hathaway were read in part. The three excluded requirements books were not cited. `research/testing/` book files carry their own confidence caveats (notably Quigley and Hambling).
- Neighbouring skills (`go-*`, `react-*`, `uat-*`) were read only at the passages cited.
