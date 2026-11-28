# Enterprise: Grain Elevator Settlements (several modules, tenant code, long runs)

Self-contained. Read for a large, multi-tenant product: several Go modules in one repository, tenant isolation logic, money arithmetic, and full runs measured in hours. **Not run:** nothing in this product was executed; tool behaviour comes from `../references/gremlins-v0.6.0.md`, and the run times are estimates the first real run must replace.

## Input

A cooperative of grain elevators settles farmers' deliveries: grading deductions, moisture shrink, drying charges, and payments, for many co-operatives (tenants) on one platform. The repository holds three modules: `settlement/`, `grading/`, `payments/`, each with its own `go.mod`. Releases go out together. The request: "The full mutation run took nine hours on a laptop. Run it on changed code only before releases, and drop the 100% thing for grading, it's just lookups."

## What the agent does

1. **No partial release run** (M7). The release run covers every package of every module; `--diff` is for scheduled runs only, and the verdict script calls a `--diff` run judged as a release INVALID.
2. **No lower bar** (M1, M4). Grading is product code; "just lookups" is not a reason a mutant cannot be killed. If grading is to be left out, that is an exclusion for the product owner, with its reason; otherwise it runs. Above 90% a waiver after review is possible for one release; at 90% or below, none.
3. **Make the full run fit**, without touching the rule:
   - one job per module, in parallel, each `make -C <module> mutation`; the publish job `needs` all three;
   - a self-hosted runner with more cores for the largest module (GitHub-hosted jobs stop at six hours; the workflow sets 350 minutes);
   - keep `timeout-coefficient` at 10 so few mutants need the runner's recheck.
4. **Scheduled runs are full per module.** Each module sits below the repository root, where Gremlins' `--diff` skips every mutant (observed); the runner refuses it there. So weekly or monthly runs cover each module fully, and still report only.
5. **Tenant isolation mutants are never recorded as equivalent.** A mutant on a tenant filter (`row.Coop == coop` → `!=`) that lives means no test proves one co-operative cannot see another's settlements: write that test.

## Output

### Publishing workflow, the mutation jobs (excerpt)

```text
jobs:
  mutation-settlement:
    uses: ./.github/workflows/mutation.yml
    with: {scope: full, module: settlement}
  mutation-grading:
    uses: ./.github/workflows/mutation.yml
    with: {scope: full, module: grading}
  mutation-payments:
    uses: ./.github/workflows/mutation.yml
    with: {scope: full, module: payments}
  publish:
    needs: [mutation-settlement, mutation-grading, mutation-payments]
```

`mutation.yml` from `../templates/workflows.md` then takes a `module` input and runs `make -C ${{ inputs.module }} mutation` on a runner labelled for the job; the scheduled branch runs the full target too (no `--diff` below the root). The validator checks a module's own files (`.gremlins.yaml`, record, Makefile); it reads workflows only under the folder it is given, so in this layout the workflow lines are checked against `../resources/checklist.md` by hand.

### Survivors an enterprise product typically meets

| Mutant | Triage |
|---|---|
| `shrink.go`: `moisture > base` → `>=` LIVED | Real gap: at exactly the base moisture no shrink applies; add the row |
| `money.go`: `cents * rate / 10000` → `cents / rate / 10000` LIVED | Tests used rate 10000 (1.0). Add a rate that separates them |
| `tenancy.go`: `row.Coop == coop` → `!=` LIVED | Never equivalent: write the cross-tenant test |
| `report.go`: `title + " — " + coop` → `-` KILLED, does not compile | Record `not-viable` (two per `+`) |
| `retry.go`: `attempt++` → `attempt--` TIMED OUT, again on recheck | Record `timeout` after reading the loop |

### The answer, in words

"The release run stays full: the product owner decided that changed-code runs are for scheduled runs only, and the release waits for the whole of every module. To make it fit, each module runs as its own job in parallel and the publish job needs all three; the largest needs a bigger self-hosted runner, because hosted jobs stop at six hours. Grading stays in scope unless you approve an exclusion with its reason; every mutant there is killed by a test or recorded, with a waiver possible only above 90% after your review. Scheduled runs here are full too, because Gremlins' changed-code mode does not work for modules below the repository root. Not run: run times are estimates until the first release run measures them."
