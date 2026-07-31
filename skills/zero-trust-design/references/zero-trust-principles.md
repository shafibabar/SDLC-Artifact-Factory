# Zero Trust Principles — The Model Behind the Design

This reference holds the conceptual model that grounds `zero-trust-design`'s
body. The body states the rules; this file explains *why* they hold, using the
control-plane/data-plane framing from Gilman & Barth's *Zero Trust Networks*
(later formalized in NIST SP 800-207).

---

## The Zero Trust Model

Trust is never derived from network location. There is no "internal" network
that is safe by virtue of being behind a firewall — a packet arriving from
`10.0.0.0/8` is exactly as untrusted as one from the public internet. This
inverts the perimeter model, where a host's IP or VLAN membership implicitly
granted it standing.

For this repo, this is the argument against ever treating "inside the Kubernetes
cluster" or "inside the Linkerd mesh" as a trust signal: a compromised pod in the
same namespace is a hostile network participant, and authorization must not
soften because the caller is `ClusterIP`-local. Every request is authenticated
and authorised on its own merits, every time.

---

## Control Plane vs Data Plane

This is the central architectural split, and the reason the mesh can never
authorise.

- The **data plane** is where application traffic actually flows — the request
  from service A to service B. Enforcement happens here.
- The **control plane** is the separate, higher-trust system that *decides*
  whether that flow is permitted and configures the enforcement points to allow
  it. The decision is made in the control plane and pushed down.

These must be separated: the thing carrying traffic must never also be the sole
authority on whether that traffic is legitimate. Mapping to this repo — Linkerd's
data plane (the sidecar proxies doing mTLS) is transport enforcement; the
*authorization* control plane is the application's ABAC engine, **not** the mesh.

### Policy engine and trust engine

The control plane decomposes into two parts:

- The **policy engine** evaluates a request against declared policy: "is subject
  X allowed action Y on resource Z under conditions C?" — this repo's ABAC
  evaluator.
- The **trust engine** continuously scores the risk/trustworthiness of the
  actors — this device, this user, this workload — from dynamic signals like
  authentication freshness, device posture, source-IP reputation, and anomaly
  flags. These are this repo's ABAC `Environment` attributes.

A modern authorization decision combines both: a structurally valid credential
(policy) presented from a device with a degraded trust score (trust engine) may
still be denied. Authentication is not a one-time binary gate.

---

## Independent Trust in Devices, Users, and Workloads

Zero trust refuses to conflate the three actors in any request. Each is
authenticated on its own axis, and a request is only as trustworthy as its
weakest axis:

- A **device** proves itself — hardware-backed identity, an enrolled
  certificate, attested posture.
- A **user** proves itself — a strong IdP-issued identity, MFA.
- A **workload/application** proves itself — a cryptographic workload identity,
  not a shared secret or a source IP.

For this repo's server-to-server calls (e.g. the data-classification service
calling the PII-extraction service) the relevant axis is *workload identity* —
each service carries its own cryptographic identity, independent of the human
user whose request triggered the chain. That is why every server-to-server call
requires **both** a verified workload identity (the Linkerd cert — *which*
service is calling) **and** a re-validated user/subject identity (the propagated
JWT — *on whose behalf*). Never let a trusted workload identity launder an
over-broad or unvalidated user claim; re-derive the `Subject` from the token at
the receiving service rather than trusting an upstream's assertion of it.

---

## Dynamic, Context-Aware Policy vs Static Firewall Rules

Zero-trust policy is not the traditional 5-tuple firewall rule
(`allow src X dst Y port Z`). Static rules encode *network topology*, which is
brittle, coarse, and blind to who is actually acting.

Zero-trust policy is expressed against *logical identities and attributes* —
"the `pii-extraction` workload, acting for a `Restricted`-clearance subject, may
call `data-assets:read`" — and is evaluated fresh per request against current
context, not baked into a firewall config that drifts. Policy is stored as
versioned, reviewable code (GitOps + Infrastructure-as-Code), so it is auditable
and diffable rather than living in mutable NetworkPolicy/firewall state.

---

## The Three Pillars in Full

The body summarises these; the per-identity mapping tables live here.

### Pillar 1: Verify Explicitly

Every request is authenticated and authorised, every time. Location (internal
network, same Kubernetes namespace) does not grant implicit trust.

| Layer | Mechanism |
|---|---|
| User → Service | JWT Bearer token; validated on every request at the API Gateway and at the service handler |
| Service → Service | mTLS; certificate identity (SPIFFE/SPIRE or Linkerd-issued); verified on every connection |
| Service → Database | Service account credentials; rotated automatically; never static passwords in environment variables |
| Service → External API | Short-lived OAuth 2.0 access tokens; never long-lived API keys stored in code |

### Pillar 2: Apply the Principle of Least Privilege

Every identity (user or service) has only the permissions required for its
specific function. No identity has permissions "just in case."

| Identity | Principle application |
|---|---|
| User JWT claims | Claims scoped to the user's role; ABAC policy enforced at every resource access |
| Service account | Read/write only to its own database; no cross-service database access |
| Infrastructure credentials | Terraform/Tofu state access scoped to specific environment; no wildcard IAM policies |
| Admin access | Time-limited; requires approval; logged; no standing admin access to production |

### Pillar 3: Assume Breach

Design as if an attacker is already inside the perimeter. Contain the blast
radius of a compromise.

| Mechanism | Purpose |
|---|---|
| mTLS between all services | A compromised service cannot impersonate another service |
| Tenant namespace isolation | A compromise of one tenant's service cannot reach another tenant's data |
| Short-lived credentials | Compromised credentials expire quickly; reduces the window of exploitation |
| Read-only service accounts where possible | A compromised read-only service account cannot modify data |
| Audit logging of all privileged actions | Compromise can be detected and its scope bounded post-incident |

---

## Zero Trust Degrades the Value of a Perimeter Breach

The model's payoff: because no lateral position confers trust, an attacker who
breaches one host or one network segment gains almost nothing beyond that single
compromised identity's own least-privilege grants. There is no "soft chewy
center" to pivot through. Combined with micro-segmentation, a breach is contained
to the blast radius of one workload identity rather than the whole flat internal
network — the security case for per-tenant physical isolation *and* per-workload
identity together: two independent containment layers, neither trusting the other.
