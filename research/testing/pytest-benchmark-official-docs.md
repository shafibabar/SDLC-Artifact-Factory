# pytest-benchmark Official Documentation and Source
**Authors:** The pytest-benchmark project (ionelmc/pytest-benchmark)
**Domain:** Testing (performance, Python)

Accessed 2026-11-25. Latest 5.3.1 (2026-11-01 per changelog), Python >=3.10, pytest>=8.1 (https://pypi.org/pypi/pytest-benchmark/json; https://pytest-benchmark.readthedocs.io/en/latest/changelog.html). Source base: S = https://raw.githubusercontent.com/ionelmc/pytest-benchmark/v5.3.1/src/pytest_benchmark.

## Core Concepts

- `--benchmark-save NAME` writes `NNNN_NAME.json`; `--benchmark-autosave` writes id, commit and timestamp; storage default `.benchmarks`; `--benchmark-json PATH` for a full report (https://pytest-benchmark.readthedocs.io/en/latest/usage.html; .../comparing.html).
- Machine directory: system, implementation, major.minor Python, bitness, e.g. `Linux-CPython-3.12-64bit` (S/utils.py). No hardware identity in it.
- `--benchmark-compare [NUM|ID]`: no value means latest (usage page). A value becomes a filename prefix glob `<value>*.json` under the current machine directory; an existing file path is used directly (S/storage/file.py).
- No match is a warning; with `--benchmark-compare-fail` it raises `UsageError` ("requires valid --benchmark-compare") (S/session.py).
- Fail expressions `field:N%` or `field:number`; fields only `min, max, mean, median, stddev, iqr` (S/utils.py). Regression raises `PerformanceRegression`.
- **A benchmark with no baseline match cannot fail the gate** (S/session.py).
- Under xdist, benchmarking is disabled with a warning; `--benchmark-only` with disabled benchmarking is a usage error (S/session.py).
- `--benchmark-disable` runs each once; `--benchmark-skip`, `--benchmark-only` (usage page).
- `pedantic(target, args, kwargs, setup, rounds=1, warmup_rounds=0, iterations=1)` plus `teardown` (5.2.0); `setup` excludes `args`, `kwargs`, `iterations` (https://pytest-benchmark.readthedocs.io/en/latest/pedantic.html).
- 5.3.0 added precision-based stopping and `compare --between` (changelog).

## Actionable Techniques (design is this note's)

- Run base then head in one job, same runner and storage; compare by the saved number (`0001`) or a file path, not the bare name.
- Fail if any head benchmark lacks a baseline match unless declared new.
- Keep benchmarks out of xdist and coverage runs.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-performance-test, python-makefile | W3C-36 to 38 | Matching rules and silent gaps |

## Candidate New Skills/Agents

None.

## Key Terminology

Round, Iteration, Pedantic Mode, Baseline, Compare-fail.

## Caveats

- Nothing was run. [unverified] That a `*_NAME` glob argument works in practice.
- Significance testing: none found on these pages [unverified as absence].

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-37: `compare=baseline` matches nothing | Glob `baseline*.json` cannot match `0001_baseline.json` | Confirmed |
| W3C-37: gate errors every time | Usage error when compare-fail is set (exit 4 per pytest codes) | Confirmed |
| W3C-37: baseline directory keyed by OS and Python version | Yes, plus implementation and bitness | Confirmed |
| W3C-36: wrong assertion in `pedantic` example | Repository logic, not tool behaviour | Not applicable |
