# Viewtype Theory: Why a Container Diagram Is a C&C View, Not a Deployment View

Source: Clements et al., *Documenting Software Architectures: Views and Beyond* (2nd ed., SEI/CMU),
Ch. 1–7 and 9. This reference makes precise the single most important correctness rule for the
Container Diagram: it is a **component-and-connector (C&C) view**, and deployment placement — nodes,
pods, replicas, regions, per-tenant stamps — belongs to a **separate allocation view**. Read this
whenever you are tempted to draw *where* a container runs on the Container Diagram.

---

## The founding claim: architecture is a set of views, not one diagram

No single diagram can show a system's structure, because a system has **many structures at once** —
how its source is decomposed into modules, how its processes talk at runtime, where those processes
are deployed. A diagram that tries to show all of them becomes unreadable. A **view** is a
representation of the system from the perspective of *one* of these structures. A **viewpoint** is
the reusable pattern (element types, relation types, notation, the questions it answers) that
generates all views of one kind.

C4's four "levels" (Context → Container → Component → Code) are a deliberately simplified,
opinionated *profile* of this method — Simon Brown built C4 as an approachable subset of the C&C
viewpoint for software teams. C4's fixed sequence occasionally blurs a distinction the method keeps
sharply separate. The Container Diagram is where that blur most often happens.

## The three major view types

Clements groups every architecture view into exactly three types. Knowing which type a diagram is
tells you what may and may not appear on it.

### 1. Module views — static implementation structure

Show how source code is divided into implementation units (modules, packages, classes, layers) and
the static relations between them: *decomposition* (is-part-of), *uses* (depends-on), *generalization*
(is-a), and *layered* (allowed-to-use). A module view answers: **"If I change X, what else must I
change or understand?"** It has **no runtime dimension** — no processes, no messages, no time.

In this repo, `component-diagram`'s "Standard Layered Architecture for Go Services" (API → Application
→ Domain → Infrastructure, inward-only dependencies) is a *layered module view*.

### 2. Component-and-connector (C&C) views — runtime structure

Show the principal **executing units** — *components*: processes, services, threads, running objects
— and the **pathways of interaction** between them — *connectors*: procedure calls, HTTP requests,
event channels, message-queue topics. A C&C view answers: **"What talks to what while the system is
running, and how?"**

**The C4 Container Diagram is a C&C view.** Its containers are runtime components (the Go API
process, the Redpanda broker, the Postgres server, the worker); its arrows are connectors (an
HTTP/JSON call, a Kafka/Redpanda topic subscription). Everything it legitimately shows is a runtime
element or a runtime interaction path.

### 3. Allocation views — mapping software onto non-software structure

Show the mapping of software (modules or components) onto structures that are **not software**:
- **Deployment view** — which process/container runs on which node, pod, cluster, region.
- **Implementation view** — how modules map onto the source-tree / directory layout.
- **Work-assignment view** — which modules are owned by which team.

An allocation view answers a fundamentally different question: not "how is the code organized" or
"what talks to what," but **"where does this run, and who owns building it?"** A Kubernetes
deployment diagram — pods, nodes, replica sets, availability zones, Helm releases, per-tenant
stamps — is a **deployment (allocation) view**.

## Where deployment nodes and pods belong: NOT on the Container Diagram

The answer to "which C4 diagram is a component-and-connector view, and where do deployment
nodes/pods belong instead?" is precise and load-bearing:

- The **C4 Container Diagram is the component-and-connector view.**
- **Deployment nodes, pods, replica counts, regions, and per-tenant stamps belong on a separate
  deployment (allocation) view** — never on the Container Diagram.

Mixing them produces what the book calls an *unexamined conflation*: one drawing forced to answer
two unrelated questions, readable by no stakeholder cleanly. The Container Diagram stops being a
crisp answer to "what talks to what" and becomes a muddled half-answer to both "what talks to what"
and "where does it run."

## Concrete symptoms of conflation (how to catch yourself)

You have drifted from a C&C view into an allocation view the moment any of these appear on a
Container Diagram:

| Symptom on the diagram | Why it is allocation, not C&C | Where it actually belongs |
|---|---|---|
| Kubernetes **node** or **pod** boxes | Physical/logical placement of a process | Deployment view |
| **Replica counts** ("×3", "3 replicas") | How many copies run — a placement decision | Deployment view |
| **Region / availability-zone** labels | Geographic placement | Deployment view |
| **"×N per tenant"** multipliers / tenant stamps | Physical multi-tenancy is a placement/allocation concern | Deployment view + its variability guide |
| **Port bindings** ("Port: 8080", NodePort) | A deployment/runtime-environment binding, not a logical connector | Deployment view |
| **Helm release / namespace** grouping | Packaging-and-placement structure | Deployment view / IaC |

