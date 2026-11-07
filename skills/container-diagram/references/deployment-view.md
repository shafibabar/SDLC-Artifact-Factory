# The Deployment View

The section of the container diagram artifact that says where each container runs, how many instances, in which environment (D047-13). Self-contained. Sources: `research/software-architecture/c4-model-brown.md` (the Deployment diagram: deployment nodes, infrastructure nodes, one per environment), `research/software-architecture/documenting-software-architectures-clements.md` (allocation views, the variability guide, mapping between views), `research/software-architecture/system-design-interview-xu.md` (load balancers, CDNs, read replicas as named scaling tiers).

There is no separate deployment-diagram artifact or skill. platform-engineer turns this section into Helm charts, OpenTofu modules and manifests at Deploy (`kubernetes-manifest`); it reads it and doesn't redraw it.

---

## 1. When It Is Drawn

After the container view and after `multi-tenancy-design`, because the tenancy model decides the shape. If the tenancy design doesn't exist yet, draw everything the NFRs already fix (environments, the regions data residency requires, clusters and namespaces, infrastructure nodes, instances and counts) and mark only the tenant dimension *pending multi-tenancy-design*, with an open question; never fill it with an assumed model.

## 2. Vocabulary (Brown)

| Term | Meaning | Examples |
|---|---|---|
| Environment | One deployment of the system | production, staging |
| Deployment node | A place containers run, nested | cloud region → Kubernetes cluster → namespace; a managed PostgreSQL service |
| Infrastructure node | Supporting infrastructure we configure | load balancer, ingress, CDN, DNS, firewall |
| Container instance | A container from the container view running on a node, with a count | `Appointments API × 3` |

## 3. One per Environment That Differs

Production always. Staging (or another) only if its shape differs: fewer nodes, a shared database server, no second region. If staging is production at smaller counts, say that in one line instead of drawing it.

## 4. Tenancy: Only What multi-tenancy-design Chose (D047-7)

There is no plugin default. The section shows the chosen model:

| Model chosen | In the deployment view |
|---|---|
| Single tenant, or no tenancy | One deployment; no tenant dimension |
| Pooled | One set of instances; the tenant is a column, a schema or a key, shown in the variability guide, not as copies |
| Stamp per tenant (silo) | One stamp drawn once, with the instance list, and "× one per tenant" stated in the variability guide |
| Mixed (pooled, with dedicated stamps for some) | The pooled deployment and one dedicated stamp, each labelled with who it serves |
| Per region | One stamp per region, each with its data-residency constraint |

Whatever the model, the broker and databases follow it: never "one shared broker" or "a stamp per tenant" by assumption.

## 5. Mapping Table

Every container in the container view, once per environment:

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Appointments API | prod cluster / `vetgroup` namespace | 3, scales on CPU | behind the ingress |
| Clinical Records DB | managed PostgreSQL, primary + one read replica | 1 + 1 | encrypted at rest |

A container with no row is undeployed; a row with no container is an unexplained process (Clements' mapping between views).

## 6. Variability Guide

What changes per environment, region or tenant, and what stays fixed (Clements): instance counts per environment; which regions exist and which customers' data lives where; which tenants have dedicated stamps; which managed services differ between staging and production. One table or a short list.

## 7. Drawing It

ASCII nested boxes: environment frame, then region, cluster, namespace, each containing container instances with counts; infrastructure nodes at the edge. Or a table when the nesting is shallow (lean). Mermaid `C4Deployment` is an optional copy at standard and enterprise.

```
Production
+-- Region: eu-west -------------------------------------------+
|  [Infrastructure] Load balancer --> [Infrastructure] Ingress |
|  +-- Kubernetes cluster ------------------------------------+|
|  |  namespace: <product>                                    ||
|  |    <API> x3     <Worker> x2     <Web App> x2             ||
|  +----------------------------------------------------------+|
|  [Managed PostgreSQL] <API> DB (primary + replica)           |
+--------------------------------------------------------------+
```

## 8. What Does Not Belong Here

Business behaviour, protocols between containers (the container view), Helm values, ports per Service and resource limits (the manifests, at Deploy). The section decides placement and counts; platform-engineer decides the configuration that realises it.
