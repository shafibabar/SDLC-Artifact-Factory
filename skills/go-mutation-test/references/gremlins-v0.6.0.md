# Gremlins v0.6.0: What It Does, Observed

Self-contained. Read before changing the Gremlins setup, reading its output, or answering "why not just use its score". Sources: Gremlins' documentation and its v0.6.0 source (`research/testing/gremlins-official-docs.md`), and runs made for this skill on 2026-11-28 with Go 1.27.4 on macOS arm64. Each row says whether it was **observed** (run), read in the **source**, or is **unverified**.

## The tool

- Gremlins (`go-gremlins/gremlins`, Apache-2.0) is pre-1.0; its settings may change between minor releases. The product owner accepted it pinned to an exact version (2026-11-28). Install: `go install github.com/go-gremlins/gremlins/cmd/gremlins@v0.6.0`. Built that way, `gremlins --version` prints `dev`; `go version -m $(command -v gremlins)` shows `mod github.com/go-gremlins/gremlins v0.6.0` (observed), which is what the runner checks.
- **Go 1.27.4:** builds and runs (observed, every run in this skill).
- `gremlins unleash [path]` takes at most one path; two give `ERROR: accepts at most 1 arg(s), received 2` and exit 1 (observed). With a path, file names in the output and `exclude-files` patterns become relative to that path (observed), so the runner passes none.
- It first runs `go test -cover ./...` (no `-coverpkg` unless set), then plants mutants in every non-test `.go` file under the module, whatever its build tags (source), and runs `go test -failfast <the mutant's package>` per mutant: only that package's tests (source; `integration: true` runs `./...` instead).

## Configuration

