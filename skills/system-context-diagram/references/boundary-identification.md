# Boundary Identification

How to find every person and external system, and decide what is inside the one system box. Self-contained. Sources: `research/software-architecture/c4-model-brown.md` (software systems are owned by one team; the ownership rule for microservices and shared platforms), `research/software-architecture/documenting-software-architectures-clements.md` (rationale and constraints recorded with the view).

The boundary is the decision this view exists to make. A wrong boundary makes the container diagram, the integrations and the deployment view wrong with it.

---

## 1. Inventory the Candidates

List every candidate with where it came from, so the catalog can be traced and nothing is forgotten.

| Source | Gives you | Watch for |
|---|---|---|
| `ideate/user-personas.md` | Persons | Two personas that are one role (collapse); one persona that is two roles (split) |
| `design/event-storming/big-picture.md`, the *Actor or system* column | Persons and external systems that start or receive events | A system named only on a hotspot |
| `design/context-map.md` | External systems upstream or downstream of our Bounded Contexts | An Anti-Corruption Layer always faces an external system |
| The stories | Persons the stories name, and anything a story says is sent, received or checked | "…and the customer gets an email": an email service |
| `ideate/nfr-specification.md` | Identity, payments, notifications, audit, regulators, data residency | Systems no story mentions: the identity provider, the regulator |
| The problem statement and stakeholder notes | Partner organisations, legacy systems that stay | A system being replaced that still runs during the migration |

Commonly forgotten: the identity provider, the email or SMS service, the payment provider, a regulator or auditor feed, and a downstream consumer that reads our webhooks or files.

## 2. The Ownership Test

For each candidate, ask: **do we build and run it as part of the system we are shipping?**

| Answer | Element | Shown here? |
|---|---|---|
| Yes, we build and run it | A container inside the system box | No; at Level 2 |
| No, a human uses it | Person | Yes |
| No, another team or organisation owns and runs it, and we exchange data with it | External system | Yes |
| No, it is where our containers run (cloud, cluster, CDN, DNS) | Infrastructure | No; the deployment view |

Ownership and operational control decide, never network location. A database we provision in another region is ours; a customer's bucket we read from in the same region is theirs.

**Tie-breaker:** whose pager fires when it fails at 3 a.m.? Ours: inside. Theirs: external.

## 3. The Hard Cases

**Our frontend, mobile app or admin console.** Inside. A web app, a mobile app and an API are three containers of one software system. Users use the system, not "the frontend"; the split is Level 2.

**Our database, broker, cache, scheduler or worker.** Inside: containers. They never appear at Level 1, even when the user asks to "show everything".

**A service another team in our own company owns.** External. Brown's rule: a software system is owned by one team; if a separate team builds and runs the billing service, it is its own software system with its own context diagram, and here it is an external system with the owning team named. If our own team runs it, it is a container, even if other products use it too.

**A third-party service (payments, email, maps).** External. The Anti-Corruption Layer we put in front of it is a container detail; at Level 1 it is one box with what it provides.

**The identity provider.** External, whether the customer's own (Okta, Entra ID) or a vendor's. It verifies who users are; leaving it off hides authentication, availability and compliance consequences until late.

**Customer-owned systems.** External. Their payroll system that receives our webhooks, their storage we read from: they own the content and the uptime. Say in the rationale when we read and never become the system of record.

**A partner organisation's system.** External, named with the organisation (`Northline Rail's booking system`). Its people who log in to our system are persons; its system we exchange data with is an external system.

**A regulator.** An external system when we exchange data with its service (a reporting portal, a submission API, a feed); a person when an inspector logs in to our system. The constraint it imposes goes in the boundary notes.

**A legacy system being replaced.** External while it still runs and we exchange data with it, even if our team will retire it; the boundary notes say when it goes and what replaces it. Once retired, redraw.

**A file drop or shared mailbox.** The external element is the system on the other side (the bank, the partner), not the SFTP server or the mailbox; the transport is the arrow's protocol.

**Automation acting for a person** (a nightly job, a reminder sender). Inside: a container of our system, not a person.

## 4. Draw the Arrows

For each person and external system, one arrow per direction of exchange, each touching the system box:
- from the party that starts it, to the other;
- labelled with what flows ("Sends settlement files to", "Receives booking confirmations from");
- protocol in plain words when it helps;
- never "uses" or "integrates with", never two heads.

An element with no arrow doesn't belong on the diagram; an exchange you can't label means the inventory is wrong.

## 5. Record Why

- **Rationale:** why each notable candidate is where it is: the containers you left inside ("the app, the API and the database are containers of this system"), the external systems and why they stay external.
- **Boundary notes:** the constraints that force the boundary (data residency, a regulator, a contract, a system that must stay) and what is **out of scope**: things a reader might expect this system to do that another system does ("payroll stays in the customer's payroll system; we send hours, not pay").
- **Assumptions:** every element inferred rather than read from a source is marked *assumed* and listed under *Open questions*.

## 6. Boundary Defects to Sweep For

| Defect | How it shows | Fix |
|---|---|---|
| Container drawn at Level 1 | A database, broker, app or worker box | Remove it; name it in the rationale as a container |
| Split system | Two boxes for what we build | One box |
| Another team's service hidden inside | A service we don't run, absent from the diagram | An external system, owning team named |
| Customer- or partner-owned system drawn as ours | Their storage or system inside the box | An external system |
| Missing person | A persona or actor with no box | Add it, or record why it doesn't use the system |
| Forgotten supporting system | No identity provider, email or payment service when the stories need one | Add it |
| Infrastructure as external | Cloud provider, Kubernetes, CDN | Remove; deployment view |
| Generic person | "User", "Customer" covering several roles | One person per role |
