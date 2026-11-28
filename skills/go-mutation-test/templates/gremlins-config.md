# Gremlins Configuration

Self-contained. Copy when setting up mutation testing in a Go product. The file sits at the module root, which is also the repository root. `run-go-mutation.sh` always passes it to Gremlins with `--config`, because Gremlins otherwise reads the first `.gremlins.yaml` it finds in `/etc/gremlins`, `~/.config/gremlins/gremlins` or `~/.gremlins` ahead of the module's (observed: a user-level file replaced the module's settings).

Run as written with Gremlins v0.6.0 on Go 1.27.4 (2026-11-28): every key below was read, and the mutant types switched on here were planted.

### `.gremlins.yaml`

```yaml
# .gremlins.yaml: Gremlins v0.6.0 settings, read by run-go-mutation.sh through --config.
# The verdict is check-go-mutation.sh's (decision D048), never Gremlins' own scores.
unleash:
  # Off (0). Gremlins' ratios leave out timed-out and not-covered mutants, count a mutant
  # that does not compile as killed, and a value of 100 fails even a perfect run.
  threshold:
    efficacy: 0
    mutant-coverage: 0
  # Each mutant may take 10x the coverage run before it counts as TIMED OUT (default 3,
  # which on a fast module marks real survivors TIMED OUT). The runner rechecks each one.
  timeout-coefficient: 10
  # Speed only: the verdict script leaves these out by itself and lists them.
  exclude-files:
    - "^internal/test/"
    - "_moq\\.go$"
mutants:
  arithmetic-base:
    enabled: true
  conditionals-boundary:
    enabled: true
  conditionals-negation:
    enabled: true
  increment-decrement:
    enabled: true
  invert-assignments:
    enabled: true
  invert-bitwise:
    enabled: true
  invert-bwassign:
    enabled: true
  invert-logical:
    enabled: true
  invert-loopctrl:
    enabled: true
  invert-negatives:
    enabled: true
  remove-self-assignments:
    enabled: true
```

## What not to write

| Line | What happens | Instead |
|---|---|---|
| `threshold-efficacy: 60` under `unleash` | Not a key: ignored without a warning (observed) | No percentage at all; the thresholds above stay 0 |
| `excludes:` with `file:line` entries | Not a key: ignored (observed) | Record the mutant in `mutation/mutant-record.txt` |
| `//gremlins:disable-next-line` in Go code | Gremlins has no suppression comment; the mutant was still planted (observed) | Record the mutant |
| `test-cpu: 2` or `--test-cpu 2` | Gremlins passes `-cpu 2` as one argument, `go test` fails at setup and **every** mutant reports KILLED (observed) | Leave it out |
| `diff:` or `dry-run:` | A diff run is partial; a dry run tests nothing | The runner adds `--diff` for scheduled runs only |
| `coverpkg:` without `integration: true` | Coverage then counts other packages' tests, but each mutant runs only its own package's tests, so it reports LIVED rather than NOT COVERED | Leave both out: each package proves itself, as the branch gate requires |
| An `exclude-files` pattern for a product package | Code leaves the gate unseen | An approved entry in `mutation/exclusions.txt`, and the pattern only after approval |

Patterns in `exclude-files` are regular expressions matched against module-relative paths, because the runner never passes a path argument (with one, names become relative to that path, observed). Generated files need no pattern: the verdict script leaves out any file with the `// Code generated ... DO NOT EDIT.` marker. A pattern only saves the time of planting them.
