# Binding, Running, Reporting and Upkeep

Self-contained. Use when writing step definitions, running scenarios, deriving browser tests from the same criteria, reporting results, or tidying a grown suite. No code here was compiled or run: confirm each call against the installed tool version.

## Order of work

1. The approved feature file exists.
2. Write step definitions that drive the product through its public interface and assert on what a user or consumer observes.
3. Run: the scenarios fail for the expected reason (not "undefined").
4. Write the code until they pass.

Bind each scenario at the lowest layer that can prove it (`test-pyramid`); the test strategy records layer, trigger and selector. Every scenario starts from fresh state and runs alone and in any order. Technical detail (requests, queries, selectors) lives here, not in the Gherkin.

## Go: godog

Facts from godog's official documentation (v0.16.0; the API may change before 1.0.0):

- Run from a Go test with `go test`; the `godog` command is deprecated.
- **Without `Strict`, undefined and pending steps do not fail the suite.** Always set it.
- With no paths and no `features` directory nothing runs and the exit is success. Assert that features were found.
- The `events` format returns 0 even on failure; do not gate on it.
- Steps register with `Step`, `Given`, `When`, `Then`; the pattern is a regular expression.
- Scenario state travels in `context.Context`; hooks exist at suite, scenario and step level.
- `Randomize: -1` exposes state leaking between scenarios.

Layout for this plugin: `internal/test/bdd/` holds `bdd_test.go` and `steps_*.go` (the test-first hook exempts `internal/test/`). Run `go test -v ./internal/test/bdd/...`.

```go
func TestFeatures(t *testing.T) {
	suite := godog.TestSuite{
		ScenarioInitializer: InitializeScenario,
		Options: &godog.Options{
			Format:    "pretty",
			Paths:     []string{"../../../artifacts/<product>/implement/features"},
			Strict:    true,
			Randomize: -1,
			TestingT:  t,
		},
	}
	features, err := suite.RetrieveFeatures()
	if err != nil || len(features) == 0 {
		t.Fatalf("no feature files found: %v", err)
	}
	if suite.Run() != 0 {
		t.Fatal("feature scenarios failed")
	}
}
```

```go
type worldKey struct{}

func InitializeScenario(sc *godog.ScenarioContext) {
	sc.Before(func(ctx context.Context, _ *godog.Scenario) (context.Context, error) {
		return context.WithValue(ctx, worldKey{}, newWorld()), nil // fresh per scenario
	})
	sc.When(`^she cancels order (\d+)$`, sheCancelsOrder)
}
```

## Python

The research library covers pytest but no Gherkin binding library, so this skill names none. Put the choice to the product owner as an open item (an added dependency needs a reason), and verify its handling of undefined steps, `Rule:` and tags before gating on it. Step code goes under `tests/`. Whatever runs it: a run that collects nothing fails (pytest exits 5 when no tests are collected), and markers are registered with strict checking.

## Browser journeys

Playwright does not run these feature files here. Must Have journeys are plain Playwright tests tagged with the same criterion IDs (`@AC-US-n.m`), selected with `--grep`; `react-e2e-testing` owns them. A `skip` or `fixme` test does not run, so it proves nothing; forbid `.only` on CI. The skill's script checks feature files only: check browser tags against the criteria separately.

## Reporting results

State the runner's own counts: passed, failed, undefined, pending, skipped, with the command, commit and date. "Written" is not "passing". A selector that matches zero scenarios fails the job. Flaky scenarios follow `test-pyramid`: one automatic retry at end-to-end only, quarantine with a deadline, and the criterion counts as unproven meanwhile.

## Living documentation

Adzic's term needs both halves:

1. The specifications are validated automatically against the real system on a regular cadence (feature files in the repository, run in CI; a stale scenario fails).
2. The validated result is rendered back as a readable document generated from that run, so nobody maintains it by hand.

Generate `artifacts/<product>/quality/test-reports/living-documentation.md` (artifact frontmatter; approved with the other test reports) from the runner's machine-readable results: grouped by feature and rule, each scenario with its criterion IDs, status, run date and commit; criteria with no running scenario listed as unproven. Which output format and generator to use is checked against the runner at build time. Never type statuses by hand, and until the report exists say that only half is in place.

## Suite upkeep

Treat the specifications like production code (Adzic): merge duplicated step definitions and overlapping scenarios, extract shared setup, and retire scenarios whose rule is gone (through the criteria, never by quiet deletion). One known-stale scenario costs trust in all of them.