| Fact | Status |
|---|---|
| Keys nest: `unleash.threshold.efficacy`, `unleash.threshold.mutant-coverage`, `unleash.exclude-files`, `unleash.timeout-coefficient`, `mutants.<type>.enabled` | Observed: each took effect |
| `threshold-efficacy: 60` under `unleash`, or a top-level `excludes:` list | Observed: ignored, no warning |
| `--threshold-efficacy` and `--threshold-mcover` on the command line, or `GREMLINS_UNLEASH_THRESHOLD_EFFICACY` | Observed: ignored (exit 0 with efficacy below the value). The value arrives as a string, which v0.6.0's lookup discards (source) |
| A nested threshold of 90 with efficacy 78.95% | Observed: exit 10; mutant coverage below its threshold: exit 11 |
| A threshold of 100 on a run with 100% efficacy | Observed: exit 10 (the check is `value <= threshold`) |
| Config file search: `/etc/gremlins`, `~/.config/gremlins/gremlins`, `~/.gremlins`, the module root, `.`; the first found wins | Source; observed: a `~/.gremlins/.gremlins.yaml` replaced the module's file. `--config <file>` restores it (observed) |
| Other `GREMLINS_*` environment variables override the file | Source (Viper); the runner refuses to start with any set |
| `//gremlins:disable-next-line` or any comment | Observed: no effect; the mutant was planted. A `//nomutant` directive exists only as an open pull request (#279) |

## Operators

Five types are on by default, six off (documented); this skill switches all eleven on. What each plants (source, `mappings.go`):

| Type | Changes |
|---|---|
| ARITHMETIC_BASE | `+`↔`-`, `*`→`/`, `/`→`*`, `%`→`*` |
| CONDITIONALS_BOUNDARY | `<`↔`<=`, `>`↔`>=` |
| CONDITIONALS_NEGATION | `==`↔`!=`, `<`↔`>=`, `>`↔`<=` |
| INCREMENT_DECREMENT | `++`↔`--` |
| INVERT_NEGATIVES | `-`→`+` (on binary `-` too: then it duplicates ARITHMETIC_BASE; observed both planted at one position) |
| INVERT_ASSIGNMENTS | `+=`↔`-=`, `*=`↔`/=`, and `%=`→`%=`: **no change**, so it always lives (observed) |
| INVERT_BITWISE, INVERT_BWASSIGN | `&`↔`\|`, `^`→`&`, `&^`→`&`, `<<`↔`>>` and their assignments |
| INVERT_LOGICAL | `&&`↔`\|\|` |
| INVERT_LOOPCTRL | `break`↔`continue` |
| REMOVE_SELF_ASSIGNMENTS | `x op= y` → `x = y` |

Never planted: removing a statement, a call or a `!`; changing a literal's value; altering a returned value. "Every planted mutant" cannot go beyond this list; each report says so.

## Statuses and what they really mean

| Status | Gremlins sets it when | Observed here |
|---|---|---|
| KILLED | `go test` exits 1 | **Also when the mutant does not compile** (`go test` exits 1 on a build failure: `"MERE" - "-"` was KILLED). Also when `--test-cpu` breaks every test run: all mutants KILLED, the equivalent one too |
| LIVED | Tests pass, or an exit code other than 1 or 2 | As expected |
| NOT COVERED | No block of the coverage run (own package's tests) covers the position | Untested package; a file behind a build tag the run did not set; generated code without tests |
| TIMED OUT | The package test exceeds (coverage run time × coefficient), default coefficient 3 | **On a fast module most mutants**: coverage took 0.6-1.0 s, so 12 to 16 of 27 mutants, real survivors included, were TIMED OUT, and Gremlins printed `Test efficacy: 100.00%`. With coefficient 30, one (a real endless loop) |
| NOT VIABLE | `go test` exits 2 | Not seen: compile errors exit 1 |
| SKIPPED | Outside the `--diff` lines | See below |
| RUNNABLE | Dry run | Not a result |

The runner therefore compiles every KILLED mutant on its own (`go test -c`) and reruns every TIMED OUT one with a generous timeout. In the lab, with coefficient 1, Gremlins reported 28 TIMED OUT; the recheck found 24 killed, 3 lived, 2 not compiling and 1 endless, and the verdict was identical to a normal run.

## Output and exit codes

- `--output <file>` writes JSON: `go_module`, `files[].file_name`, `files[].mutations[]` with `type`, `status`, `line`, `column`, plus `test_efficacy`, `mutations_coverage`, `mutants_total` (= lived + killed + not viable), `mutants_killed`, `mutants_lived`, `mutants_not_viable`, `mutants_not_covered`, `elapsed_time`, `mutator_statistics` (observed). There is **no timed-out counter and no commit**: hence `run.txt`.
- Efficacy is killed / (killed + lived); mutant coverage is (killed + lived) / (killed + lived + not covered). Neither counts timed-out mutants; efficacy counts non-compiling mutants as killed.
- Exit 0 also when: no mutant was planted (it prints "No results to report" and writes **no** JSON, observed); the run was interrupted (SIGINT: "Shutting down gracefully", exit 0, no JSON, observed). Exit 1 when tests fail before mutation (observed, no JSON) or on bad arguments. Exit 10 and 11 only from the nested thresholds.

## `--diff`

- `--diff <ref>` runs `git diff --merge-base <ref>` and plants only on added lines; everything else is SKIPPED (observed: 2 planted, 25 SKIPPED).
- An empty diff (nothing changed) plants **everything** (observed).
- It reads each hunk's added lines as one block after the leading context, so a changed line further down a hunk is SKIPPED (observed: the changed comparison on line 8 of a hunk was skipped; with Git's `diff.context=0` it was planted). The runner sets that for diff runs.
- With the module in a subfolder of the repository, every mutant is SKIPPED and it exits 0 (observed): repository paths never match module paths. The runner refuses `--diff` there.

## Not verified

- Behaviour on Linux runners and with `go.work`, nested modules or cgo.
- Run times at enterprise scale: the documentation warns that very large modules can take hours.
- Whether a mutant whose `Apply` fails is dropped from the report (source suggests it is logged and dropped; never seen).
