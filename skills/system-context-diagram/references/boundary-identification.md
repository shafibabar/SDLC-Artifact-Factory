# Boundary Identification Procedure

The step-by-step procedure for identifying the people and external systems on a
System Context Diagram, and for drawing the boundary between what is *inside*
the system being built and what is *outside* it. Self-contained: the "do we
build and own it?" test, ambiguous-case rulings, and the boundary anti-patterns
all live here.

The boundary decision is the single most consequential choice a Level 1 view
makes. Get it wrong and every detailed diagram built on top of it is wrong.

---

## Step 1 — Inventory the Personas

Read the personas produced by the `user-persona` skill and the Actors surfaced
during Event Storming / Domain Storytelling. Each *distinct role* becomes one
person element.

For this repo's data-estate / compliance product the persona inventory is:

| Persona / Actor | Becomes | Interaction |
|---|---|---|
| Data Steward | Person element | Configures estate scans, curates the data catalog |
| Compliance Officer | Person element | Reviews compliance gaps, signs off reports |
| IT Administrator | Person element | Provisions the tenant, connects storage credentials |
| CISO / Security Lead | Person element | Receives risk alerts, sets policy thresholds |

Collapse duplicates: if "Data Owner" and "Data Steward" turn out to be the same
role under the Ubiquitous Language, they are one element. Split lumps: a generic
"Admin" that actually covers both tenant provisioning *and* compliance sign-off
is two roles and two elements.

---

## Step 2 — Inventory Upstream and Downstream Systems

List every system the system-being-built exchanges data with, in either
direction. Two categories:

- **Upstream (we consume them):** systems the system calls out to. For this
  product: Google Drive and Amazon S3 (source file storage the system scans), an
  identity provider (Okta / Azure AD) for SSO.
- **Downstream (they consume us):** systems that call the system or receive its
  output. For this product: an alerting gateway (PagerDuty / email) that
  receives compliance risk alerts; potentially a customer's SIEM pulling an
  audit feed.

Source this list from the External System (pink) cards in Event Storming, then
cross-check the `nfr-specification` — data-residency and tenant-isolation
constraints can move a system across the boundary or add one that Event Storming
missed.

---

## Step 3 — Apply the "Do We Build and Own It?" Test

For every candidate element, ask one question:

> **Do we build and operate this ourselves as part of the system we are
> shipping?**

The answer routes it to exactly one place:

- **Yes, we build and own it** → it is an **internal container**, *inside* the
  system box, therefore **invisible at Level 1**. It first appears at Level 2.
  Examples: the DataAsset Management service, the Compliance service, the
  Reporting service, the per-tenant PostgreSQL instance we provision, the
  Redpanda broker we run, the React SPA we ship, Apache AGE.
- **No — a human uses or operates it** → it is a **person element** (yellow).
- **No — someone else owns and operates it, and we integrate with it** → it is
  an **external system element** (grey).

The decisive axis is **ownership and operational control, not network
location**. A thing reached "over the network" can be internal (a PostgreSQL
instance *we* provision per tenant) or external (a customer's own S3 bucket we
read from). Distance on the wire tells you nothing; who runs it tells you
everything.

---

## Step 4 — Resolve the Ambiguous Cases

Four recurring hard cases and how to rule on each:

### A shared platform / internal service used by many products

If *our team* builds and operates it, it is internal — hidden at L1 — even if
other products also use it. If a *different team in the same company* owns it and
we merely consume its API, it is an external system at L1 (grey box), because
from this system's perspective we do not build or control it. Ownership is drawn
at the team boundary, not the company boundary.

### A third-party SaaS API (Google Drive, Stripe, PagerDuty)

Always an **external system** (grey). We never build it, never operate it, and
depend on its published contract. It appears at L1 with a label describing the
capability it lends us — "customer's source file storage," "receives risk
alerts." The fact that we write an Anti-Corruption Layer around it internally is
a Level 2/3 detail; at L1 it is one grey box.

