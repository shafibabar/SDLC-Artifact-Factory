# Deployment Models

Reference for `multi-tenancy-design`. Self-contained: the deployment models, how they combine, partitioning per store type, and the forces that choose between them. Read it when you have to defend a model per resource with the product's own evidence.

Vocabulary from Golding (`research/software-architecture/building-multi-tenant-saas-golding.md`). The repo's earlier names are kept as aliases so older artifacts still read.

## 1. The Models

| Model | What it means | Old alias | Isolation comes from |
|---|---|---|---|
| **Pool** | The resource is shared by tenants | shared-everything | A run-time mechanism: tenant-scoped credentials, row-level security, ACLs |
| **Bridge** | A schema (or database) per tenant inside one shared instance | shared-schema | Schema separation plus per-tenant roles; the instance, host and superuser are shared |
| **Silo** | The resource is dedicated to one tenant | — | Separate processes, storage, credentials; still needs network and credential controls |
| **Full-stack silo** | Every resource dedicated: a complete copy of the product per tenant | stamp | As silo, for everything |
| **Mixed** | Some resources pooled, others siloed | — | Per resource |
| **Tiered** | Tenants of one tier pooled, another tier siloed | — | Per tier, per resource |

A **pod** (also called a cell or stamp) is a repeatable unit of deployment holding a *group* of tenants: a pool per region, or a pool capped at N tenants, to bound blast radius and scale the fleet.

### Pool

| Axis | Assessment |
|---|---|
| Isolation | Logical, and only as good as its mechanism. With forced row-level security and tenant-scoped credentials it is enforced by the platform, not by developer discipline |
| Blast radius | The pool: a bypass of the mechanism exposes every tenant in it. A pod per region or per N tenants bounds it |
| Cost to serve | Lowest: one footprint amortised; a new tenant is rows |
| Operations | One thing to deploy, upgrade and observe; the hardest part is getting the mechanism right everywhere |
| Noisy neighbour | Present: shared planner, cache, connections. Contained with per-tenant throttling, quotas, separate queues per tier |

**Use when:** many tenants, each small; data that enforced logical isolation protects adequately; cost and onboarding speed matter; no law, contract or tier asks for dedicated resources.

### Bridge

| Axis | Assessment |
|---|---|
| Isolation | Schema separation stops accidental cross-tenant queries; the database process, host and superuser are shared |
| Blast radius | The instance: an engine breach, a compromised superuser or a backup mix-up reaches every schema in it |
| Cost to serve | Low to medium: migrations run once per schema; a ceiling on schemas per instance before tenants are spread across instances |
| Operations | Per-schema migrations and connection routing; per-tenant restore and export are simpler than in a pool |
| Noisy neighbour | Bounded but present |

**Use when:** tens to low hundreds of tenants; customers who ask for per-tenant restore, export or schema-level separation; a full silo per tenant uneconomic. Ford's granularity middle ground: the security force separates the data, not the deployable (`software-architecture-hard-parts-ford.md`).

### Silo

| Axis | Assessment |
|---|---|
| Isolation | Strongest; still needs default-deny networking and per-tenant credentials, or it leaks |
| Blast radius | One tenant |
| Cost to serve | Highest: baseline cost multiplied by tenant count, idle capacity per tenant |
| Operations | A fleet: provisioning, drift control, upgrade waves, per-tenant rollback are mandatory |
| Noisy neighbour | Eliminated for that resource |

**Use when:** a named law, contract or tier requires dedicated resources; a tenant whose load or risk can't be contained in a pool; customer-hosted or customer-key deployments. Ford's security and fault-tolerance disintegrators are the argument in architecture terms.

## 2. Mixed and Tiered

The common enterprise shape: a pooled standard tier, and siloed resources for tenants whose tier or contract pays for them. Decide:
- **Which resources** a premium or regulated tenant gets dedicated: often the database and its key first, compute second, the whole stack only if the contract asks.
- **Where the line sits:** by tier (a product decision about what each price point promises) or by named tenant (a contract).
- **Routing:** the control plane's tenant registry says where each tenant lives; the gateway or the service routes by the tenant in the token.
- **Moving between tiers:** see `control-plane-and-lifecycle.md` § 4.

Regions are a separate axis: residency is met by a pool (or pod) per region, independent of whether a tenant is pooled or siloed.

## 3. Partitioning per Store Type

Each store gets its own choice at its own grain (Golding):

| Store | Silo | Bridge | Pool |
|---|---|---|---|
| Relational (PostgreSQL) | Instance or database per tenant | Schema per tenant | Shared tables, tenant key, forced row-level security |
| Key-value / document | Table per tenant | — | Shared table, tenant in the partition key |
| Object storage | Bucket per tenant | — | Tenant prefix, prefix-scoped policies |
| Search index | Index or cluster per tenant | — | Shared index, tenant filter enforced by the query layer |
| Broker | Namespace or cluster per tenant | — | Shared topics, tenant on every event, per-principal ACLs; or a topic per tenant when consumers must be separated |
| Cache | Instance per tenant | — | Tenant-prefixed keys; flush per tenant possible |

**Partition keys in a pool** (Kleppmann, `designing-data-intensive-applications-kleppmann.md`): the tenant id leads the key, so one tenant's data is contiguous for export and deletion. Check the hot-key case explicitly: one large tenant on one partition caps its throughput and degrades its neighbours; the remedy is a compound key (tenant plus entity), or moving that tenant to a silo. Replication and failover per instance are platform-engineer's decision; name it as deferred, not as a silent gap.

**Scaling inside a silo** (Xu, `system-design-interview-xu.md`): a siloed tenant that grows still needs the ordinary toolkit within its own resources: replicas, caches, sharding. The silo removes neighbours, not scale.

## 4. Choosing: a Worked Shape

Write the decision as one row per resource:

| Resource | Model | Forces that decided it | Isolation mechanism |
|---|---|---|---|
| App compute | pool | cost, operations, onboarding | tenant context from token; per-tenant rate limits |
| Main database | pool | cost; data classification "internal" | forced RLS, non-owner role, `SET LOCAL` |
| Documents bucket | pool | cost | tenant prefix, prefix-scoped policy |
| Premium tier database | silo | tier promise (contract clause 7.2) | own instance, own credentials and key |

Then state the overall model (`pool`, `bridge`, `silo` or `mixed`) and the tiers. A row without a force, or a silo without a source, is not finished.
