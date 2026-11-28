# Standard: Instrument Hire (routes, adapters, generated code, a pending exclusion, weekly runs)

Self-contained. Read when a product has FastAPI routes, asyncpg adapters with integration tests, generated code, or asks to run mutation more often than monthly or on part of the code only. **Not run:** this product's code was not executed; every tool behaviour it relies on was observed in the lab of `./01-lean-cider-press.md` or is stated in `../references/mutmut-3.8.1.md`. The two files under **Output** were checked with this skill's validator.

## Input

A standard product hiring out orchestral instruments by the term, one project in the `python-project-structure` layout:

| Path | Holds | Tests |
|---|---|---|
| `src/hire/domain/` | Term pricing, deposit and damage rules | Unit, parametrized |
| `src/hire/service_layer/` | Command handlers | Unit, with fakes |
| `src/hire/entrypoints/api.py` | FastAPI routes (`@router.post(...)`) | `httpx` against the app, unit |
| `src/hire/adapters/postgres.py` | asyncpg repository | `@pytest.mark.integration`, a throwaway PostgreSQL |
| `src/hire/adapters/catalogue_client.py` | Generated OpenAPI client (`# Code generated ... DO NOT EDIT.`) | None |

The request: "Set up mutation testing; only the domain matters, skip the routes and the database code. And run it every week."

## What the agent does

1. **Scope: all product code** (the fixed rule). `source_paths = ["src/hire"]`. Leaving out routes or adapters is an exclusion only the product owner can approve; the agent does not add one on request. The generated client is left out by its marker (a `do_not_mutate` entry for it only saves time) and listed.
2. **Routes.** mutmut never mutates a decorated function, so the bodies of `@router.post` handlers are never planted whatever the settings. That is stated in the report as a limit, and it is one more reason the handlers only translate and delegate: the logic they call lives in `service_layer/`, which is mutated.
3. **Adapters and the integration tests.** mutmut runs, for each mutant, the tests that reach its function, integration tests included. Without a database, the clean run fails and mutmut stops before any mutant (exit 1: the run gives no result). Two ways out, put to the product owner:
   - run the release job with the same throwaway PostgreSQL the integration tests use (each adapter mutant then reruns those tests; run time not measured);
   - or list `src/hire/adapters/postgres.py` as **pending** with the reason. Pending excludes nothing: the validator fails `do_not_mutate` for it, and the verdict stays INVALID until the product owner decides.
4. **Weekly is allowed** (more often than monthly; never less). `sdlc-config.json` gets `methodology_parameters.mutation_test_cadence: "weekly"`; the workflow's cron becomes `"41 3 * * 1"`. The release run is unchanged.
5. Setup from the templates, the validator run until clean, then `make mutation`.

## Output

### `pyproject.toml` (the mutmut table)

```toml
[tool.mutmut]
source_paths = ["src/hire"]
pytest_add_cli_args = ["--no-cov"]
do_not_mutate = ["src/hire/adapters/catalogue_client.py"]
```

### `mutation/exclusions.txt`, while the decision is open

```text
# Code left out of mutation testing, each approved by the product owner.
# <path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>   (or | pending | while awaiting approval)
# Generated code (a "generated ... DO NOT EDIT" marker) and test support under tests/ need no entry.
src/hire/adapters/postgres.py | file | pending | integration tests need PostgreSQL for every mutant; cost not yet measured
```

The validator warns that it awaits approval. If the product owner approves it, the line becomes `| approved 2026-12-02 |`, `do_not_mutate` gains the file, and the report lists it under **Approved exclusions**.

### Survivors a standard product typically meets

| Mutant | Triage |
|---|---|
| `term_price`: `weeks >= 12` → `weeks > 12` survived | Real gap: no row at exactly twelve weeks |
| `deposit_due`: `"GBP"` → `"XXGBPXX"` survived | The currency is never asserted; assert it |
| `x_record_damage__mutmut_4`: `fee = None` survived | The handler's test asserted only that no error came back; assert the fee saved |
| `damage_band`: `amount // 100` → `amount / 100` survived | `2.0 == 2` passes; add an amount that does not divide evenly |
| `release_hold`: no tests | No test calls it: write the unit test, or ask whether it is dead code; never a record |

### The answer, in words

"Every module stays in scope, routes and adapters included: leaving one out is an exclusion only you can approve, so I listed `src/hire/adapters/postgres.py` as pending with its reason; until you decide, the release run reports INVALID. The route handlers' own bodies are never mutated by mutmut (it skips decorated functions); their logic sits in the service layer, which is. Weekly scheduled runs are fine (more often than the monthly default); they report only, on the functions changed since the last release. The release run covers everything and blocks publication. The target is 100%: each mutant is killed by a test or recorded with its reason. Not run: this setup was checked by the validator only."
