# Enterprise: Harbour Tug Dispatch (several projects, tenant code, long runs, the six-hour limit)

Self-contained. Read when a repository holds several Python projects, the code serves several tenants, a full run may not fit a hosted runner, or someone proposes running the release on changed code only. **Not run:** this product's code was not executed; run times below are the product's own estimates, not measurements; the tool behaviour comes from `./01-lean-cider-press.md` and `../references/mutmut-3.8.1.md`.

## Input

A dispatch platform for tug operators in several ports (each port operator a tenant). One repository, three Python projects, each with its own `pyproject.toml` and `uv.lock`:

| Project root | Holds | Estimated full run |
|---|---|---|
| `services/dispatch/` | Tug assignment, tide windows, per-tenant rules | 7 to 9 hours (about 4,000 mutants, a slow suite) |
| `services/billing/` | Towage tariffs per port | 50 minutes |
| `libs/tidal/` | Shared tide-table maths, published as a package | 10 minutes |

The request: "Mutation testing takes all night on dispatch. For releases, just mutate what changed since the last tag, and turn off the tenant-specific rule modules: they're tested elsewhere."

## What the agent does

1. **The release run covers everything** (fixed rule). A release on changed code only is refused: the verdict script calls a changed-code run judged as a release INVALID. Run time is solved with machines, never with scope or a lower bar.
2. **One release job per project root.** Each project has its own `[tool.mutmut]` (`source_paths = ["src/dispatch"]`, and so on), its own `mutation/` record and exclusions, and its own report. The publishing workflow runs one mutation job per root (`working-directory` set per job) and the publish job of what ships `needs` each of them; `libs/tidal` gates the package it publishes.
3. **Dispatch does not fit six hours.** GitHub-hosted jobs stop at six hours, so `services/dispatch/`'s release job runs on a larger self-hosted runner (more CPUs: mutmut forks one worker per CPU). The workflow's `runs-on` for that job changes; nothing else does. Until the runner exists, the release waits.
4. **Tenant rule modules stay in.** `src/dispatch/tenants/` holds each port operator's rules; "tested elsewhere" means tested by another suite, which mutmut also runs if it reaches the code. Leaving the folder out is an exclusion only the product owner can approve; the agent lists it as pending with the claim to verify, and the release run stays INVALID until the decision. A tenant's survivor is triaged per tenant: an assignment rule for one port that no test exercises is a gap for that port only.
5. **Scheduled runs** between releases use `--changed-since` per project root, weekly here (allowed; never less than monthly), and report only. They also give an early count of what the long release run will find.
6. **The type checker** (`mypy --strict` already gates `make ci`) is **not** given to mutmut: every mutant it rejects would need its own record line, which in the lab was more than half of all mutants.

## Output

### `services/dispatch/mutation/exclusions.txt`, while the decision is open

```text
# Code left out of mutation testing, each approved by the product owner.
# <path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>   (or | pending | while awaiting approval)
# Generated code (a "generated ... DO NOT EDIT" marker) and test support under tests/ need no entry.
src/dispatch/tenants/ | folder | pending | requester says the contract suite covers it; to verify against that suite's reach
```

### The release jobs, in words

| Job | Runner | Gates |
|---|---|---|
| `mutation-dispatch` (`working-directory: services/dispatch`) | Self-hosted, 32 CPUs | The dispatch image |
| `mutation-billing` | `ubuntu-26.04` | The billing image |
| `mutation-tidal` | `ubuntu-26.04` | The `tidal` package |

A waiver is per project and per run: each project's verdict prints its own source id, and the row in that project's report names it.

### The answer, in words

"The release run stays whole-project for each of the three projects; a changed-code release run is refused by the verdict script, and lowering the bar is not an option. Dispatch's full run does not fit the six-hour limit of hosted runners, so its release job needs a larger self-hosted runner; billing and tidal run on hosted runners, each in its own job that the matching publish job needs. The tenant rule modules stay in scope: I listed `src/dispatch/tenants/` as a pending exclusion with your reason, for your approval; until then the dispatch release run reports INVALID. Weekly scheduled runs on changed functions report only. Not run: the run times are estimates."
