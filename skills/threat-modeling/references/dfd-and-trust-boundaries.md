# Data Flow Diagrams and Trust Boundaries

The Data Flow Diagram (DFD) is the model that anchors Question 1 of the
Four-Question Framework ("what are we building?"). It is the software-centric
artifact this skill mandates: something the team already understands and can draw
accurately, unlike a drifting asset list or a speculative attacker persona. This
file gives the DFD notation, where trust boundaries go, the concrete boundary set
for this repo's DataAsset flow, and the drawing anti-patterns that make a DFD
misleading.

---

## DFD notation — exactly four element types

A DFD is built from four — and only four — element types. Keeping the vocabulary
this small is deliberate: it makes the model reviewable and the STRIDE-per-element
heuristics (see `references/stride-catalogue.md`) apply cleanly.

| Element type | Notation | What it is | Examples in this repo |
|---|---|---|---|
| **External entity** | rectangle | A principal outside your control that talks to the system | Browser/user, Google Drive, S3 |
| **Process** | circle | Code that transforms data | Ingestion worker, classification service, compliance service |
| **Data store** | two parallel lines | Somewhere data rests or is buffered | PostgreSQL, the Redpanda topic (a store-in-transit) |
| **Data flow** | arrow | Data moving between two elements | JWT on the API request, event on a Redpanda topic |

**Drawing rules.**

- **Draw the DFD first, boundaries second.** Get the elements and flows right before
  reasoning about trust.
- **Number every element** (E1, P1, DS1, F1 …). Threats are recorded against element
  numbers, which is what keeps the model and the STRIDE grid linked — a finding
  says "Tampering on DS4", not "somewhere in the database".
- **The Redpanda topic is a data store, not just a flow.** A message sits on the
  topic between produce and consume, so it is a store-in-transit: it gets a data
  store's STRIDE letters (Tampering, Information disclosure, Repudiation for the
  log) *and* the crossing flows get theirs.
- **A process must have both inputs and outputs.** A process that produces output
  from no input, or consumes input and produces nothing, is a modeling error (see
  anti-patterns).

---

## Trust boundaries — where trust changes

A **trust boundary** is a dashed line drawn on the DFD wherever the level of trust
changes — where data crosses from a less-trusted zone into a more-trusted one, or
between two zones neither of which should trust the other. The central insight:
**threats concentrate on the data flows that cross a trust boundary.** A flow
entirely inside one trust zone is lower priority; a flow that crosses a boundary is
where STRIDE analysis pays off most, because that crossing is where an attacker's
input meets your trust.

### The boundary set for this repo

Draw a trust boundary at each of these on the DataAsset DFD:

1. **The browser/API edge.** The user's browser is an external entity you do not
   control. Everything crossing this boundary (the JWT, the classification request)
   is attacker-influenceable. Spoofing (S) and Tampering (T) concentrate here; this
   is the TLS-on-ingress and JWT-validation boundary.
2. **The Google Drive / S3 external-ingestion edges.** Ingested file content comes
   from an external service. Content crossing this boundary is untrusted input —
   this is where the Circuit Breaker for availability (D) and content validation
   sit, and where the "never persist raw file contents" privacy constraint is
   enforced on the flow into the classification process.
3. **Each Linkerd mTLS hop (every service↔service edge).** Under Assume Breach, one
   service does not implicitly trust another. Linkerd's automatic mTLS makes each
   internal hop a boundary with a cryptographic peer identity — mitigating Spoofing
   (S) at transport level. Note the boundary carries **transport identity only**;
   the authorization decision (E) is still the application-layer ABAC check.
4. **The per-tenant namespace edge.** Physical tenant isolation (separate
   namespace/deployment per tenant) is a trust boundary: a request in tenant A's
   namespace must never reach tenant B's data. This is the crown-jewel boundary —
   the one the single attack tree targets. It is defense in depth *with* the ABAC
   tenant-scope check, not a replacement for it.
5. **The data store edges (PostgreSQL, Redpanda).** The boundary between a process
   and its persistent store: Tampering (T) and Information disclosure (I) via
   parameterized `pgx` writes and encryption at rest.

