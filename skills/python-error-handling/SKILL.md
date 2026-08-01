---
name: python-error-handling
description: >
  Teaches the backend-engineer Python error handling — custom Exception
  subclasses carrying structured attributes (class NotFoundError(DomainError)),
  native chaining via raise ... from cause (the %w analog), isinstance() checks
  replacing errors.Is/As, and the raise-deep/catch-once-at-the-transport-edge
  placement rule via a single boundary handler. The Python analog of
  go-error-handling.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, errors, exceptions, exception-chaining, raise-from, isinstance, domain-error, fastapi, exception-handler, boundary, logging]
produces: python-error-handling
domain: backend
status: stable
related: [go-error-handling, python-domain-model, python-fastapi-handler]
---

# Python Error Handling

## Purpose

This is the Python analog of `go-error-handling`: the cross-cutting standard the domain, repository, service, and handler `python-*` skills defer to for exception taxonomy, chaining, and where errors are raised versus caught. Where Go treats errors as ordinary return values checked with `if err != nil`, Python treats them as **control flow** — an exception unwinds the stack until something catches it. That difference shapes everything below: you do not check-and-return at every layer, you `raise` deep and let a single edge catch and translate.

The rule is absolute: **never swallow an exception.** A bare `except: pass`, or an `except Exception` that logs and continues as if nothing happened, is a defect unless a comment justifies exactly why the failure is provably irrelevant. Handling means one of: let it propagate, translate it (re-raise a domain exception `from` the original), or — rarely, with justification — deliberately catch-and-continue.

---

## The Exception Hierarchy

Every application-owned error is a subclass of one project-root base, `DomainError`, and carries **structured attributes**, not just a message string — the Python equivalent of Go's typed errors. A caller that needs the failing entity's id reads `err.asset_id`, never re-parses the message.

```python
class DomainError(Exception):
    """Base for every business-rule failure this service raises."""

class NotFoundError(DomainError):
    def __init__(self, asset_id: str, tenant_id: str) -> None:
        super().__init__(f"data asset {asset_id} not found")
        self.asset_id = asset_id
        self.tenant_id = tenant_id
```

