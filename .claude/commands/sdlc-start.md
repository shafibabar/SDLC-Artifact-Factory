# Command: /sdlc-start

Initialise a new product run for the SDLC Artifact Factory. Collect product configuration through an interactive questionnaire, create the product directory structure, and generate the manifest. After this command completes, the product is in the **Strategy** phase and ready for artifact generation.

---

## Step 1: Check for existing run

Check whether an `sdlc-manifest.json` already exists in the current working directory or a subdirectory. If one is found, ask:

> "A product run already exists for **{product_name}** (current phase: **{phase}**). Do you want to:
> (a) Continue that run — run `/sdlc-status` to see where you left off
> (b) Start a new product run alongside it
> (c) Cancel"

If (a): stop and suggest `/sdlc-status`. If (b): proceed. If (c): stop.

---

## Step 2: Interactive Questionnaire

Ask each question in sequence. Wait for the answer before moving to the next. Do not ask all questions at once.

---

**Q1 — Product name / codename**

> "What is the codename for this product? (lowercase, hyphen-separated — e.g. `data-estate-map`, `invoice-processor`, `patient-portal`)"

- Validate: lowercase letters, hyphens only, no spaces, no special characters
- Store as: `product_name`

---

**Q2 — Problem statement**

> "In 2–4 sentences, describe the problem this product solves. Be specific about who has the problem and what the cost of the problem is."

- Store as: `problem_statement`

---

**Q3 — Target language**

> "What is the primary programming language for this product?
>
> 1. Go (default — recommended for distributed systems)
> 2. TypeScript / Node.js
> 3. Python
> 4. Java / Kotlin
> 5. Rust
> 6. Other (specify)"

- Default: `go` if the user presses Enter without selecting
- Store as: `target_language`

---

**Q4 — Compliance frameworks in scope**

> "Which compliance frameworks must this product address? Select all that apply:
>
> 1. SOC 2
> 2. GDPR
> 3. HIPAA
> 4. ISO 27001
> 5. PCI DSS
> 6. None at this time"

- Multi-select (accept comma-separated numbers or "none")
- Store as: `compliance_frameworks` (array)

---

**Q5 — Tenancy model**

> "How will this product handle multiple customers?
>
> 1. Single-tenant — one deployment per customer (default)
> 2. Logical multi-tenant — shared infrastructure, data isolated by tenant ID
> 3. Physical multi-tenant — dedicated infrastructure per customer (strongest isolation)"

- Default: `single-tenant`
- Store as: `tenancy_model`

---

**Q6 — Deployment target**

> "Where will this product be deployed?
>
> 1. Customer's own cloud account (customer provisions via wizard)
> 2. Managed private cloud (you operate a dedicated environment per customer)
> 3. Both"

- Store as: `deployment_target`

---

**Q7 — Cloud providers**

> "Which cloud providers must the infrastructure artifacts support? Select all that apply:
>
> 1. AWS
> 2. Azure
> 3. GCP
> 4. Multi-cloud (all three)
> 5. None / on-premises only"

- Multi-select
- Store as: `cloud_providers`

---

**Q8 — Graph database**

> "Does this product require a graph data store (for entity relationships, knowledge graphs, or network analysis)?
>
> 1. No (default)
> 2. Yes — Apache AGE (PostgreSQL extension, zero extra infrastructure, default choice)
> 3. Yes — Neo4j Community (separate service, richer graph tooling — use when graph is a primary product surface)"

- Default: `none`
- Store as: `graph_database`

---

**Q9 — MongoDB hybrid store**

> "Does this product need a document store for variable-schema data (e.g. extracted entities, crawl metadata, ML output)?
>
> 1. No (default — use PostgreSQL JSONB for variable-schema needs)
> 2. Yes — add MongoDB as an optional document store for specific bounded contexts"

- Default: `false`
- Store as: `mongodb_hybrid`

---

**Q10 — Sensitive data types**

> "What categories of sensitive data will this product handle? Select all that apply:
>
> 1. PII (Personally Identifiable Information)
> 2. PHI (Protected Health Information)
> 3. Financial data (card numbers, account data)
> 4. Intellectual property / trade secrets
> 5. Government / classified data
> 6. All of the above
> 7. None"

- Multi-select
- Store as: `sensitive_data_types`

---

**Q11 — GitHub organisation** (ask only if `repo_strategy` is `multi-repo`, which is the default)

> "What is the GitHub organisation or user account where product repositories will be created? (e.g. `acme-corp` or your GitHub username)"

- Store as: `github_org`

---

**Q12 — Natural language querying**

> "Will this product include natural language querying via a locally hosted LLM?
>
> 1. No (default — add later if needed)
> 2. Yes — include LLM infrastructure requirements in deployment artifacts"

- Default: `false`
- Store as: `nl_querying`

---

## Step 3: Confirmation

Display a summary of all answers:

