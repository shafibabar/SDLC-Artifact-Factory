# Example 2 — Standard: An Approve Action, a Lost Update and a Slow Export

Self-contained. **Leavebook** is the leave-request tool of one logistics company's HR department. **Standard** profile, one service, **Leave**, called by the company's own web front end. A request moves from submitted to approved or declined. Two managers sometimes open the same request at once, and the yearly leave report takes minutes to build.

## Input

> **User:** "Add `POST /approveLeave` with the request id in the body. For the two managers, return 409 if the second one tries. Make `GET /exportLeaveReport` hold the connection open until the file is ready."

## Working it

- **Approve.** Approval is a one-way action with side effects (the payroll hand-off, a notice), not a value the request holds, and a plain `PATCH` of a `status` field would let any caller set any status. A **custom method** on the resource: `POST /v1/leave-requests/{id}:approve`, the id in the path. A genuine state change (decline, withdraw) stays a `PATCH` of `status`.
- **Two managers.** Approving an already-approved request is a business-rule conflict: `409` with a code such as `LEAVE_ALREADY_DECIDED`. Two managers *editing* the same request is a lost update, which a `409` alone does not prevent. The request carries an `ETag`; an update sends `If-Match`; a mismatch returns `409` with a different code, `REVISION_MISMATCH`, so the front end reloads instead of re-reading a rule.
- **The export.** A `GET` that holds a connection for minutes, and triggers work, is wrong twice. `POST /v1/leave-requests:export` returns `202 Accepted` with an `Operation` to poll at `GET /v1/operations/{id}`; the finished file is a link in `response`. It is a `POST`, so it takes an `Idempotency-Key`.
- **Idempotency.** On the approve and export `POST`s, where a retry could repeat an effect; none on `GET`s or the `PATCH` of a status (setting it twice is harmless). Keys are kept 48 hours, because month-end retries span a weekend.
- **Spec first.** The Go developers write handlers against the reviewed contract at `design/leave/openapi.yaml`; the spec is not generated from annotations afterwards.
- **No tenant path variable:** one company.

## Output: `design/leave/openapi.yaml` and `design/leave/api-contract-summary.md` (frontmatter omitted in a reply)

````yaml
openapi: 3.1.0
info:
  title: Leave API
  version: 1.0.0
security:
  - BearerAuth: []
paths:
  /healthz:
    get:
      operationId: getHealth
      security: []
      responses:
        "200": { description: The service is up }
  /v1/leave-requests:
    get:
      operationId: listLeaveRequests
      parameters:
        - { name: status, in: query, schema: { type: string, enum: [submitted, approved, declined] } }
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, default: 25, maximum: 100 } }
      responses:
        "200": { description: A page of requests, ordered by submittedAt then id }
        "401": { $ref: "#/components/responses/Error" }
    post:
      operationId: submitLeaveRequest
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201": { description: The request was submitted }
        "422": { $ref: "#/components/responses/Error" }
  /v1/leave-requests/{id}:
    get:
      operationId: getLeaveRequest
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200":
          description: The request; the ETag header carries its revision
        "404": { $ref: "#/components/responses/Error" }
    patch:
      operationId: updateLeaveRequest
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
        - { name: If-Match, in: header, required: true, schema: { type: string } }
      responses:
        "200": { description: Updated; the new ETag is returned }
        "409": { $ref: "#/components/responses/Error" }
  /v1/leave-requests/{id}:approve:
    post:
      summary: Approve a request (a one-way action, not a field update)
      operationId: approveLeaveRequest
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "200": { description: Approved }
        "409": { $ref: "#/components/responses/Error" }
  /v1/leave-requests:export:
    post:
      summary: Start the yearly leave report (long running)
      operationId: exportLeaveReport
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "202":
          description: Accepted; poll the Operation named in the body
          content:
            application/json:
              schema:
                type: object
                properties:
                  operation: { type: string, example: /v1/operations/op_91c4 }
  /v1/operations/{id}:
    get:
      summary: Poll an Operation
      operationId: getOperation
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: The Operation }
        "404": { $ref: "#/components/responses/Error" }
components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      description: Client-generated unique value; a repeat within 48 hours returns the first result.
      schema: { type: string }
  responses:
    Error:
      description: An error, in the standard envelope
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorResponse" }
  securitySchemes:
    BearerAuth: { type: http, scheme: bearer }
  schemas:
    Operation:
      type: object
      required: [name, done]
      properties:
        name: { type: string }
        done: { type: boolean }
        response: { type: object, description: Present when done and successful; carries the report link }
        error: { $ref: "#/components/schemas/ErrorResponse/properties/error" }
    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string, example: REVISION_MISMATCH }
            message: { type: string }
````

````markdown
# API Contract Summary: Leave

- **Audience:** internal (the company's own front end)

## Endpoints

| Method | Path | Command / Read Model | Auth | Idempotency |
|---|---|---|---|---|
| GET | /v1/leave-requests | LeaveRequestList Read Model | BearerAuth | No: safe method |
| POST | /v1/leave-requests | SubmitLeaveRequest | BearerAuth | Yes: Idempotency-Key, 48 hours |
| PATCH | /v1/leave-requests/{id} | UpdateLeaveRequest | BearerAuth | No: a repeat is harmless; If-Match guards lost updates |
| POST | /v1/leave-requests/{id}:approve | ApproveLeaveRequest | BearerAuth | Yes: Idempotency-Key, 48 hours |
| POST | /v1/leave-requests:export | ExportLeaveReport | BearerAuth | Yes: Idempotency-Key, 48 hours |

## Breaking Change Log

No breaking changes recorded yet.

## Consumer Registry

- Leavebook web front end (internal); contract test owner: frontend team.
````

> **Reply summary:** approve is a custom method on the resource; the two-manager overwrite is a revision check, distinct from the business-rule 409; the export is a 202 with a pollable Operation, not a held-open GET; the idempotency key goes only on the retry-sensitive POSTs, kept 48 hours; the spec is written first at `design/leave/openapi.yaml`; every documented status code, header and error branch gets a contract test.
