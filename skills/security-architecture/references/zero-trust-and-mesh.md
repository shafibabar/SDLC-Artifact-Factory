# Zero Trust and the Mesh — the Model Behind the Placement Rule

Reference for `security-architecture`. The body states the core rule ("the network is always
hostile; the authorization decision stays in the application, Linkerd provides transport identity
only"). This file is the decomposition behind that rule (Gilman & Barth, *Zero Trust Networks*;
later formalized in NIST SP 800-207) and precisely how it maps onto this repo's Linkerd + physical
per-tenant isolation stack.

---

## The founding axiom: the network is always hostile

Trust must **never** be derived from network location. There is no "internal" network that is safe
by virtue of being behind a firewall. A packet arriving from `10.0.0.0/8` is exactly as untrusted
as one from the public internet. This inverts the perimeter model, where a host's IP or VLAN
membership implicitly granted it standing.

For this repo: never treat "inside the Kubernetes cluster" or "inside the Linkerd mesh" as a trust
signal. A compromised pod in the same namespace is a hostile network participant; authorization
must not soften because the caller is `ClusterIP`-local. Every request is authenticated and
authorized on its own merits, every time.

---

## Control plane vs. data plane (the central architectural split)

The book's central architectural split, and the vocabulary the previous version of this skill
lacked:

- The **data plane** is where application traffic actually flows — the request from service A to
  service B. It *enforces* what it is told to enforce.
- The **control plane** is the separate, higher-trust system that *decides* whether that flow is
  permitted and configures the enforcement points to allow it.

Enforcement happens in the data plane, but the **decision** is made in the control plane and pushed
down. The two must be separated: *the thing carrying traffic must never also be the sole authority
on whether that traffic is legitimate.*

Mapping to this repo:

| Zero-trust concept | This repo |
|---|---|
| Data plane (transport enforcement) | Linkerd sidecar proxies doing mTLS between meshed pods |
| Control plane (the authorization decision) | the application's **ABAC** engine (`AccessPolicy.Evaluate`) |

This is the architectural invariant a reviewer must be able to assert cleanly: **Linkerd is
data-plane transport enforcement; the ABAC engine is the control-plane authorization decision; the
two are separated by design.** (Note: "control plane / data plane" here is the *security* sense —
who decides vs. who carries — distinct from the routing sense of the same words.)

---

## The control plane decomposes into a policy engine and a trust engine

The control plane is itself two components:

- The **policy engine** evaluates a request against declared policy: *"is subject X allowed action Y
  on resource Z under conditions C?"* It is the rule. It maps directly to this repo's ABAC
  evaluator.
- The **trust engine** continuously *scores the trustworthiness* of the actors — this device, this
  user, this workload — from dynamic signals like device posture, historical behavior, and
  freshness of authentication. It is the continuously-updated confidence that the actors are who
  they claim and are behaving acceptably.

A modern authorization decision **combines both**: a structurally-valid credential (policy says
allow) from a device or context with a degraded score (trust engine says risky) may still be
**denied**. In this repo, the ABAC `Environment` attributes — token age / authentication freshness,
source-IP reputation, device posture, anomaly flags — are exactly the **trust engine** signals
feeding the policy decision. Authentication is therefore *not* a one-time binary gate; it is
per-request, context-aware.

```go
// ABAC Environment carries trust-engine signals, evaluated per request.
type Environment struct {
    TokenAgeSeconds   int     // authentication freshness
    SourceIPReputation string // trust-engine signal
    DevicePosture      string // trust-engine signal
    AnomalyFlagged     bool
}
// A valid credential from a low-trust context can still be denied.
```

---

## Three independent identity planes: device, user, workload

Zero trust refuses to conflate the three actors in any request. Each is authenticated on its own
axis, and a request is only as trustworthy as its **weakest** axis:

- **Device** proves itself — hardware-backed identity, enrolled certificate, attested posture.
- **User** proves itself — a strong IdP-issued identity, MFA.
- **Workload / application** proves itself — a *cryptographic workload identity*, never a shared
  secret or a source IP.

For this repo's server-to-server calls (the data-classification service calling the PII-extraction
service), the relevant axis is **workload identity**: each service has its own cryptographic
identity (the Linkerd-issued cert), independent of the human user whose request triggered the
chain. Two identity planes are always in play on such a hop and both must be validated
independently:

