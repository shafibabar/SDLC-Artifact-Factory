# Why the Container View and the Deployment View Stay Apart

Self-contained. Source: `research/software-architecture/documenting-software-architectures-clements.md` (viewtypes, combined views, mapping between views, the documentation package); `research/software-architecture/c4-model-brown.md` (how C4 relates to the views tradition). Read it when someone wants placement on the container picture, or asks why the artifact has two parts.

---

## 1. One System, Several Structures

A system has several structures at once: how its code divides into modules, what runs and talks at runtime, where it runs. One drawing that tries to show them all is readable by nobody. A **view** shows one structure, for named readers with a named concern; a **viewpoint** is the reusable rule for drawing views of that kind (Clements).

Clements groups views into three types:

| Type | Shows | Answers | In this plugin |
|---|---|---|---|
| Module | Code units and their static relations | If I change X, what else changes? | `component-diagram`'s layer view; package layout |
| Component-and-connector | Running units and their runtime interactions | What talks to what while it runs, and how? | The container view |
| Allocation | Software mapped onto non-software: machines, environments, teams | Where does it run, who builds it? | The deployment view section |

**C4 beside the views tradition.** Brown presents C4 as a simplification of the views literature (Kruchten's 4+1 and others) for developers, not as a profile of Clements' method. Clements' viewtypes are a useful lens on it: read this way, the Container diagram is a component-and-connector view and the Deployment diagram an allocation view.

## 2. The Rule

The container view answers what talks to what. The deployment view answers where each container runs and how many copies. Detail that can change without changing who talks to whom is allocation, and goes in the deployment view:

| On the container picture, this is a sign of drift | Because | Goes to |
|---|---|---|
| Node, pod, cluster, namespace boxes | Placement | Deployment view |
| Replica counts, autoscaling | How many copies | Deployment view |
| Regions, availability zones | Geography | Deployment view |
| "×N per tenant", tenant stamps | Tenancy placement | Deployment view and its variability guide |
| Ports, Services, Helm releases | Network binding and packaging | Deployment view; then `kubernetes-manifest` |
| Docker images | How a container is packaged | Deployment view |

The appointments API calls its database the same way with one replica or ten, in one region or three, in one stamp or forty. That invariance is the test.

## 3. Combined Views Are an Exception

Clements allows one diagram to carry two view types when the combination serves one reader better than two drawings, as a deliberate exception with a one-line justification; combined views tend to grow until nobody can read them. This plugin's default is two parts of one artifact: the container view and the deployment view section. A combined drawing needs that line, and the reason.

## 4. Mapping Between Views

The two parts are linked by a **mapping**: every container in the container view appears in the deployment view's mapping table, with the deployment node it runs on and its instance count. Matching names make the mapping checkable; a container with no row is undeployed, and a row with no container is an unexplained process.

## 5. The Documentation Package

A view is more than a picture (Clements):
- **Primary presentation:** the ASCII diagram.
- **Element catalog:** the containers table and the communication matrix, carrying what the boxes can't (technology, protocol, owner).
- **Context:** the system context diagram supplies it for Level 2.
- **Variability guide:** in the deployment view, what changes per environment, region or tenant.
- **Rationale:** why this shape: which splits and why, why the gateway sits where it does. A cross-cutting decision is an ADR; the rationale explains this view.