None of these change *what talks to what*. The Compliance API calls the DataAsset API over HTTP/JSON
whether there is one replica or thirty, in one region or three, in one tenant stamp or fifty. That
invariance is the signal: if a detail can vary without changing the communication topology, it is
allocation, and it does not belong on the C&C Container Diagram.

## How the two views relate — without merging

The C&C view and the deployment (allocation) view are connected by a **mapping between views**: each
container in the Container Diagram is *allocated to* one or more nodes/pods in the deployment view.
This mapping is documented (a table, or matching element names across the two diagrams) — it is not
drawn by cramming both structures into one picture.

```
Container Diagram (C&C)                 Deployment Diagram (allocation)
--------------------------              --------------------------------
DataAsset API   ────maps to───▶         Pod: dataasset-api  (3 replicas, tenant stamp per namespace)
DataAsset DB    ────maps to───▶         StatefulSet: dataasset-pg  (1 primary + 1 replica)
Redpanda        ────maps to───▶         StatefulSet: redpanda  (3 brokers, shared cluster)
```

The Container Diagram says *DataAsset API publishes `dataasset.discovered` to Redpanda*. The
deployment view says *the dataasset-api pod runs 3 replicas per tenant namespace on the general
node pool*. Two questions, two views, one documented mapping between them.

## Combined views: allowed, but only when deliberate and justified

Clements (Ch. 9) permits overlaying two view types in one diagram — e.g. a C&C view annotated with
deployment allocation — **but only as a deliberate, justified exception**, with a one-line note
stating why the combination serves the reader better than two separate views would. It is never the
default, because combined views silently grow until no one can read them.

For this repo, the default is **two separate views**: a pure C&C Container Diagram, and a separate
deployment diagram. Given the physical multi-tenancy model (per-tenant stamps multiply deployment
but not the logical topology), keeping them separate is strictly clearer — the tenant multiplication
lives once in the deployment view's variability guide, not smeared across the Container Diagram.

## Why the earlier version of this skill was defective

The v1 `container-diagram` mixed C&C and allocation concerns: its worked example carried port
bindings ("Port: 8080") and cluster-placement annotations ("shared cluster"), and its "Deciding
Service Boundaries" table folded allocation reasoning (physical multi-tenancy "multiplies"
deployment, data residency, team ownership) into what was nominally a C&C diagram's supporting text.
Those are allocation-view concerns. The v2 skill resolves this by: (a) naming the Container Diagram
explicitly as a C&C view; (b) stating the C&C-vs-allocation separation as a correctness rule; (c)
moving placement, ports, replicas, and tenant multiplication to the deployment view; and (d) keeping
only runtime communication (protocol, sync/async, topic) on the Container Diagram itself.

## A view is more than a picture — the documentation package

A complete view is a *documentation package*, not just a drawing. Its parts (Ch. 3):

- **Primary presentation** — the diagram (Mermaid / textual C4 here).
- **Element catalog** — a table enumerating every element and relation with properties the picture
  cannot carry (a connector's protocol, a container's responsibility, a topic's schema).
- **Context diagram** — how this view's system-of-interest relates to what is outside it, at this
  view's own level (for L2, the System Context view supplies this).
- **Variability guide** — what varies across product variants or deployments (for the *deployment*
  view: per-tenant stamp count, region set — kept out of the C&C Container Diagram deliberately).
- **Rationale** — why *this diagram's shape* was chosen. This is lighter-weight than an ADR: not
  every layout choice warrants a full ADR, but a sentence or two captured in the view's own package
  gives view-shape reasoning a home. An ADR records a cross-cutting *decision*; a view Rationale
  records why *this view* looks the way it does.

## Key terms

- **View** — a representation of the system from one structural perspective (a documentation package,
  not just a picture).
- **Viewpoint** — the reusable conventions that generate all views of one kind.
- **Module view / C&C view / Allocation view** — the three major view types.
- **Element catalog** — the tabular enumeration of every element/relation with its properties.
- **Mapping between views** — the documented correspondence between elements of two views (here:
  container → node/pod).
- **Combined view** — a deliberate, justified overlay of two view types in one diagram.