1. **Workload identity** — the Linkerd cert answers *"which service is calling?"*
2. **User/subject identity** — the propagated, re-validated JWT answers *"on whose behalf?"*

Never let a trusted workload identity *launder* an unvalidated or over-broad user claim. **Re-derive
the `Subject` from the token at the receiving service** — do not trust an upstream service's
assertion of it.

---

## mTLS as the enforcement substrate — and its precise limit

mTLS is the practical mechanism that makes zero trust real on the wire: every connection is mutually
authenticated with certificates, giving both ends a verified cryptographic identity and encrypting
transport. The certificate *is* the workload's identity — trust is bound to a short-lived, rotatable
credential, not to an IP or DNS name that can be spoofed. Linkerd automates exactly this (automatic
mTLS between meshed pods, certs rotated frequently).

**The sharpest point for this repo:** mTLS answers *"who is this?"* at the transport layer. It does
**not** answer *"is this actor allowed to do this?"*. That authorization question lives above the
transport, in the control-plane policy engine (ABAC). A meshed connection succeeding proves
identity; it is never a permission grant.

```
Request A ──► B
  │
  ├─ Linkerd mTLS (data plane): proves "A is A", encrypts transport   ← who
  └─ ABAC Evaluate (control plane): "may A's subject do this action?" ← what  (the decision)
```

---

## Dynamic, identity-based policy vs. static firewall rules

Contrast zero-trust policy with the traditional 5-tuple firewall rule (`allow src X dst Y port Z`).
Static rules encode *network topology* — brittle, coarse, blind to who is actually acting.
Zero-trust policy is expressed against **logical identities and attributes**: "the `pii-extraction`
workload, acting for a `Restricted`-clearance subject, may call `data-assets:read`" — evaluated
fresh per request against current context.

- Express policy in terms of **workload identities, subject attributes, and resource sensitivity** —
  never source IP, namespace, or port.
- Store policy as **versioned, reviewable code** (GitOps / Infrastructure as Code), so it is
  auditable and diffable rather than living in mutable firewall/NetworkPolicy state that drifts.

---

## Micro-segmentation and per-tenant isolation as two independent containment layers

Because no lateral position confers trust, an attacker who breaches one host or segment gains almost
nothing beyond that single compromised identity's own least-privilege grants — there is no "soft
chewy center" to pivot through. Two independent containment layers apply here, **neither trusting
the other**:

1. **Physical per-tenant isolation** contains cross-tenant blast radius at the *deployment* layer —
   each tenant namespace is a failure-domain boundary.
2. **Per-workload micro-segmentation** contains blast radius *within* a tenant's deployment.

Micro-segmentation is default-deny service-to-service traffic with only the specific
identity-to-identity paths a service actually needs opened:

```yaml
# Default-deny; open only pii-extraction ← data-classification.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: pii-extraction-ingress }
spec:
  podSelector: { matchLabels: { app: pii-extraction } }
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: { matchLabels: { app: data-classification } }
```

NetworkPolicy is reachability; the *authorization* decision on the opened path still lives in ABAC —
the two layers are complementary, not redundant. Physical multi-tenancy is not a substitute for
per-workload zero-trust identity, and vice versa.

---

## Audit every decision — allow *and* deny

Emit an OpenTelemetry span/log for each authorization decision recording the subject, workload
identity, resource, action, and the trust signals that drove the outcome — so the control-plane
decision is observable in Tempo/Grafana, not a silent gate. "Why was this allowed?" becomes
answerable after the fact, which perimeter firewalls never could. This is also the queryable SOC 2
evidence that authorization is enforced *per request in the control plane*, not merely asserted by a
static NetworkPolicy snapshot.

---

## The invariant the zero-trust design protects

> Every request is authenticated and authorized on its own merits regardless of origin; the
> authorization decision is made in the control-plane policy engine (ABAC), fed by trust-engine
> signals, and never inferred from network position or a successful mTLS handshake.

---

## Applying this proportionately

"Never trust the network" adds latency and operational surface if over-applied. Apply it *always*
for cross-service authorization decisions; do **not** re-run full trust scoring on every intra-
service function call. The book supplies the posture; this repo applies it to the boundaries that
matter — the trust-boundary crossings the threat model already identified.
