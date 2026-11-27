# Workflows: Pull-Request Gates, the Daily Pact Run and Deployment

Self-contained. Copy when wiring contract checks into a product's pipelines. `ci-pipeline` and `cd-pipeline` own the pipelines and `python-makefile` owns the Makefile; these are the targets and steps this skill adds. Every pipeline step calls a `make` target, so a laptop and the pipeline run the same commands (`python-makefile`). Every make target below was run locally (uv 0.13.9, oasdiff 1.39.0, Redpanda v26.2.7 schema registry, pact-python 4.2.0, the `pact` command of `pact-python-cli` 1!1.0.0, Pact Broker 2.124.0), except `contract-baseline`, whose two git commands were run by hand in that form. The workflow files themselves were **not** run on GitHub Actions, and the Linux download of oasdiff was not run (the macOS archive was checked against the published checksum the same way).

Copy `../scripts/check-openapi-breaking.sh`, `../scripts/check-event-compatibility.sh` and `../scripts/write-pact-impact-report.sh` into the product's `scripts/`, and `../resources/oasdiff-severity.txt` to `api/oasdiff-severity.txt`.

## What runs when

| When | What | Blocks |
|---|---|---|
| Every pull request, in `make ci` | Provider conformance, consumer and event contract tests (`tests/contract/`, plain pytest tests) | The merge |
| Every pull request, `make contract-gates` | API description and event schemas against the deployed ones | The merge |
| Daily, and by hand | Pact: consumer tests, publish, provider verification, impact report | Nothing at merge time. The run goes red and the report lists the break |
| Each deployment | `can-i-deploy`, a question to the broker; no test runs | That deployment |
| After a deployment succeeds | `record-deployment` | |

## Make targets

### `Makefile`

```makefile
# Added to the service's Makefile (python-makefile owns the rest). None of
# these targets is part of `ci`: the gates need the deployed commit, oasdiff
# and Docker; the Pact targets need the broker and run once a day.
# GIT_SHA and GIT_BRANCH come from the environment.
DEPLOYED_REF      ?= deployed/production
BASELINE          := .contract-baseline
REGISTRY_IMAGE    := redpandadata/redpanda:v26.2.7
REGISTRY_NAME     ?= contract-registry
REGISTRY_PORT     ?= 18081
PRODUCT           := garden-plots
PACT_SERVICES     := plots rentals
PACT_ENVIRONMENTS := production

.PHONY: contract-baseline api-gate event-gate contract-gates
.PHONY: pact-consumer pact-publish pact-provider pact-report

contract-baseline: ## The API description and event schemas as they are deployed
	rm -rf $(BASELINE) && mkdir -p $(BASELINE)
	git show "$(DEPLOYED_REF):api/openapi.yaml" > $(BASELINE)/openapi.yaml
	git archive "$(DEPLOYED_REF)" schemas/events | tar -x -C $(BASELINE)

api-gate: contract-baseline ## API description against the deployed one
	bash scripts/check-openapi-breaking.sh \
		--base $(BASELINE)/openapi.yaml --revision api/openapi.yaml \
		--severity-levels api/oasdiff-severity.txt \
		--exceptions api/contract-exceptions.txt \
		--retirements api/endpoint-retirements.txt

event-gate: contract-baseline ## Event schemas against the deployed ones, on a throwaway registry
	docker run -d --name $(REGISTRY_NAME) -p 127.0.0.1:$(REGISTRY_PORT):8081 $(REGISTRY_IMAGE) \
		redpanda start --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id 0 \
		--check=false --schema-registry-addr 0.0.0.0:8081
	for attempt in $$(seq 1 60); do \
		curl -fsS http://127.0.0.1:$(REGISTRY_PORT)/subjects > /dev/null 2>&1 && break; sleep 1; \
	done; \
	bash scripts/check-event-compatibility.sh --schemas schemas/events \
		--baseline $(BASELINE)/schemas/events --registry http://127.0.0.1:$(REGISTRY_PORT); status=$$?; \
	docker rm -f -v $(REGISTRY_NAME) > /dev/null; exit $$status

contract-gates: api-gate event-gate ## Both gates: the pull-request job beside `make ci`

pact-consumer: ## Consumer Pact tests; write ./pacts (daily run)
	rm -rf pacts
	PACT_DO_NOT_TRACK=true uv run pytest pact_tests/consumer -m pact

pact-publish: ## Publish ./pacts under this commit and branch (daily run)
	uv run pact broker publish pacts --consumer-app-version "$(GIT_SHA)" --branch "$(GIT_BRANCH)"

pact-provider: ## Provider verification against the broker (daily run)
	PACT_DO_NOT_TRACK=true uv run pytest pact_tests/provider -m pact -rP

pact-report: ## One broker answer per service and environment, then the impact report
	rm -rf pact-results && mkdir pact-results
	for service in $(PACT_SERVICES); do for environment in $(PACT_ENVIRONMENTS); do \
		uv run pact broker can-i-deploy --pacticipant "$$service" --version "$(GIT_SHA)" \
			--to-environment "$$environment" --output json \
			> "pact-results/$$service.$$environment.json" 2>&1; \
	done; done; \
	bash scripts/write-pact-impact-report.sh --product $(PRODUCT) --date "$$(date -u +%F)" \
		--results pact-results > "pact-impact-$$(date -u +%F).md"
```

