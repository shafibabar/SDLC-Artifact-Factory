# Throughput Micro-Tests, Stored Baselines, and the CI Regression Gate

Full standard referenced from `SKILL.md`'s "The CI Regression Gate" and "The Honest Python-vs-Go
Divergence" sections. Self-contained — reads without the parent body in context. Covers throughput
and latency micro-tests, how a baseline is saved and committed, the exact flag that fails CI on a
regression, the dedicated GitHub Actions job, what must NOT be benchmarked here, and the two honest
divergences from Go's `benchstat` gate.

---

## Throughput and Latency Micro-Tests

Two related shapes both build on the `benchmark` fixture:

**Latency** is the default reading — round time for one operation. `median` round time is the
gated latency figure.

**Throughput** is the same measurement reported as its inverse (`ops`, operations per second),
useful when the headline you care about is "how many `DataAssetClassified` envelopes can we
serialize per second on the outbox path." You do not write throughput differently — you read the
`ops` field of the same run. For a batch operation, benchmark the *whole batch* and divide, rather
than timing a single element and extrapolating, because per-element overhead (loop setup, attribute
lookups) is real and only the batch measurement captures it:

```python
# tests/benchmarks/test_outbox_batch_bench.py
import orjson


def _serialize_batch(rows: list[dict]) -> bytes:
    return b"\n".join(orjson.dumps(r) for r in rows)


def test_outbox_batch_throughput(benchmark):
    rows = [{"asset_id": i, "classification": "pii-high"} for i in range(500)]

    result = benchmark(_serialize_batch, rows)

    assert result.count(b"\n") == 499
    # Read `ops` from the printed table: envelopes/sec = ops * 500.
```

These remain **in-process** micro-tests. They measure CPU-bound serialization and pure logic — not
the rate at which the deployed service accepts real HTTP traffic. That is a different question with
a different owner (see the next section).

---

## What Must NOT Be Benchmarked Here — I/O Belongs in Load Tests

A `pytest-benchmark` micro-test times a callable in-process, repeatedly, and gates on the
distribution. That model **only works for deterministic, CPU-bound units.** The following are
explicitly out of scope and belong to `python-load-test` (Locust, black-box, against the deployed
FastAPI service through the Linkerd mesh):

| Do NOT micro-benchmark | Why | Belongs to |
|---|---|---|
| A real `asyncpg` query against Postgres | Network + connection-pool + planner variance dominates; non-deterministic round-to-round | `python-load-test` |
| An `aiokafka` produce to Redpanda | Broker acknowledgement latency and batching are not the code's CPU cost | `python-load-test` |
| An S3 / Google Drive read | External-service latency, wholly outside the process | `python-load-test` |
| A full HTTP request through the FastAPI stack | Middleware + mTLS handshake + real I/O — the *system* p99, not a unit | `python-load-test` |

The rule mirrors `go-performance-test`'s exactly: this skill's benchmark is a **build-time proxy**
for the handler's own logic, narrower in scope than any system SLO and complementary to — never a
substitute for — `python-load-test`'s real-traffic measurement. If the timed callable touches the
network, it is in the wrong skill.

---

## Saving and Committing the Baseline

`pytest-benchmark` writes runs to `.benchmarks/<machine-id>/<counter>_<name>.json`. Save a named
baseline explicitly:

```bash
# Produce the committed baseline (done deliberately, reviewed in a PR)
pytest tests/benchmarks --benchmark-only \
    --benchmark-save=baseline \
    --benchmark-min-rounds=50
```

The resulting `.benchmarks/**/*_baseline.json` is **committed to the repo**. It is regenerated only
two ways, both deliberate:

1. **Inside the same PR that knowingly trades speed for a feature** — the reviewer sees the baseline
   file change in the diff alongside the code that justifies it.
2. **On a scheduled cadence tied to tagged releases** — to keep the baseline honest against gradual
   hardware/dependency drift without becoming a rubber stamp.

**The baseline is never regenerated automatically on every merge.** Auto-saving on merge would let
each small regression quietly become the next run's "normal," so a slow decline never trips the
gate — defeating the entire point. This is the identical discipline `go-performance-test` applies to
its committed `benchstat` baseline.

To compare two saved runs by hand while diagnosing, the plugin ships a standalone CLI:

