# Responses, Errors, Pagination, Operations and Revisions

Reference for `api-contract-design` steps 5 and 6. Grounded in Geewax (the error model, the long-running Operation, resource revisions) and Winteringham (every documented status code and header is testable). OpenAPI fragments are the contract, not implementation code.

## Status codes

| Status | When |
|---|---|
| `200 OK` | a successful `GET`, `PUT`, `PATCH` or custom method |
| `201 Created` | a `POST` that creates a resource |
| `202 Accepted` | accepted for async work; the body carries the resource id and an Operation to poll |
| `204 No Content` | a successful `DELETE`, or an action with no body |
| `400 Bad Request` | malformed or structurally invalid payload |
| `401 Unauthorized` | token missing or expired |
| `403 Forbidden` | token valid, permission missing |
| `404 Not Found` | the resource does not exist |
| `409 Conflict` | a business rule rejected the request, or a revision mismatch (distinct code) |
| `422 Unprocessable Entity` | structurally valid but semantically invalid |
| `429 Too Many Requests` | rate limit exceeded; say how long to wait |
| `500 Internal Server Error` | unexpected; never expose internal detail |

Never return a failure with a `200`. Clients, gateways, retries and monitoring key on the status code.

## One error envelope

Every error response, on every documented failure branch, uses one shape: a top-level `error` object with a machine-readable `code` (SCREAMING_SNAKE_CASE, domain-specific, such as `INVOICE_NOT_FOUND`), a human-readable `message`, and an optional `details` array of field-level problems. Domain codes may sit under a small set of canonical categories (invalid argument, not found, permission denied, failed precondition); that is an optional cross-reference, not a replacement. A `500` returns a generic code and a correlation id; stack traces, SQL and internal error text go to logs, not the body.

```yaml
components:
  schemas:
    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string, example: INVOICE_NOT_FOUND }
            message: { type: string }
            details:
              type: array
              items:
                type: object
                properties:
                  field: { type: string }
                  message: { type: string }
```

## Pagination

Every collection shares one convention; never invent a per-endpoint variant.

- **Cursor pagination is the default:** `?cursor=<opaque>&limit=<n>`, with `limit` capped (a default and a maximum stated). The response carries `nextCursor`, null on the last page. Cursors are opaque; the server encodes the sort position, never a raw offset.
- **Offset pagination** only for a small, stable admin collection: on large or frequently written collections it skips or repeats rows as data moves.
- **A stable order is part of the contract:** a sort field plus an id tiebreaker. Without a deterministic total order, cursors are meaningless.

## Long-running work: the Operation

A request whose work outlasts a normal request returns `202 Accepted` at once, with the resource id and a link to an **Operation** the client polls. Specify what the polling endpoint returns; a "status URL" with no documented shape is an unfinished contract.

```yaml
components:
  schemas:
    Operation:
      type: object
      required: [name, done]
      properties:
        name: { type: string, example: operations/op_4b2e7f10 }
        done: { type: boolean }
        response: { type: object, description: Present when done and successful; shaped like the resource the call would have returned }
        error: { $ref: "#/components/schemas/ErrorResponse/properties/error" }
```

Clients poll `GET /v1/operations/{id}` until `done` is true, then read `response` or `error`, never both, and apply a client-side timeout: a stalled worker surfaces as an eventual `error`, not silence. The domain outcome also arrives as a Domain Event.

## Revisions: lost updates

A `409` for a business-rule rejection is not a lost update. When two writers can race on one resource, every representation carries a revision (`ETag`), and a conditional write sends it back (`If-Match`). If the resource changed since the client read it, the server rejects the write with `409` and a distinct code (for example `REVISION_MISMATCH`), so the client knows to reload and retry rather than reconsider a business rule.

```yaml
# GET /v1/invoices/{id}      -> 200, ETag: "rev-7f2a91"
# PATCH /v1/invoices/{id}    If-Match: "rev-7f2a91"
# 409  { "error": { "code": "REVISION_MISMATCH", "message": "Reload and retry." } }
```

Carry revisions on resources with real concurrent-writer risk (several staff editing a record), not on every resource.

## Idempotency

An `Idempotency-Key` (a client-generated unique value) lets a client retry a request without repeating its effect: the server keeps the result for a stated window and returns it again for the same key. Declare it once as a reusable parameter and reference it where needed.

- **Needed** where a retry could repeat an effect: a `POST` that creates a resource or triggers an action, and a custom method.
- **Not needed** on `GET` (safe) or `PUT` and `DELETE` (idempotent by definition); a `PATCH` needs it only if its effect is not naturally idempotent (an increment).
- **State the window per product** (how long keys are kept and what a repeat returns); do not copy a fixed number.

## Security in the contract

A global security scheme (a bearer token) applies to every operation; health endpoints are excluded. The contract declares the requirement; every service verifies the token itself rather than relying on a gateway that may be bypassed (`api-gateway-design` is the first check, not the only one).

## Testable by design

Every documented status code, error branch and response header (security headers, an echoed idempotency key, a `Deprecation` header) can be tested. A contract that promises behaviour the test suite cannot assert is incomplete (Winteringham); the contract tests are `go-contract-test` and `python-contract-test`.