### An identity provider (Okta, Azure AD, the customer's own IdP)

Always an **external system**. Even though authentication feels "part of the
system," the IdP is operated by the customer or a SaaS vendor and asserts
identity to us over OIDC/SAML. Draw it grey, labelled "Verifies user identity."
Omitting it is a classic forgotten-supporting-system defect — it carries auth,
compliance, and availability consequences that surface late.

### Customer-owned storage (their Google Drive, their S3 bucket)

External. The customer owns the content store; the system reads from it and is
never the system of record for that content. This is the ownership test's
cleanest case: the data lives in *their* account under *their* control. Draw it
grey and note in the Rationale that we read from it and do not become the store
of record — this is exactly the kind of boundary the per-tenant physical
isolation model depends on.

### Tie-breaker

When still genuinely unsure, ask: *"If this thing had an outage at 3 a.m., whose
pager fires?"* If ours, it is internal. If theirs (the customer's or a vendor's),
it is external.

---

## Step 5 — Draw and Label the Relationships

For each surviving actor, draw one connector to the system box:

- Direction = initiator → target (who *starts* the exchange).
- Label = what flows ("Uploads scan config," "Fetches file content," "Verifies
  identity via OIDC," "Sends risk alert").
- Never a bare "integrates with"; never a double-headed arrow (split into two).

---

## Step 6 — Apply the Boundary Anti-Pattern Checklist

Before presenting, sweep the diagram for these boundary-specific failures:

| Anti-pattern | How to detect it | Fix |
|---|---|---|
| **Internal service drawn as external** | A grey box that *we* actually build and operate (e.g. the Compliance service shown next to Google Drive) | Move it inside the system box; it is a container, invisible at L1 |
| **External-owned store drawn as internal** | Customer's S3 bucket hidden inside the blue box | Pull it out as a grey external system — we do not own it |
| **Omitted human actor** | A role from the persona list with no element on the diagram (often the IT Administrator or CISO) | Add the person element; every persona maps to one |
| **Data store shown at L1** | A database or broker box on the context diagram | Remove it — a store we own is an internal container; only an externally-owned store appears, and then as an external *system*, not a "database" |
| **Split system** | Two blue boxes ("Frontend," "Backend") | Merge into one; frontend/backend is a Level 2 container split |
| **Forgotten supporting system** | The IdP, alerting gateway, or monitoring SaaS absent | Cross-check Event Storming pink cards + NFR spec; add the grey box |
| **Technology label leaking in** | "React," "PostgreSQL," "chi" on any element | Strip it; technology first appears at Level 2 |

---

## Worked Boundary Ruling — Data-Estate Platform

Applying the test across the candidate list:

| Candidate | Ownership question answer | Verdict | On the L1 diagram? |
|---|---|---|---|
| DataAsset Management service | We build & run it | Internal container | No (hidden in box) |
| Compliance service | We build & run it | Internal container | No |
| Reporting service | We build & run it | Internal container | No |
| Per-tenant PostgreSQL (we provision) | We build & run it | Internal container | No |
| Redpanda broker (we run) | We build & run it | Internal container | No |
| React SPA | We build & ship it | Internal container | No |
| Data Steward | A human uses it | Person | Yes (yellow) |
| Compliance Officer | A human uses it | Person | Yes (yellow) |
| IT Administrator | A human operates it | Person | Yes (yellow) |
| Google Drive | Customer owns it | External system | Yes (grey) |
| Amazon S3 (customer bucket) | Customer owns it | External system | Yes (grey) |
| Identity Provider (Okta) | Vendor/customer owns it | External system | Yes (grey) |
| Alerting gateway (PagerDuty) | Vendor owns it | External system | Yes (grey) |

The result: **one blue box** (the platform), **three yellow person elements**,
**four grey external systems**. Everything we build and run collapses into the
single blue box, exactly as Level 1 requires.