A useful discipline: for **every** boundary crossing, name what happens if the outer
layer is misconfigured or bypassed. If the answer is "nothing, we rely on it", that
is the "defense in depth as an excuse for a shallow model" anti-pattern — the
physical-isolation boundary does not remove the ABAC check; the mTLS boundary does
not remove the authorization decision.

---

## Worked boundary sketch (text DFD)

```
[ Browser/User ]  (external entity, E1)
      | F1: JWT + classification request
==========================================  <-- Trust boundary 1: browser/API edge (TLS, JWT)
      v
   ( API / chi handler, P1 )
      | F2: validated command (mTLS)
------------------------------------------  <-- Trust boundary 3: Linkerd mTLS hop
      v
   ( Classification service, P2 )
      |  \
      |   \ F4: entity types + counts ONLY   ==========  <-- per-tenant namespace edge (TB4)
      |    v
      |   [ PostgreSQL, DS1 ] ----  <-- Trust boundary 5: data store edge (pgx, encryption)
      | F3: classification event
      v
   [ Redpanda topic, DS2 ]  (store-in-transit)
      | F5: event (mTLS)
------------------------------------------  <-- Trust boundary 3: Linkerd mTLS hop
      v
   ( Compliance service, P3 )

[ Google Drive / S3 ]  (external entity, E2)
      | F6: raw file content
==========================================  <-- Trust boundary 2: external-ingestion edge
      v
   ( Ingestion worker, P4 ) -- F7 raw content, NEVER persisted --> ( Classification P2 )
```

---

## DFD anti-patterns

- **Missing boundary.** A DFD with no trust boundaries drawn, or with only the
  internet-facing edge marked and everything inside the cluster treated as one
  trusted zone. This is the "only the external boundary" failure — internal
  service↔service, service↔store, and tenant↔tenant boundaries must all be drawn,
  or STRIDE has nowhere to concentrate.
- **Process with no inputs (or no outputs).** A circle that emits data from nothing,
  or swallows data and emits nothing, means the DFD is incomplete — a real data
  source or sink is missing, and any threat on the hidden flow is invisible. Every
  process needs at least one inbound and one outbound flow.
- **Data store drawn as a flow (or vice versa).** Modeling the Redpanda topic as a
  mere arrow hides that messages rest there and lose a data store's Tampering/
  Information-disclosure/Repudiation analysis. Modeling a transient in-process value
  as a data store inflates the grid with cells that do not exist.
- **Unnumbered elements.** Without element numbers, findings cannot be traced back to
  the model, and Question 4's "was STRIDE applied to every element?" becomes
  unanswerable.
- **The DFD that outlived the system.** A diagram that no longer matches the built
  architecture (a new ingestion connector added, a boundary moved) is stale evidence.
  Any DFD change re-opens the threat model.
- **Boundaries drawn where trust does *not* change.** A dashed line between two
  components in the same trust zone adds noise and dilutes attention from the
  crossings that actually matter. Draw a boundary only where the trust level changes.

---

## Boundary-crossing analysis checklist

For each flow that crosses a trust boundary, walk these questions before moving on —
this is what turns a drawn diagram into an analysable model:

1. **What crosses?** Name the data on the flow (a JWT, raw file content, a signed
   event). Attacker-influenceable data crossing *inward* is the highest priority.
2. **Which STRIDE letters does the crossing invite?** Use the data-flow heuristic
   (Tampering, Information disclosure, Denial of service) plus the source element's
   letters — a flow from an external entity also carries that entity's Spoofing.
3. **Which layer defends the crossing?** Map it to mesh/mTLS (Spoofing, transport
   Tampering) or application/ABAC (Elevation of privilege, Information disclosure),
   so the finding lands in the right Security Control Matrix layer.
4. **What if the outer layer is bypassed?** State the second, independent layer. If
   there is none, that is a finding, not a reassurance — the physical-isolation
   boundary must not remove the ABAC check, and the mTLS boundary must not remove the
   authorization decision.
5. **Where is the evidence?** Every state-changing crossing needs an audit record
   (non-repudiation) so Question 4 can confirm the crossing is attributable.

A crossing that answers all five is analysed; one that cannot answer (4) with a named
second layer is the "defense in depth as an excuse" anti-pattern the model exists to
surface.
