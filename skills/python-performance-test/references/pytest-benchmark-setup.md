# pytest-benchmark Setup, Stats, and Worked Benchmarks

Full standard referenced from `SKILL.md`'s "pytest-benchmark Micro-Benchmarks" section.
Self-contained — reads without the parent body in context. Covers the `benchmark` fixture, the
async-wrapping pattern the synchronous fixture forces, `pedantic` mode for very fast functions, the
stats fields a run reports, and two worked benchmarks for the data-estate-mapping product (an
`orjson` serialization path and a `DataAsset` domain calculation).

---

## Install and Enrollment

`pytest-benchmark` is a `pytest` plugin. Add it to the dev group only — it is never a runtime
dependency:

```toml
# pyproject.toml
[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-benchmark>=4.0",
    "orjson>=3.10",
]
```

A tracked benchmark is enrolled **by path convention, not a manifest**: any function named
`test_*` that requests the `benchmark` fixture and lives under `tests/benchmarks/test_*_bench.py`
is a tracked micro-benchmark. This mirrors `python-unit-test`'s `test_*.py` discovery convention —
layout is the policy, there is nothing extra to register.

Because a benchmark run is slow and must not run in the fast PR unit-test loop, keep the directory
separate and select it explicitly:

```bash
# fast PR loop — benchmarks excluded
pytest --ignore=tests/benchmarks

# the dedicated perf job — benchmarks only
pytest tests/benchmarks --benchmark-only
```

`--benchmark-only` deselects every non-benchmark test; `--benchmark-disable` does the inverse
(runs the benchmark bodies once for correctness without timing them), which is what the fast loop
uses if a benchmark file is ever picked up incidentally.

---

## The `benchmark` Fixture — Basic Shape

The fixture is a callable. You hand it the function under test plus its arguments; it runs a
calibration pass to pick an iteration count, discards warmup rounds, then times many rounds and
records the distribution. It returns the function's own return value so you can assert correctness
in the same test — a benchmark that computes the wrong answer fast is worthless.

```python
# tests/benchmarks/test_serialization_bench.py
import orjson
from app.domain.events import DataAssetClassified


def _envelope() -> DataAssetClassified:
    return DataAssetClassified(
        asset_id="a3f1c2d4-0000-4000-8000-000000000001",
        tenant_id="t-1029",                      # carried for audit traceability only
        classification="pii-high",
        rule_version=7,
        scored_fields=[f"col_{i}" for i in range(24)],
    )


def test_orjson_dumps_envelope(benchmark):
    envelope = _envelope()
    payload = envelope.model_dump()              # setup OUTSIDE the timed callable

    result = benchmark(orjson.dumps, payload)    # only orjson.dumps is timed

    assert orjson.loads(result)["classification"] == "pii-high"
```

Everything expensive that is *not the thing under test* — building the envelope, calling
`model_dump()` — happens before `benchmark(...)`. The timed callable is `orjson.dumps` alone. This
is the direct analog of Go's rule that setup lives outside `b.ResetTimer()`: the timed loop
contains only the operation being gated.

---

## Benchmarking Async Code — The Synchronous-Fixture Wrinkle

The `benchmark` fixture calls a **synchronous** callable. The hot paths in a FastAPI + asyncpg +
aiokafka service are `async def`. Passing a coroutine function straight to `benchmark` either
raises (the coroutine is never awaited) or, if you wrap each call in `asyncio.run`, measures the
cost of **spinning up and tearing down a fresh event loop every round** — which dwarfs and hides
the work you meant to measure.

The fix: create **one** event loop for the whole benchmark and drive the coroutine on it with a
tiny synchronous shim, so the timed callable is sync but the awaited work runs on a stable loop.

```python
# tests/benchmarks/conftest.py
import asyncio
import pytest


@pytest.fixture
def run_sync():
    """Drive a coroutine factory on a single reused event loop.

    Returns a synchronous callable suitable for the `benchmark` fixture, so the
    timed loop measures the coroutine's work — NOT repeated event-loop setup.
    """
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def _run(coro_factory, *args, **kwargs):
        return loop.run_until_complete(coro_factory(*args, **kwargs))

    yield _run
    loop.close()
```

