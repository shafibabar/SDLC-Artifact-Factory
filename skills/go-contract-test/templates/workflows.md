# Workflows: Pull-Request Gates, the Daily Pact Run and Deployment

Self-contained. Copy when wiring contract checks into a product's pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines; these are the steps this skill adds to them. The commands inside the steps were run locally for this skill (oasdiff 1.39.0, Redpanda v26.2.7 schema registry, pact-go v2.9.1, `pactfoundation/pact-cli:1.5.0.5`, Pact Broker 2.124.0). The workflow files themselves were **not** run on GitHub Actions, and `git archive` and the Linux install of the native library were not run.

Copy `./scripts/check-openapi-breaking.sh`, `./scripts/check-event-compatibility.sh` and `./scripts/write-pact-impact-report.sh` into the product's `scripts/`, and `./resources/oasdiff-severity.txt` to `api/oasdiff-severity.txt`.

## What runs when

| When | What | Blocks |
|---|---|---|
| Every pull request, in `make ci` | Provider conformance, consumer and event contract tests (plain Go tests) | The merge |
| Every pull request, this gates job | API description and event schemas against the deployed ones | The merge |
| Daily, and by hand | Pact: consumer tests, publish, provider verification, impact report | Nothing at merge time. The run goes red and the report lists the break |
| Each deployment | `can-i-deploy`, a question to the broker; no test runs | That deployment |
| After a deployment succeeds | `record-deployment` | |

## Pull request

### `.github/workflows/contract-gates.yml`

```yaml
# Runs on every pull request, beside `make ci` (which already runs the provider
# conformance, consumer and event contract tests: they are ordinary Go tests).
name: contract-gates
on:
  pull_request:
permissions:
  contents: read
jobs:
  gates:
    runs-on: ubuntu-24.04
    env:
      # The commit that is in production. Here: a tag the deployment moves.
      DEPLOYED_REF: deployed/production
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # the deployed commit must be reachable
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Install oasdiff (pinned)
        run: go install github.com/oasdiff/oasdiff@v1.39.0
      - name: API description against the deployed one
        run: |
          git show "$DEPLOYED_REF:api/openapi.yaml" > "$RUNNER_TEMP/deployed-openapi.yaml"
          ./scripts/check-openapi-breaking.sh \
            --base "$RUNNER_TEMP/deployed-openapi.yaml" --revision api/openapi.yaml \
            --severity-levels api/oasdiff-severity.txt \
            --exceptions api/contract-exceptions.txt \
            --retirements api/endpoint-retirements.txt
      - name: Event schemas against the deployed ones
        run: |
          docker run -d --name schema-check -p 127.0.0.1:18081:8081 redpandadata/redpanda:v26.2.7 \
            redpanda start --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id 0 \
            --check=false --schema-registry-addr 0.0.0.0:8081
          for attempt in $(seq 1 60); do
            curl -fsS http://127.0.0.1:18081/subjects > /dev/null && break
            sleep 1
          done
          mkdir -p "$RUNNER_TEMP/deployed"
          git archive "$DEPLOYED_REF" schemas/events | tar -x -C "$RUNNER_TEMP/deployed"
          ./scripts/check-event-compatibility.sh --schemas schemas/events \
            --baseline "$RUNNER_TEMP/deployed/schemas/events" --registry http://127.0.0.1:18081
```

- A product without events drops the second step; a product with no deployed version yet passes `--first-release` in place of `--base` or `--baseline` and says so in its report.
- The deployed commit must come from the deployment's own record. A tag moved by the deployment is one way; the commit behind the image digest in the GitOps repository is another. If it cannot be resolved the step fails, which is correct.
- A product that operates its own schema registry may run the declared-mode check against that registry's compatibility endpoint instead; the add-only pass still needs a throwaway registry, because it registers altered copies.
- For an internal gRPC API the same job runs `buf breaking --against ".git#ref=$DEPLOYED_REF"` (`../references/grpc-contracts.md`).

## Daily Pact run

### `.github/workflows/pact-daily.yml`