- Set `PRODUCT`, `PACT_SERVICES` and `PACT_ENVIRONMENTS` to the product's own; list every service and every environment.
- A product without events drops `event-gate` and the `git archive` line; a product with no deployed version yet passes `--first-release` in place of `--base` or `--baseline` and says so in its report.
- The deployed commit must come from the deployment's own record. A tag moved by the deployment is one way; the commit behind the image digest in the GitOps repository is another. If it cannot be resolved, `git show` fails and the target stops, which is correct (run: exit 128).
- `pact-consumer` removes `pacts/` first: pact-python merges into an existing file, so a deleted expectation would stay.
- `pytest` exits 5 when `-m pact` selects nothing, so a Pact target that runs no test fails (run).
- `pact-report` fails when any answer is not "verified" (run: make exits 2). With `--output json` the `can-i-deploy` command itself exits 0 whatever the answer, which is why the report script decides.
- A product that operates its own schema registry may run the declared-mode check there instead; the add-only pass still needs the throwaway one, because it registers altered copies.
- For an internal gRPC API add a target that runs `buf breaking --against ".git#ref=$(DEPLOYED_REF)"` (`../references/grpc-contracts.md`).

## Pull request

### `.github/workflows/contract-gates.yml`

```yaml
# Runs on every pull request, beside `make ci` (which already runs the provider
# conformance, consumer and event contract tests: they are ordinary pytest tests).
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
      - name: Install oasdiff (pinned, checksum checked)
        run: |
          curl -fsSL -o "$RUNNER_TEMP/oasdiff.tar.gz" \
            https://github.com/oasdiff/oasdiff/releases/download/v1.39.0/oasdiff_1.39.0_linux_amd64.tar.gz
          echo "71a85930728f367a2086077b7ae1411319421549d18473a3e8258b6451520433  $RUNNER_TEMP/oasdiff.tar.gz" | sha256sum -c -
          sudo tar -xzf "$RUNNER_TEMP/oasdiff.tar.gz" -C /usr/local/bin oasdiff
      - name: API description and event schemas against the deployed ones
        run: make contract-gates
```

## Daily Pact run

### `.github/workflows/pact-daily.yml`

```yaml
# Pact runs once a day and by hand, never on a pull request or push.
name: pact-daily
on:
  schedule:
    - cron: "23 3 * * *" # 03:23 UTC; GitHub can delay or drop a scheduled run
  workflow_dispatch: # for a commit that has to deploy before the next daily run
permissions:
  contents: read
concurrency: pact-daily
env:
  PACT_BROKER_BASE_URL: ${{ vars.PACT_BROKER_URL }}
  PACT_BROKER_USERNAME: ${{ secrets.PACT_BROKER_USERNAME }}
  PACT_BROKER_PASSWORD: ${{ secrets.PACT_BROKER_PASSWORD }}
  PACT_DO_NOT_TRACK: "true"
  GIT_SHA: ${{ github.sha }}
  GIT_BRANCH: ${{ github.ref_name }}
jobs:
  pact:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
        with:
          version: "0.13.9"
      - run: make install
      - name: Consumers record what they expect
        run: make pact-consumer
      - name: Publish the pacts
        run: make pact-publish
      - name: Providers verify and record the results
        env:
          PACT_PUBLISH_RESULTS: "true"
        run: make pact-provider
      - name: Ask the broker and write the impact report
        if: always()
        run: make pact-report
      - name: Keep the report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: pact-impact-report
          path: pact-impact-*.md
```

- The report is written from the broker's answers, and the run fails when any answer is not "verified". File the report as `artifacts/<product>/quality/test-reports/pact-impact-<date>.md` for the product owner's approval.
- When consumer and provider live in different repositories (or the consumer is a partner), each side runs its own half on its own schedule: the consumer publishes, the provider verifies. Neither checks out the other's code.
- A scheduled workflow runs only on the default branch and can be delayed or dropped by GitHub (`research/testing/github-actions-official-docs.md`). A missing report for a day is itself a finding.

## Deployment

```bash
# Before deploying <service> at <commit> to <environment>. Exit 1 refuses the deployment.
uv run pact broker can-i-deploy --pacticipant "$SERVICE" --version "$GIT_SHA" --to-environment "$ENVIRONMENT"

# ... deploy ...

# Only once the deployment can no longer fail.
uv run pact broker record-deployment --pacticipant "$SERVICE" --version "$GIT_SHA" --environment "$ENVIRONMENT"
```

Both read `PACT_BROKER_BASE_URL`, `PACT_BROKER_USERNAME` and `PACT_BROKER_PASSWORD` from the environment, as in the daily workflow.

- `can-i-deploy` answers from recorded results only. A commit no Pact run has seen is refused (`No pacts or verifications have been published for version ...`): start `pact-daily` by hand for that commit, then deploy.
- **Never add `--output json` here**: with it the command exits 0 on a refusal (run). Never `--dry-run`: it prints the refusal and exits 0 (run).
- The very first deployment goes provider first. A consumer is refused until a provider version is recorded in that environment.
- Environments other than `test` and `production` are created once: `pact broker create-environment --name staging --display-name Staging` (run; this command has no `--no-production` option, and an environment is non-production unless `--production` is given).
- docs.pact.io still shows the older `pact-broker ...` command and the `pactfoundation/pact-cli` image. The `pactfoundation/pact` image for the new command was not run for this skill; the pip-installed command was.

## The broker itself

Self-hosted and open source: `pactfoundation/pact-broker` (pinned tag) with its own PostgreSQL database, deployed like any other service of the product (`helm-chart`, `opentofu-module`). Run with image `3.2.0-pactbroker2.124.0` on `postgres:17-alpine`, PostgreSQL started first: with public read switched off, `/diagnostic/status/heartbeat` answers `401` without credentials and `200` with them. PactFlow, the hosted paid service, is not used without the product owner's approval.
