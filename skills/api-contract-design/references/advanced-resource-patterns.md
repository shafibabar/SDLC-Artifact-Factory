# Advanced Resource Patterns

Grounded in JJ Geewax's *API Design Patterns* (`research/software-architecture/api-design-patterns-geewax.md`) — the four/five patterns this skill's core resource model doesn't cover on its own: actions that aren't clean CRUD, async work that needs a pollable status shape, concurrent-writer safety, and precise partial-update semantics.

## Custom Methods

`SKILL.md`'s Resource Naming section maps every Command onto a standard HTTP method — `POST` to create, `PUT`/`PATCH` to update, `DELETE` to remove. That covers the overwhelming majority of Commands in the Command Catalog. It does not cover the rarer action that is genuinely not a create, read, update, or delete on the resource, and that cannot honestly be expressed as a `PATCH` to a resource field either. Geewax's answer is the **custom method**: `POST /{resource}:verb` — a colon-suffixed verb, scoped to a specific resource or collection, reserved for exactly this narrow case.

This is not a reopening of the "Verb endpoints" anti-pattern in `SKILL.md`'s Anti-Patterns table. That anti-pattern forbids **free-floating** verb endpoints with no resource in the path at all — `POST /v1/classifyDataAsset` reads as an RPC call with no noun, no caching semantics, and no place in the resource hierarchy. A custom method is the opposite shape: it is still `POST /{resource-path}:verb`, still hangs off a real resource URL, still inherits that resource's auth, rate limiting, and routing. The distinguishing question is not "does this endpoint contain a verb" — it's "does this action have a resource to hang off of, or none at all." `PATCH /v1/data-assets/{id}/classification` (the anti-pattern table's own correction) remains the preferred default whenever the action *is* a state transition on a resource field. Reach for a custom method only when it genuinely is not — a one-shot, non-idempotent action with no natural resource-field equivalent.

Worked example: cancelling an in-progress estate scan is not a `PATCH` to a status field in any honest sense — it's a one-way, non-idempotent action with side effects (the scan worker is signaled to stop), not a value the resource durably holds. It is a legitimate custom method:

```yaml
paths:
  /v1/estate-scans/{id}:cancel:
    post:
      summary: Cancel an in-progress estate scan
      operationId: cancelEstateScan
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        "200":
          description: Scan cancellation accepted; the scan transitions to CANCELLED
        "409":
          description: Scan is already in a terminal state (COMPLETED, FAILED, CANCELLED)
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }
```

Before reaching for a custom method, check whether the action is actually a Command from the Command Catalog that maps cleanly onto an existing resource field — most will. A custom method is the fallback for the minority that don't, not a shortcut around modeling the resource properly.

## Long-Running Operations

`SKILL.md`'s `202 Accepted` row specifies what the *initial* response contains — the resource ID and a status URL — but does not specify what that status URL returns when polled. This section closes that gap with Geewax's `Operation` resource: a standard, reusable shape for tracking asynchronous work, carrying at minimum a unique operation name, a `done: boolean`, and — once `done` is true — either a `response` field (the result, shaped like whatever the triggering call would have returned synchronously) or an `error` field. The `error` field is not a new error type: it is `SKILL.md`'s existing `ErrorResponse.error` object, same `code`/`message`/`details` structure, reused exactly.

Worked example: starting an estate scan is async — the scan itself can run for minutes against a large storage source, far past what a synchronous request/response cycle should hold open.

**(a) The initial `202 Accepted` response**, extending what `SKILL.md` already sketches for this status code:

```yaml
# POST /v1/estate-scans
# 202 Accepted
{
  "id": "es_8f3c1a90",
  "status": "PENDING",
  "operation": "/v1/operations/op_4b2e7f10"
}
```

**(b) The `Operation` resource schema itself**, as an OpenAPI `components/schemas/Operation` fragment:

```yaml
components:
  schemas:
    Operation:
      type: object
      required: [name, done]
      properties:
        name:
          type: string
          description: Unique operation identifier
          example: operations/op_4b2e7f10
        done:
          type: boolean
          description: True once the operation has finished, successfully or not
        response:
          type: object
          description: >
            Present only when done is true and the operation succeeded.
            Shaped like the resource the triggering call would have
            returned synchronously — e.g. the completed EstateScan.
        error:
          $ref: "#/components/schemas/ErrorResponse/properties/error"
          description: >
            Present only when done is true and the operation failed.
            Same code/message/details shape as ErrorResponse.error —
            not a separate error type.
```

**(c) The polling endpoint:**

```yaml
paths:
  /v1/operations/{id}:
    get:
      summary: Poll the status of a long-running operation
      operationId: getOperation
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        "200":
          description: Current operation state
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Operation" }
```

The polling contract is plain: clients poll `GET /v1/operations/{id}` until `done` is `true`, then read either `response` or `error` — never both, and never poll indefinitely without a client-side timeout, since a stalled worker or crashed scan should surface as an eventual `error`, not silence. The domain outcome also arrives via a Domain Event, per `SKILL.md`'s `202 Accepted` row — the `Operation` resource is for client-side status polling, the Domain Event is for other Bounded Contexts reacting to the outcome; they are not substitutes for each other.