```bash
pytest-benchmark compare 0001_baseline 0002_pr-under-review --group-by name
```

---

## The Gate Flag That Fails CI

A PR run compares against the committed baseline and **fails the build** when the median regresses
past tolerance, in one invocation:

```bash
pytest tests/benchmarks --benchmark-only \
    --benchmark-compare=baseline \
    --benchmark-compare-fail=median:12% \
    --benchmark-min-rounds=50
```

- `--benchmark-compare=baseline` loads the committed `*_baseline.json` as the reference.
- `--benchmark-compare-fail=median:12%` is the gate: **if any tracked benchmark's `median` is more
  than 12% slower than its baseline, the pytest process exits non-zero and the CI job fails.** No
  silent auto-accept — the only two ways forward are a genuine fix or an explicit, reviewed
  baseline-update commit.

### Why 12%, and Why `median`

12% is the same reasoned tolerance `go-performance-test` uses: tight enough to catch a real
regression (an accidental `O(n²)` sweep, a `json`-for-`orjson` swap, a `deepcopy` on a hot path),
loose enough to absorb shared-CI-runner scheduling noise without becoming a flake factory. Gating on
`median` rather than `mean` further hardens against that noise — a few descheduled slow rounds move
`mean` but barely move `median`. The threshold is overridable per-product through
`sdlc-config-management`'s established pattern (the same mechanism `COVER_MIN` and
`mutation_test_cadence` use), not edited per-repo.

---

## The Dedicated CI Job

The sweep is too slow for the fast PR unit-test loop, so it runs as its **own** job — never wired
into the loop every other gate shares:

```yaml
# .github/workflows/perf-gate.yml
name: perf-gate
on:
  pull_request:
  schedule:
    - cron: "0 4 * * 1"      # weekly release-cadence baseline honesty check
jobs:
  benchmark-regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install
        run: |
          pip install uv
          uv sync --group dev
      - name: Run benchmark regression gate
        run: |
          uv run pytest tests/benchmarks --benchmark-only \
            --benchmark-compare=baseline \
            --benchmark-compare-fail=median:12% \
            --benchmark-min-rounds=50
```

The job is separate from the `pytest --ignore=tests/benchmarks` fast loop, so a benchmark sweep
never blocks the sub-minute PR feedback budget. A regression past 12% on `median` fails
`benchmark-regression` and blocks merge until fixed or the baseline is deliberately updated.

---

## The Two Honest Python-vs-Go Divergences

`go-performance-test` gates on **two independent signals plus a memory field** that Python's tooling
does not provide out of the box. Both gaps are stated plainly rather than papered over:

### 1. No Statistical-Significance Test in the Gate

Go's `benchstat` requires a delta to clear **both** the percentage threshold **and** `p < 0.05`
(via a Mann-Whitney U test over `-count=10` samples) before it counts as a regression; a
`~`-marked, high-`p` delta is treated as noise whatever the raw percentage says.
`--benchmark-compare-fail=median:12%` has **no such test** — it is a raw percentage comparison on a
single stat. This repo closes the gap the frugal way, not by adding tooling:

- Gate on `median` (noise-robust) rather than `mean`.
- Run on a **dedicated, quieter** job rather than contending with the full PR matrix.
- Use `--benchmark-min-rounds=50` so each figure is a distribution, not a lucky single sample.
- Accept that 12% is deliberately a touch looser than a significance-gated threshold could be,
  precisely to absorb the variance the missing U-test would otherwise filter.

A team that needs true significance tracking over time adopts `asv` (airspeed velocity) as a closer
`benchstat` analog — noted as the escalation path, not the frugal default.

### 2. No Allocation Counter

Go's `b.ReportAllocs()` gives `allocs/op` and `B/op` for free inside the same benchmark, and
`go-performance-test` gates on allocations alongside wall time. `pytest-benchmark` measures
**wall-time only** — there is no allocation field to gate. Allocation and object-churn regressions
are caught with `tracemalloc` snapshots, and that measurement lives in
`python-performance-optimization`, not in this CI gate. This skill's gate is therefore, honestly, a
**wall-time-only, percentage-threshold** gate — a real and stated reduction in scope from the Go
sibling, not a claimed equivalence.