```yaml
# Pact runs once a day and by hand, never on a pull request or push. It needs
# the Pact native library and the broker, which `make ci` must not need.
name: pact-daily
on:
  schedule:
    - cron: "23 3 * * *" # 03:23 UTC; GitHub can delay or drop a scheduled run
  workflow_dispatch: # for a commit that has to deploy before the next daily run
permissions:
  contents: read
concurrency: pact-daily
env:
  PACT_BROKER_BASE_URL: ${{ vars.PACT_BROKER_URL }} # read by the pact-broker command
  PACT_BROKER_URL: ${{ vars.PACT_BROKER_URL }} # read by the provider test
  PACT_BROKER_USERNAME: ${{ secrets.PACT_BROKER_USERNAME }}
  PACT_BROKER_PASSWORD: ${{ secrets.PACT_BROKER_PASSWORD }}
  PACT_DO_NOT_TRACK: "true"
  PACT_CLI: pactfoundation/pact-cli:1.5.0.5
  GIT_SHA: ${{ github.sha }}
  GIT_BRANCH: ${{ github.ref_name }}
jobs:
  pact:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Install the Pact native library (pinned)
        run: |
          go install github.com/pact-foundation/pact-go/v2@v2.9.1
          sudo "$(go env GOPATH)/bin/pact-go" -l INFO install
      - name: Consumers record what they expect
        run: make pact-consumer
      - name: Publish the pacts
        run: |
          docker run --rm -v "$PWD/pacts:/pacts:ro" \
            -e PACT_BROKER_BASE_URL -e PACT_BROKER_USERNAME -e PACT_BROKER_PASSWORD -e PACT_DO_NOT_TRACK \
            "$PACT_CLI" pact-broker publish /pacts --consumer-app-version "$GIT_SHA" --branch "$GIT_BRANCH"
      - name: Providers verify and record the results
        env:
          PACT_PUBLISH_RESULTS: "true"
        run: make pact-provider
      - name: Ask the broker about every service and environment
        if: always()
        run: |
          mkdir -p pact-results
          for service in signup classes; do
            for environment in production; do
              docker run --rm \
                -e PACT_BROKER_BASE_URL -e PACT_BROKER_USERNAME -e PACT_BROKER_PASSWORD -e PACT_DO_NOT_TRACK \
                "$PACT_CLI" pact-broker can-i-deploy --pacticipant "$service" --version "$GIT_SHA" \
                --to-environment "$environment" --output json \
                > "pact-results/$service.$environment.json" 2>&1 \
                || echo "$service: not deployable to $environment, see the report"
            done
          done
      - name: Write the impact report
        if: always()
        run: |
          ./scripts/write-pact-impact-report.sh --product step-studio --date "$(date -u +%F)" \
            --results pact-results > "pact-impact-$(date -u +%F).md"
      - name: Keep the report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pact-impact-report
          path: pact-impact-*.md
```

### `Makefile`

```makefile
# Added to the service's Makefile (go-makefile owns the rest). Neither target
# is part of `ci`: both need the Pact native library, and the provider one
# needs the broker.
.PHONY: pact-consumer pact-provider

pact-consumer: ## Consumer Pact tests; write ./pacts (daily run)
	go test -tags pact -count=1 -run '^TestPact' ./internal/signup/...

pact-provider: ## Provider verification against the broker (daily run)
	go test -tags pact -count=1 -run '^TestPact' ./internal/classes/...
```

- List every service and every environment in the two loops.
- The report is written from the broker's answers, and the run fails when any answer is not "verified". File the report as `artifacts/<product>/quality/test-reports/pact-impact-<date>.md` for the product owner's approval.
- When consumer and provider live in different repositories (or the consumer is a partner), each side runs its own half on its own schedule: the consumer publishes, the provider verifies. Neither checks out the other's code.
- A scheduled workflow runs only on the default branch and can be delayed or dropped by GitHub (`research/testing/github-actions-official-docs.md`). A missing report for a day is itself a finding.

## Deployment

```bash
# Before deploying <service> at <commit> to <environment>. Exit 1 refuses the deployment.
pact-broker can-i-deploy --pacticipant "$SERVICE" --version "$GIT_SHA" --to-environment "$ENVIRONMENT"

# ... deploy ...

# Only once the deployment can no longer fail.
pact-broker record-deployment --pacticipant "$SERVICE" --version "$GIT_SHA" --environment "$ENVIRONMENT"
```

Both run from the pinned `pactfoundation/pact-cli` image with `PACT_BROKER_BASE_URL`, `PACT_BROKER_USERNAME` and `PACT_BROKER_PASSWORD` set, as in the daily workflow.

- `can-i-deploy` answers from recorded results only. A commit no Pact run has seen is refused (`No pacts or verifications have been published for version ...`): start `pact-daily` by hand for that commit, then deploy.
- The very first deployment goes provider first. A consumer is refused until a provider version is recorded in that environment.
- Environments other than `test` and `production` are created once: `pact-broker create-environment --name staging`.
- Never `--dry-run`: it prints the refusal and exits 0.

## The broker itself

Self-hosted and open source: `pactfoundation/pact-broker` (pinned tag) with its own PostgreSQL database, deployed like any other service of the product (`helm-chart`, `opentofu-module`). Observed with image `3.2.0-pactbroker2.124.0`: the container exits with status **0** when PostgreSQL is not ready yet, so wait for the database first; with public read switched off, `/diagnostic/status/heartbeat` answers `401` without credentials. PactFlow, the hosted paid service, is not used without the product owner's approval.
