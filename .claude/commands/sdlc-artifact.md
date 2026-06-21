# Command: /sdlc-artifact

## Purpose
The general-purpose skill invoker. Runs any named skill in the correct context with pre-flight validation, glossary check, and manifest registration.

Usage:
```
/sdlc-artifact <phase>/<skill-name> [arguments]
```

Examples:
```
/sdlc-artifact design/aggregate-definition StorageLocation
/sdlc-artifact design/api-contract file-domain-service
/sdlc-artifact ideate/user-story US-042
/sdlc-artifact strategy/adr use-redpanda-over-kafka
```

---

## Pre-Flight Checks (run before every skill invocation)

### 1. Manifest check
- Read `{product-root}/sdlc-manifest.json`
- Verify `current_phase` matches or precedes the skill's phase
- If skill is in a future phase: BLOCK with message:
  ```
  Cannot run design/aggregate-definition — current phase is ideate.
  Advance to the design phase with /sdlc-next before running design skills.
  ```

### 2. Phase status check
- If phase status is `review_pending`: WARN (do not block)
  ```
  Warning: The {phase} phase has pending DoD gaps. Running this skill adds work to an incomplete phase.
  Continue? (yes/no)
  ```

### 3. Dependency check
- Read the skill file; check `## Inputs` section for required prerequisite artifacts
- For each required input: verify the file exists at the specified path
- If a dependency is missing: WARN with list of missing artifacts
  ```
  Warning: The following inputs are missing:
  - artifacts/design/domain/events.md (run /sdlc-artifact design/event-catalogue first)
  Continue without these inputs? (yes/no)
  ```

### 4. Config load
- Load `{product-root}/sdlc-config.json`
- Make config available to the skill (product_name, target_language, compliance_frameworks, etc.)

---

## Skill Execution

### Step 1: Read the skill file
- Load `.claude/skills/{phase}/{skill-name}.md`
- Extract: Purpose, Inputs, Output path, Process, Template, Quality Checks

### Step 2: Gather context
- Read all listed input artifacts
- Load relevant bounded context artifacts if skill is BC-scoped
- Pass any CLI arguments to the skill (e.g. aggregate name, BC name)

### Step 3: Generate the artifact
- Follow the skill's Process steps
- Use the skill's Template as the output structure
- Substitute all `{placeholders}` with actual values from config, context, and generated content

### Step 4: Glossary validation
- Run `core/glossary validate` on the generated artifact
- FAIL: Block registration if FAIL-level findings; show report; require acknowledgment
- WARN: Show warnings; do not block

### Step 5: Write the artifact
- Write to the path specified in `## Output`
- Create parent directories if they do not exist

### Step 6: Register with manifest
- Run `core/artifact-manifest register`
- Add artifact path to `phases.{phase}.artifacts[]`
- Update `phases.{phase}.status` to `in_progress` if currently `not_started`

### Step 7: Run quality checks
- Execute each item in `## Quality Checks` as a validation pass
- Report results: ✓ (pass) / ⚠ (warning) / ✗ (fail)
- FAIL items: output a warning that DoD may be impacted

---

## Post-Execution Output

```
✓ Artifact generated: artifacts/design/domain/aggregates/storage-location.md
✓ Glossary validation: PASS (0 undefined terms)
✓ Manifest registered: design phase, in_progress
⚠ Quality check: State machine error states — WARNING (ScanError retry flow not documented)

Next suggested skill:
  /sdlc-artifact design/aggregate-definition FileProcessingJob
  /sdlc-artifact design/command-catalogue (when all aggregates complete)
```

---

## Skill Registry (for tab-completion reference)

| Skill path | Arguments | Output |
|-----------|-----------|--------|
| `core/glossary` | `validate \| add \| update` | drift report |
| `design/domain-context` | — | `artifacts/design/domain/context.md` |
| `design/event-catalogue` | — | `artifacts/design/domain/events.md` |
| `design/aggregate-definition` | `<AggregateName>` | `artifacts/design/domain/aggregates/{name}.md` |
| `design/command-catalogue` | — | `artifacts/design/domain/commands.md` |
| `design/policy-catalogue` | — | `artifacts/design/domain/policies.md` |
| `design/read-model-definition` | `<ReadModelName>` | `artifacts/design/domain/read-models/{name}.md` |
| `design/bounded-context-map` | — | `artifacts/design/bounded-contexts.md` |
| `design/ubiquitous-language-bc` | `<bc-name>` | `artifacts/design/language/{bc-name}.md` |
| `design/system-context-diagram` | — | `artifacts/design/architecture/c4-context.md` |
| `design/container-diagram` | — | `artifacts/design/architecture/c4-container.md` |
| `design/component-diagram` | `<service-name>` | `artifacts/design/architecture/c4-component-{name}.md` |
| `design/adr` | `<decision-slug>` | `artifacts/design/adrs/ADR-{NNN}-{slug}.md` |
| `design/api-contract` | `<service-name>` | `artifacts/design/contracts/{service-name}-api.md` |
| `design/event-schema` | — | `artifacts/design/contracts/event-schemas.md` |
| `design/integration-design` | — | `artifacts/design/architecture/integration-design.md` |
| `design/data-architecture` | — | `artifacts/design/data/data-architecture.md` |
| `design/canonical-data-model` | — | `artifacts/design/data/canonical-data-model.md` |
| `design/data-lineage-design` | — | `artifacts/design/data/data-lineage-design.md` |
| `design/data-classification` | — | `artifacts/design/data/data-classification.md` |
| `design/data-retention-policy` | — | `artifacts/design/data/data-retention-policy.md` |
| `design/security-architecture` | — | `artifacts/design/security/security-architecture.md` |
| `design/threat-model` | — | `artifacts/design/security/threat-model.md` |
| `design/compliance-design` | — | `artifacts/design/security/compliance-design.md` |
| `design/privacy-design` | — | `artifacts/design/security/privacy-design.md` |
| `design/access-control-model` | — | `artifacts/design/security/access-control-model.md` |
| `design/secrets-management` | — | `artifacts/design/security/secrets-management.md` |
| `design/deployment-architecture` | — | `artifacts/design/platform/deployment-architecture.md` |
| `design/multi-tenancy-design` | — | `artifacts/design/platform/multi-tenancy-design.md` |
| `design/observability-design` | — | `artifacts/design/platform/observability-design.md` |
| `design/ux-flow` | `<flow-name>` | `artifacts/design/ux/flows/{flow-name}.md` |
| `design/information-architecture` | — | `artifacts/design/ux/information-architecture.md` |