```
═══════════════════════════════════════════════
  SDLC Artifact Factory — New Product Run
═══════════════════════════════════════════════

Product name:        {product_name}
Target language:     {target_language}
Compliance:          {compliance_frameworks joined by ", "}
Tenancy model:       {tenancy_model}
Deployment target:   {deployment_target}
Cloud providers:     {cloud_providers joined by ", "}
Graph database:      {graph_database}
MongoDB hybrid:      {yes/no}
Sensitive data:      {sensitive_data_types joined by ", "}
GitHub org:          {github_org}
NL querying:         {yes/no}

Problem statement:
"{problem_statement}"

═══════════════════════════════════════════════
```

Ask: "Confirm and initialise? (yes / no / edit [question number])"

- If "edit N": re-ask question N, then return to confirmation.
- If "no": cancel without creating any files.
- If "yes": proceed to Step 4.

---

## Step 4: Initialise the product run

1. Create the product root directory: `./{product_name}/`
2. Write `sdlc-config.json` in the product root — validate against `schemas/sdlc-config.schema.json`
3. Write `sdlc-manifest.json` in the product root — validate against `schemas/sdlc-manifest.schema.json`:
   - `current_phase`: `"strategy"`
   - `strategy`: `{ "status": "in_progress", "started_at": "{now}", "artifacts": [], "dod_gaps": [], "warnings": [], "acknowledged_risks": [] }`
   - All other phases: `{ "status": "not_started" }`
4. Create the top-level artifact directory structure (directories only):
   ```
   {product_name}/artifacts/strategy/
   {product_name}/artifacts/ideate/requirements/
   {product_name}/artifacts/ideate/personas/
   {product_name}/artifacts/ideate/backlog/epics/
   {product_name}/artifacts/ideate/backlog/stories/
   {product_name}/artifacts/ideate/backlog/examples/
   {product_name}/artifacts/design/domain/aggregates/
   {product_name}/artifacts/design/domain/read-models/
   {product_name}/artifacts/design/language/
   {product_name}/artifacts/design/arch/components/
   {product_name}/artifacts/design/adr/
   {product_name}/artifacts/design/api/
   {product_name}/artifacts/design/events/
   {product_name}/artifacts/design/data/
   {product_name}/artifacts/design/security/
   {product_name}/artifacts/design/compliance/
   {product_name}/artifacts/design/platform/
   {product_name}/artifacts/design/ux/flows/
   {product_name}/artifacts/implement/standards/
   {product_name}/artifacts/implement/specs/
   {product_name}/artifacts/implement/features/
   {product_name}/artifacts/implement/guides/
   {product_name}/artifacts/implement/events/
   {product_name}/artifacts/implement/contracts/
   {product_name}/artifacts/data/models/
   {product_name}/artifacts/data/dashboards/
   {product_name}/artifacts/data/pipelines/
   {product_name}/artifacts/data/reports/
   {product_name}/artifacts/data/narratives/
   {product_name}/artifacts/quality/unit/
   {product_name}/artifacts/quality/integration/
   {product_name}/artifacts/quality/contracts/
   {product_name}/artifacts/quality/e2e/
   {product_name}/artifacts/quality/compliance/
   {product_name}/artifacts/quality/reports/
   {product_name}/artifacts/deploy/ci/
   {product_name}/artifacts/deploy/cd/
   {product_name}/artifacts/deploy/iac/
   {product_name}/artifacts/deploy/helm/
   {product_name}/artifacts/deploy/envs/
   {product_name}/artifacts/operations/runbooks/
   {product_name}/artifacts/validate/scenarios/
   {product_name}/artifacts/core/reviews/
   ```
5. Write a product-specific `{product_name}/CLAUDE.md` with a header referencing the factory CLAUDE.md:
   ```markdown
   # {Product Name} — Product Standards

   Extends: SDLC Artifact Factory CLAUDE.md (root)

   **Product:** {product_name}
   **Problem:** {problem_statement}
   **Initialised:** {date}
   **Current phase:** Strategy

   ## Product-Specific Ubiquitous Language
   *Bounded-context-specific terms will be added here as Event Storming produces bounded context definitions.*

   ## Product Configuration
   See `sdlc-config.json` for full configuration.
   ```

---

## Step 5: Completion message

```
═══════════════════════════════════════════════
  ✓ Product run initialised: {product_name}
═══════════════════════════════════════════════

Current phase: Strategy

Suggested next steps:
  /sdlc-artifact strategy/vision-statement    → Start with the Vision Statement
  /sdlc-artifact strategy/north-star-metric   → Define the North Star Metric
  /sdlc-artifact strategy/stakeholder-map     → Map stakeholders
  /sdlc-status                                → Check phase status at any time
  /sdlc-next                                  → Advance to Ideate when Strategy DoD is met

All artifacts will be saved to: ./{product_name}/artifacts/
═══════════════════════════════════════════════
```
