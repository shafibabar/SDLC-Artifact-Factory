# Contract Versioning and can-i-deploy

Self-contained detail for how a contract's version is tracked once a boundary escalates to Pact, and the deployment gate that versioning enables. Read after the parent `SKILL.md`'s "Contract Versioning" section names the two tiers (file-pinning default, Broker-backed escalation).

## Versioning Is Tied to Deployable Version, Not a Hand-Managed Contract Number

Neither tier of this skill asks anyone to hand-maintain a semantic contract version. The schema tier pins consumer expectation files to a deployed git tag/commit (`schema-based-contract-and-event-compatibility.md`). The Pact tier does the equivalent through the Broker: every published pact and every verification result is tagged with the actual application version that produced it — `$GIT_SHA` — plus the environment it targets. Compatibility becomes a lookup against real deployed versions, not "the latest contract in the repo." This is what makes cross-service compatibility checks meaningful once consumer and provider deploy on independent schedules.

## The Frugal Choice: Self-Hosted Pact Broker, Not PactFlow

CLAUDE.md's Budget and Frugality section requires open-source tooling over paid, and no external paid API without explicit approval. Pact offers two implementations of the same shared-contract-store idea:

| Option | Cost | Fit |
|---|---|---|
| **Pact Broker** (`pactfoundation/pact-broker` Docker image, Postgres-backed) | Open source, self-hosted, no license | **The frugal default for this repo** — Postgres is already this stack's primary database (CLAUDE.md Tech Stack Defaults), so the Broker's storage need adds no new operational surface |
| **PactFlow** | Commercial SaaS | Adds bi-directional contract testing (provider publishes OpenAPI, consumer publishes expectations, PactFlow diffs them with no Verifier run) at the cost of losing exact-interaction-replay guarantees. Flag against the frugality constraint before ever adopting — requires explicit approval, per CLAUDE.md |

Run the self-hosted Broker as one more service in the same OpenTofu/Helm-managed cluster this repo already provisions everything else in — not a new vendor relationship. Do not reach for PactFlow to avoid the (small, one-time) work of standing up the open-source Broker.

## can-i-deploy: The Gate Itself

Before either side deploys, ask the Broker whether the version about to go out is compatible with whatever the other side has verified against, right now:

```bash
pact-broker can-i-deploy \
  --pacticipant estate-scan-service \
  --version "$GIT_SHA" \
  --to-environment production \
  --broker-base-url "$PACT_BROKER_URL"
```

This queries the Broker's compatibility matrix — every consumer version × every provider version that has ever been verified against each other — and exits non-zero if the pairing about to ship has no successful verification on record. Wire this as a hard gate immediately before the deploy step on **both** sides' pipelines (`pact-consumer-driven-workflow.md`'s CI wiring), never as an advisory check whose failure is ignored.

This answers a question schema validation structurally cannot: not "does my code satisfy the contract at HEAD" but "is the specific version I am about to deploy compatible with the specific version currently running in production" — checked against real historical verification results.

## Pending and WIP Pacts: Don't Let Contract Evolution Break the Provider's Build Instantly

A naive Broker-gated pipeline means the moment a consumer publishes a new expectation, the provider's very next CI run turns red — before the provider team has had any chance to react. Two Pact mechanisms exist for exactly this:

- **Pending Pacts** — a newly published, never-yet-successfully-verified contract is marked non-blocking: the provider's verification step still runs it and still reports the result to the Broker, but a first failure does not fail the provider's build.
- **WIP Pacts** — extends the same non-blocking treatment to pacts still tagged to an in-progress consumer branch that hasn't reached its main branch yet.

Enable both the moment more than one consumer can publish contracts against a given provider independently — this is the difference between contract evolution happening incrementally and visibly versus an automatic build break the instant any consumer iterates. A provider verification run that goes red for a Pending Pact is a signal to look, not a blocked deploy.

## What Changes vs. the Schema-Tier's File-Pinning Workaround

The schema tier's answer to "what's actually deployed" is committing pinned expectation files and verifying both HEAD and the pinned deployed version by hand (`schema-based-contract-and-event-compatibility.md`). `can-i-deploy` is the same underlying question — verify against what's actually deployed, not just HEAD — implemented as a queryable service against real historical verification data instead of files someone has to remember to re-pin. Adopting Pact for a boundary retires that boundary's file-pinning workaround entirely; it does not run alongside it.