## Resource Revisions (Optimistic Concurrency)

`SKILL.md`'s `409 Conflict` row already covers one kind of conflict — an Aggregate guard rejecting a request because it violates a business rule. Resource revisions solve a different problem: two clients racing to write the *same* resource, where the second write silently overwrites the first client's changes because neither client knew about the other. That's a lost update, not a business-rule violation, and it needs a different mechanism to detect: `etag`/`If-Match`.

The mechanism: every representation of a revisable resource carries a revision identifier — an opaque `etag` — in the response. A client performing a conditional update sends that same identifier back on the write. The server compares it against the resource's current revision; if they don't match, the resource changed since the client last read it, and the server rejects the write rather than silently clobbering the intervening change.

Worked example: two compliance reviewers open the same Compliance Gap and both attempt to update its `status` field — one to `REMEDIATED`, one to `WAIVED` — without knowing the other is also looking at it.

```yaml
# GET /v1/compliance-gaps/{id}
# 200 OK
# ETag: "rev-7f2a91"
{
  "id": "cg_2b91f0a3",
  "status": "OPEN",
  "severity": "HIGH"
}
```

```yaml
# PATCH /v1/compliance-gaps/{id}
# If-Match: "rev-7f2a91"
{
  "status": "REMEDIATED"
}
```

If the second reviewer's `PATCH` arrives after the first reviewer's update already changed the revision, the server rejects it:

```yaml
# 409 Conflict
{
  "error": {
    "code": "REVISION_MISMATCH",
    "message": "The compliance gap was modified since it was last read. Reload and retry."
  }
}
```

`REVISION_MISMATCH` (or an equivalent `[RESOURCE]_REVISION_MISMATCH` code) is deliberately distinct from the business-rule error codes `SKILL.md`'s `409 Conflict` row already documents (e.g. a status transition an Aggregate guard forbids) — both share the `409` status because both are conflicts, but the error `code` tells the client which kind it is and what to do about it: reload-and-retry for a revision mismatch, versus reconsider-the-request for a business-rule violation. Apply this pattern only to resources with real concurrent-writer risk — `DataAsset` and `ComplianceGap` are the plausible candidates in this domain, since multiple scanners or reviewers can plausibly race on the same record; a resource only ever written by one process at a time does not need it.

## Field Masks

`SKILL.md`'s HTTP Method table notes that `PATCH` partially updates a resource but leaves one question unstated: what does an *omitted* field in the request body mean? The field-mask convention answers it: an omitted field means "leave unchanged." An explicit `null` means "clear the field." These are different instructions, and a resource with many optional fields needs to be able to express both without ambiguity.

```yaml
# PATCH /v1/data-assets/{id}
{
  "sensitivityLevel": "Restricted",
  "notes": null
}
```

Here, `sensitivityLevel` is set to `Restricted`, `notes` is explicitly cleared, and every other field on the resource — `classification`, `storageSourceId`, and so on — is left exactly as it was, because none of them appear in the body at all. For resources where this still isn't precise enough (for example, a nested object where the client wants to update one nested field without re-sending the whole object), an explicit `updateMask` query parameter names the field paths the request intends to touch:

```
PATCH /v1/data-assets/{id}?updateMask=sensitivityLevel,notes
```

A parallel, smaller idea exists on the response side: a `fields` query parameter on `GET` lets a caller request only a subset of a large resource's fields back, rather than the full representation — useful for a Read Model with many columns where a caller only needs a handful. This is a secondary convenience, not a required part of every collection endpoint the way pagination is.

## Singleton Sub-resources

`SKILL.md`'s Resource Naming rule "nest only one level deep" governs nesting *depth* — how far a sub-resource path can go (`/data-assets/{id}/classification`, not deeper). A singleton sub-resource is a different, more specific idea: it's about how many instances of that sub-resource can exist per parent, and which standard methods apply to it. A singleton has exactly one instance per parent, is never listed or independently created or deleted, and supports only `GET` and `PATCH`/`PUT` at a fixed path.

`/v1/data-assets/{id}/classification` — already present in `SKILL.md` as the anti-pattern table's correction for the classify action — is the illustrative case: in this skill's actual convention, classification is a field on the `DataAsset` resource itself, reached through that nested path only for the `PATCH`. Treated formally as a singleton sub-resource, the same path would also support `GET /v1/data-assets/{id}/classification` to read the classification object on its own, while explicitly having no `POST` (a data asset's classification isn't created independently of the data asset) and no `DELETE` (it isn't removed independently either — only ever replaced or updated). This is not a proposal to change how classification currently works in this skill; it's the same resource, named precisely: a one-per-parent object with no independent lifecycle, Get/Update only.

The pattern generalizes to any future resource that is genuinely settings-like — one-per-parent, no independent create/delete — such as a hypothetical `/v1/estate-scans/{id}/config` holding the tunable parameters for a single scan (file-type filters, size limits, throttling). No `/v1/estate-scans/{id}/configs` collection, no `POST` to create a config, no `DELETE` to remove one — it exists for exactly as long as the parent `EstateScan` does, addressed at that one fixed path.
