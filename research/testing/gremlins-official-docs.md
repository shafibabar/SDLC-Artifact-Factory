# Gremlins Official Documentation and Source
**Authors:** The go-gremlins project (gremlins.dev, go-gremlins/gremlins)
**Domain:** Testing (mutation, Go)

Accessed 2026-11-25. Latest release v0.6.0, 2025-12-06 (https://api.github.com/repos/go-gremlins/gremlins/releases/latest). Apache-2.0; pre-1.0, configuration may change between minor releases; suited to "smallish" modules, very large ones can take hours (https://github.com/go-gremlins/gremlins).

## Core Concepts

- `gremlins unleash [path]`; **at most one path argument** (https://raw.githubusercontent.com/go-gremlins/gremlins/v0.6.0/cmd/unleash.go).
- Flags: `--tags`, `--coverpkg`, `--exclude-files/-E` (regexp), `--diff/-D`, `--integration/-i`, `--dry-run`, `--workers`, `--test-cpu`, `--timeout-coefficient`, `--output/-o` (JSON), `--output-statuses/-S`, `--threshold-efficacy`, `--threshold-mcover` (https://gremlins.dev/latest/usage/commands/unleash/).
- Operators on by default (5): arithmetic-base, conditionals-boundary, conditionals-negation, increment-decrement, invert-negatives. Off (6): invert-assignments, invert-bitwise, invert-bwassign, invert-logical, invert-loopctrl, remove-self-assignments. No statement-removal operator is listed. (https://gremlins.dev/latest/usage/mutations/)
- Statuses: KILLED, LIVED, NOT COVERED, TIMED OUT, NOT VIABLE, SKIPPED, RUNNABLE. Efficacy = killed/(killed+lived). Mutant coverage = (killed+lived)/(killed+lived+not covered). (unleash page)
- Config file `.gremlins.yaml`; keys nest as `unleash.threshold.efficacy`, `unleash.threshold.mutant-coverage`, `unleash.exclude-files`, `unleash.output`, `mutants.<name>.enabled`; env prefix `GREMLINS_`. (https://gremlins.dev/latest/usage/configuration/; https://raw.githubusercontent.com/go-gremlins/gremlins/v0.6.0/internal/configuration/configuration.go)
- Exit 10 for efficacy, 11 for mutant coverage; threshold 0 disables. (unleash page)

### Source behaviour at v0.6.0
Files under https://raw.githubusercontent.com/go-gremlins/gremlins/v0.6.0/internal/ (`report/report.go`, `engine/engine.go`, `engine/executor.go`).
- The check fails when value **<=** threshold, so **a threshold of 100 fails even a perfect run**.
- TIMED OUT is excluded from both ratios and `mutants_total`; JSON has no timed-out counter, only per-mutation `status`.
- `mutants_total` is lived+killed+not viable in code, although the docs say NOT VIABLE is excluded from calculations.
- Test exit 1 means KILLED, 2 NOT VIABLE, other codes and non-exit errors LIVED.
- With no mutants it logs "No results to report", writes no JSON and succeeds.
- SKIPPED is set for code outside `--diff`. No suppression comment appears in these files.
- Default timeout coefficient 3.
- A `//nomutant` directive is only an **open** pull request (opened 2026-04-28): https://github.com/go-gremlins/gremlins/pull/279.

## Actionable Techniques (design is this note's, for D048 B)

- Pin v0.6.0 (`go install .../cmd/gremlins@v0.6.0`, https://gremlins.dev/latest/install/).
- Enable all eleven operators.
- Do not use the built-in thresholds for 100%. A tested script reads `--output` JSON and fails on a missing report, or any LIVED, NOT COVERED or TIMED OUT mutation without a recorded reason; review NOT VIABLE and SKIPPED too.
- Keep the equivalent-mutant register outside the tool, keyed by file, line, column and type; revalidate when lines move.
- Run per package or per module if large; do not rely on `--diff` for the full gate.
- Use `--exclude-files` only for generated code or approved exclusions.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-mutation-test | W3B-20 to 22; D048 B | Real keys, exit codes, gaps in the gate |

## Candidate New Skills/Agents

None.

## Key Terminology

Mutant, Efficacy, Mutant Coverage, Timed Out, Not Viable.

## Caveats

- Behaviour of the operator list covers only what Gremlins plants; "every planted fault" cannot exceed it.
- [unverified] Nothing was run. How compile errors map to exit codes on go1.27.4 (a build failure exiting 1 would count as KILLED).
- [unverified] go1.27.4 compatibility; that `latest` docs match v0.6.0 in every detail.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-20: flat `threshold-efficacy` config key | Documented key is nested `unleash.threshold.efficacy`; the flat name is a CLI flag | Confirmed |
| W3B-20: `excludes` list | Key is `unleash.exclude-files` | Confirmed |
| W3B-20: `//gremlins:disable-next-line` | Not in docs or the source read | Confirmed by absence |
| W3B-20: report written without a flag | JSON needs `--output`/`unleash.output` | Confirmed |
| Narrative 3: `threshold-mcover: 0` ignores uncovered code | 0 disables; efficacy ignores uncovered | Confirmed |
| W3B-21: killed/(killed+lived), ignores uncovered | Yes | Confirmed |
| W3B-22: two path arguments | Rejected | Confirmed |
| W3B-22: "removes a statement" operator | None listed | Confirmed (the skill claim is unsupported) |