```python
# tests/benchmarks/test_handler_bench.py
from app.application.classify import ClassifyDataAssetHandler
from tests.doubles import FakeDataAssetRepository, classify_command


def test_classify_handler_logic(benchmark, run_sync):
    # A FAST fixture double for the asyncpg repository port — no real Postgres,
    # so the timed loop is in-process business logic only, never a network hop.
    handler = ClassifyDataAssetHandler(repo=FakeDataAssetRepository())
    cmd = classify_command(field_count=24)

    result = benchmark(run_sync, handler.handle, cmd)

    assert result.classification == "pii-high"
```

The command handler is called directly against a deterministic in-memory double for its `asyncpg`
repository port. No real query, no `aiokafka` produce, no S3 read is inside the timed callable — a
real one would make the measurement non-deterministic and push it into `python-load-test`'s
territory (see `references/throughput-and-ci.md`).

---

## `pedantic` Mode — When the Function Is Very Fast

For a sub-microsecond pure function, the fixture's auto-calibration can be noisy. `benchmark.pedantic`
gives explicit control over `rounds` (how many timed samples), `iterations` (inner loop per sample,
amortizing timer resolution), and `warmup_rounds` (untimed passes to prime caches and let the
interpreter settle):

```python
def test_sensitivity_score_pedantic(benchmark):
    fields = [f"col_{i}" for i in range(24)]

    result = benchmark.pedantic(
        score_sensitivity,
        args=(fields,),
        rounds=200,          # 200 timed samples
        iterations=50,       # each sample calls the function 50x, timed as one
        warmup_rounds=10,    # 10 untimed priming rounds, discarded
    )

    assert result == "pii-high"
```

Use plain `benchmark(...)` by default; reach for `pedantic` only when a function is fast enough
that timer granularity or cold-cache effects distort the plain reading.

---

## Worked Benchmark 2 — A DataAsset Domain Calculation

The classification rule sweep is a pure function evaluated once per row in a batch — exactly the
kind of hot, deterministic unit worth gating. Its timing depends only on the input field count, not
on any I/O, so it is stable across runs.

```python
# app/domain/scoring.py
_HIGH = frozenset({"ssn", "dob", "card", "email", "phone"})


def score_sensitivity(field_names: list[str]) -> str:
    hits = sum(1 for name in field_names if any(tok in name for tok in _HIGH))
    if hits >= 3:
        return "pii-high"
    if hits >= 1:
        return "pii-low"
    return "none"
```

```python
# tests/benchmarks/test_scoring_bench.py
import pytest
from app.domain.scoring import score_sensitivity


@pytest.mark.parametrize("field_count", [8, 24, 96])
def test_score_sensitivity(benchmark, field_count):
    fields = [f"ssn_col_{i}" for i in range(field_count)]

    result = benchmark(score_sensitivity, fields)

    assert result == "pii-high"
```

Parametrizing produces one tracked benchmark **per case**, named distinctly
(`test_score_sensitivity[8]`, `[24]`, `[96]`) so a regression comparison reports each field-count
independently instead of one undifferentiated average — the Python analog of Go's named
sub-benchmarks over a table.

---

## The Stats a Run Reports

A run prints a table per benchmark and, when saved, records every field to JSON:

| Field | Meaning | Use in gating |
|---|---|---|
| `min` | Fastest observed round | Least noisy point estimate; useful sanity check |
| `median` | 50th-percentile round time | **The stat this repo gates on** — robust to a few slow outliers from a shared runner |
| `mean` | Arithmetic mean round time | Pulled around by outliers; not the gate stat |
| `stddev` | Round-time standard deviation | High stddev = noisy sample; re-run before trusting |
| `ops` | Operations per second (1/mean) | Human-readable throughput headline |
| `rounds` / `iterations` | Sample count / inner-loop count | Raise `rounds` when confirming a suspected regression |

The repo gates on **`median`** deliberately: on a shared CI runner a handful of rounds get
descheduled and run slow, which drags `mean` around but barely moves `median`. Gating on `median`
is how a percentage-threshold gate stays honest without the statistical-significance test Go's
`benchstat` provides and `pytest-benchmark` lacks — see `references/throughput-and-ci.md` for that
divergence and the exact gate flags.
