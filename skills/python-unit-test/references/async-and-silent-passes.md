# Async Tests and Silent Passes

Self-contained. Use when testing `async def` code, or when a green test is suspected of checking nothing. All rows were run with pytest 9.2.0 and pytest-asyncio 1.5.0 on Python 3.14.4 (2026-11-26) unless marked.

## Configuration

`asyncio_mode = "auto"` runs `async def` tests and fixtures without a decorator. In the default `strict` mode each needs `@pytest.mark.asyncio`. Set both loop-scope options once. Pin both versions.

## An un-awaited async test does not silently pass

An `async def` test that nothing can run **fails** with "async def functions are not natively supported", both without the plugin and in strict mode without the marker. pytest has failed it since 8.4.0; older releases skipped it with a warning (official changelog, not run). Do not add a "deliberately failing test" to CI: it only keeps CI red.

## What really passes while checking nothing

| Mistake | Default result | Guard |
|---|---|---|
| `charge()` without `await` inside an async test | **Passes**, with `RuntimeWarning: coroutine ... was never awaited` | The `filterwarnings` entries in `../templates/pytest-settings.md` fail it |
| `mock.send("x")` never awaited, checked with `assert_called_once_with` | **Passes** | `assert_awaited_once_with`; the same filters |
| A mock created and never asserted | Passes | Assert the unmanaged interaction |
| `assert (1 == 2, "message")` | Passes with a warning | Filter, and the checker script |
| Parametrize with no rows | Skipped, run green | `empty_parameter_set_mark = "fail_at_collect"` |
| `Test*` class with `__init__` | Not collected, run green | Filter |
| Two tests with one name | First never runs | Checker script; a linter (not run here) |
| Assert inside a `pytest.raises` block after the raising call | Never runs | Checker script |
| `pytest.raises(Exception)` | Passes for any error | Exact class |
| Test returns a value instead of asserting | Fails since pytest 8.4 | None needed |

The filters make a forgotten `await` fail because Python reports it when the coroutine is discarded. A coroutine that is still referenced when the test ends was not tried.

## Fakes in async code

An async port needs `async def` methods on its fake. To make two use cases interleave, have the fake yield once (`await asyncio.sleep(0)`) between read and write, and check the version on write. `asyncio.sleep` with any other value is a real wait: do not use it.

## Selection and exit codes

pytest exits 5 when nothing is collected or everything is deselected: treat it as failure, never mask it. `-m` with an unregistered marker exits 4 under strict markers.