Pick the subclass mechanically by failure kind, not by style. Full hierarchy — `NotFoundError`, `ValidationError` (the domain one, distinct from Pydantic's `ValidationError`), `ConflictError`, `OptimisticConcurrencyError`, `AuthorizationError` — with structured attributes and the selection table: `references/exception-hierarchy.md`.

Infrastructure exceptions (`asyncpg.PostgresError`, `aiokafka` errors) are **never** their own vocabulary above the repository — translate them into a `DomainError` at the boundary they cross, so nothing above persistence catches a driver type.

---

## Chaining — `raise ... from cause` (the `%w` analog)

When you translate a low-level exception into a domain one, preserve the original with `raise NewError(...) from cause`. This sets `__cause__` on the new exception — Python's native chaining, the direct analog of Go's `fmt.Errorf("...: %w", err)`:

```python
try:
    row = await conn.fetchrow(sql, asset_id, tenant_id)
except asyncpg.PostgresError as exc:
    raise RepositoryError(f"loading data asset {asset_id}") from exc
```

Never `raise NewError(str(exc))` — flattening the original into a string severs the chain and loses the traceback, the Python twin of Go's `errors.New(err.Error())` anti-pattern. Worked chaining examples and `__cause__` inspection: `references/exception-hierarchy.md`.

---

## Inspection — `isinstance()` replaces `errors.Is`/`errors.As`

To branch on an error's kind, use `isinstance(err, NotFoundError)` — it matches the class **and every subclass**, so catching `DomainError` catches the whole family. This replaces both `errors.Is` (identity) and `errors.As` (type extraction) at once: because the matched object *is* the typed exception, its structured attributes are already in hand — no separate extraction step.

**Honest divergence to know:** `isinstance()` walks the **class hierarchy**, not the `__cause__` chain. Go's `errors.Is`/`errors.As` walk the *wrap chain*, matching a sentinel buried under several `%w` layers. Python's `isinstance` does **not** — a `NotFoundError` wrapped inside a `RepositoryError` is *not* `isinstance(err, NotFoundError)`. If you must match against a wrapped cause you walk `__cause__` yourself. The standard avoids this entirely: translate at each boundary so the top-most exception already *is* the kind callers branch on. The chain-walking helper for the rare case: `references/exception-hierarchy.md`.

---

## Raise Deep, Catch Once at the Transport Edge

Domain and service code **raises** `DomainError` subclasses freely and catches nothing it cannot fully resolve. There is exactly **one** place that catches the family: a single FastAPI/Starlette exception handler registered at the app boundary (`@app.exception_handler(DomainError)`) — the analog of Go's HTTP `Recoverer`-plus-`writeDomainError` seam. It maps each exception kind to an HTTP status and a standard error envelope; the route handlers themselves build no error responses. Placement rules, the handler code, the kind→status table, and the error-envelope shape: `references/boundary-mapping.md`.

A `try/except` anywhere *between* the raise site and that edge is a smell — almost always either a swallowed failure or a translation that belongs one layer down at the infrastructure boundary. The only sanctioned intermediate catch is `asyncpg`/`aiokafka` → `DomainError` translation at the repository/consumer edge.

---

## Never Leak a Traceback

An uncaught non-`DomainError` exception must become an **opaque HTTP 500** with a correlation id — never a stack trace, exception message, SQL fragment, file path, or variable value in the response body. Starlette will surface a traceback to the client when the app runs with `debug=True`; production runs `debug=False` and relies on a catch-all `@app.exception_handler(Exception)` that logs the full context server-side and returns only `{"error": {"code": "internal", "trace_id": "..."}}`. The traceback is for the log, never the wire. Catch-all handler and the log-vs-response split: `references/boundary-mapping.md`.

---

## Log Once at the Boundary

**Named anti-pattern: log-and-return duplication** — the Python form is *log-and-re-raise*: catching, `logger.exception(...)`, and re-raising at every layer, so one failure produces N near-identical log lines. The rule: intermediate layers translate-and-`raise` (or just let it propagate) and log nothing; exactly one place — the boundary exception handler that owns the request — calls `logger`. Log **with context** (tenant id, asset id, `trace_id` from the `contextvars.ContextVar`) and **never** PII, secrets, connection strings, or tokens. Worked wrong/right and the structured-logging call: `references/boundary-mapping.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No swallowed exceptions | Every exception propagates, translates, or is justified-caught with a comment | `except: pass`; log-and-continue |
| Structured, typed hierarchy | `DomainError` subclasses carrying attributes (`err.asset_id`) | Raising bare `Exception`; data only in the message string |
| Chain preserved | `raise NewError(...) from cause`; `__cause__` intact | `raise NewError(str(exc))`; `raise` with no `from` when translating |
| Inspection by class | `isinstance(err, NotFoundError)` on the top-most exception | Matching on `str(err)`; expecting `isinstance` to walk `__cause__` |
| Infra translated at its boundary | `asyncpg`/`aiokafka` errors become `DomainError` at the repository/consumer | A driver exception reaching a route handler |
| Catch once at the edge | One `@app.exception_handler(DomainError)`; deep code only raises | `try/except` scattered between raise site and edge |
| No traceback leak | Opaque 500 + `trace_id`; `debug=False` in prod | Stack trace, message, or SQL in the response body |
| Log once, no secrets | One `logger` call at the boundary, context but no PII/secrets | Log-and-re-raise at N layers; a token/DSN/PII in a log line |

---

## Anti-Patterns

- **Swallowing** — `except Exception: pass`, or logging and continuing as if the call succeeded.
- **Stringly-typed errors** — `raise DomainError(f"...{id}")` with the id only in the text; give the exception an attribute.
- **Breaking the chain** — `raise NewError(str(exc))` or `raise NewError() from None` when the cause was real; both discard the original traceback.
- **Expecting `isinstance` to walk `__cause__`** — matching a wrapped cause by type; translate at each boundary instead so the top exception is the right kind.
- **Catch-in-the-middle** — a `try/except` between the raise site and the single edge handler, absorbing or re-mapping what the edge already handles.
- **Leaking a driver exception across a boundary** — an `asyncpg.PostgresError` reaching the service or handler layer; translate it at the repository.
- **Traceback on the wire** — returning the exception message or stack trace to the client; that is a 500 with an opaque body plus a `trace_id`.
- **Log-and-re-raise duplication** — logging at every layer on the way up instead of once at the owning boundary.

---

## Output Format

Produces Python source (an exception module per bounded context plus a single boundary handler) and tests asserting exception kind:

```
src/<context>/domain/errors.py        (DomainError base + typed subclasses with structured attributes)
src/<context>/adapters/errors.py      (RepositoryError etc. — infra translation targets, rare)
src/app/exception_handlers.py         (the single @app.exception_handler(DomainError) + catch-all Exception handler)
tests/.../test_*_errors.py            (pytest.raises asserting the kind and its attributes, per python-unit-test)
```
