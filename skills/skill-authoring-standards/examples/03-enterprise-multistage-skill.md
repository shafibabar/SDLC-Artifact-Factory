# Example 3 — An enterprise multi-stage skill: every folder earning its place

Self-contained. Shows the **most complex** case: a staged procedure for a multi-tenant, high-availability, multi-region product, where all seven folders and an eval suite are justified.

## Input — the content inventory

A skill for planning a zero-downtime database migration on a multi-tenant SaaS platform (PostgreSQL, 2,000 tenants, two regions, a 99.95% availability SLO):

- when expand/contract applies versus a blue-green database switch (decision table);
- four stages, each long: (1) inventory and risk-score tenants, (2) expand the schema and dual-write, (3) backfill in tenant batches under a lag budget, (4) contract and verify;
- a risk-scoring formula: tenant size × write rate × SLA tier;
- a non-negotiable rule set: no lock above 2 s, no backfill batch over 10,000 rows, rollback possible at every stage;
- a fill-in migration plan document and a per-batch runbook entry;
- a JSON schema the plan's machine-readable section must validate against;
- three examples: a single-region nullable column; adding a NOT NULL column across 2,000 tenants; splitting a hot table across two regions with replication lag;
- the book research behind expand/contract and progressive delivery.

## Decision, content by content

| Content | Folder test | Result |
|---|---|---|
| Decision table, stage overview, "which stage next" | Decision-shaping; always needed | Body |
| Four stage procedures | Separate execution loops; stage 3 detail would crowd out stage 1 | `steps/`, one file per stage |
| Risk score | An exact calculation a model does unreliably in prose | `scripts/` (with a `tests/scripts/` test) |
| Lock / batch / rollback rules; plan JSON schema | Rigid rules and a schema the output is cross-checked against | `resources/` |
| Migration plan document, runbook entry | Copied and filled in | `templates/` |
| Three migration cases | Demonstrations from simple to hardest | `examples/` |
| Research | The books it draws on | `sources:` in frontmatter, named in prose |
| Regression cases | Golden prompts and graders | repo-root `evals/<skill>/` (never inside `skills/`) |

## Output — the layout

```
skills/zero-downtime-migration/
├── SKILL.md                       stage map + pointers
├── steps/01-inventory.md … 04-contract-and-verify.md
├── scripts/score-tenant-risk.sh
├── resources/migration-rules.md
├── resources/plan.schema.json
├── templates/migration-plan.md
├── templates/batch-runbook-entry.md
└── examples/
    ├── single-region-nullable-column.md
    ├── not-null-across-tenants.md
    └── cross-region-table-split.md
evals/zero-downtime-migration/       (repo root)
├── stage-order/{prompt.md, graders/}
└── lock-budget/{prompt.md, graders/}
```

The body points into `steps/` **one stage at a time**: "Run stage 1 by reading `./steps/01-inventory.md`; read the next stage's file only once this stage's exit check passes." That keeps later stages out of the context until they're needed: the retrieved-on-demand tier (Zhu, *Mastering Context Engineering for AI Agents*).

**Evals** prove the skill earns its place: the "lock budget" case asks for the maximum lock duration during backfill. Claude without the plugin answers generically; with the plugin it must cite the 2-second rule from `resources/`. That is the positive delta `tests/run-skill-evals.sh` requires.
