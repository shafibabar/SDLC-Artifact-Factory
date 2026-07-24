# OpenAPI Spec Structure — Full Worked Example

The complete top-to-bottom worked example of an `api/openapi.yaml` file, moved here from `SKILL.md` as illustrative reference material. Self-contained — loadable without reading `SKILL.md` first.

This shows one resource (`DataAsset`) end-to-end — `info`, `servers` with the `tenantId` multi-tenancy variable, global `security`, `tags`, a complete `paths` entry for `GET /v1/data-assets`, and the `components` shared by every resource in the spec: `schemas`, `parameters`, and `securitySchemes`. The pattern shown for `/v1/data-assets` repeats for every other resource (`/v1/storage-sources`, `/v1/compliance-gaps`, `/v1/estate-scans`) — this file does not re-derive it four times.

---

```yaml
openapi: 3.1.0
info:
  title: Data Estate & Compliance API
  version: 1.0.0
  description: >
    Contract for the data estate mapping and compliance platform. This spec
    is the source of truth — server-side code is generated from it or
    validated against it, never the reverse.

servers:
  - url: https://api.example.com/{tenantId}
    description: >
      Production. The tenantId path variable routes each request to the
      tenant's physically isolated database and resources (physical
      multi-tenancy, not a shared-schema tenant column).
    variables:
      tenantId:
        description: The requesting tenant's unique identifier.
        default: t_00000000

security:
  - BearerAuth: []

tags:
  - name: DataAssets
    description: >
      Files, records, and structured data discovered and classified during
      estate scans.
  - name: Operations
    description: Poll status for long-running asynchronous work.

paths:
  /v1/data-assets:
    get:
      summary: List data assets
      operationId: listDataAssets
      tags: [DataAssets]
      parameters:
        - name: cursor
          in: query
          required: false
          schema:
            type: string
          description: >
            Opaque pagination cursor from a previous response's
            pagination.nextCursor. Omit to fetch the first page.
        - name: limit
          in: query
          required: false
          schema:
            type: integer
            default: 25
            maximum: 100
          description: Maximum number of items to return.
        - name: sensitivityLevel
          in: query
          required: false
          schema:
            type: string
            enum: [Public, Internal, Confidential, Restricted]
          description: Filter to data assets at this sensitivity level.
        - name: storageSourceId
          in: query
          required: false
          schema:
            type: string
          description: Filter to data assets discovered in this storage source.
        - name: sort
          in: query
          required: false
          schema:
            type: string
            default: classifiedAt
          description: Field to sort by. Only Read-Model-indexed fields are sortable.
        - name: order
          in: query
          required: false
          schema:
            type: string
            enum: [asc, desc]
            default: desc
      responses:
        "200":
          description: A page of data assets, in stable deterministic order.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/DataAssetListResponse"
        "401":
          description: JWT missing or expired.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "403":
          description: JWT valid but insufficient permissions.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"

  /v1/operations/{id}:
    get:
      summary: Poll the status of a long-running operation
      operationId: getOperation
      tags: [Operations]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: Current operation state.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Operation"

components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: false
      schema:
        type: string
        format: uuid
      description: >
        Client-generated UUID v4. If provided, the server returns the stored
        result for any duplicate request with the same key within 24 hours.

  schemas:
    DataAsset:
      type: object
      required: [id, storageSourceId, classification, sensitivityLevel, createdAt]
      properties:
        id:
          type: string
          example: da_7c1f2e88
        storageSourceId:
          type: string
          description: The storage source this data asset was discovered in.
          example: ss_4a9b0e12
        classification:
          type: string
          description: The data classification assigned during an estate scan.
          example: PII
        sensitivityLevel:
          type: string
          enum: [Public, Internal, Confidential, Restricted]
        notes:
          type: string
          nullable: true
        createdAt:
          type: string
          format: date-time

    DataAssetListResponse:
      type: object
      required: [items, pagination]
      properties:
        items:
          type: array
          items:
            $ref: "#/components/schemas/DataAsset"
        pagination:
          type: object
          required: [nextCursor]
          properties:
            nextCursor:
              type: string
              nullable: true
              description: Opaque cursor for the next page; null when this is the last page.

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

    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code:
              type: string
              description: Machine-readable error code in SCREAMING_SNAKE_CASE
              example: DATA_ASSET_NOT_FOUND
            message:
              type: string
              description: Human-readable description suitable for display
              example: "The data asset with ID abc123 was not found"
            details:
              type: array
              description: Field-level validation errors
              items:
                type: object
                properties:
                  field: { type: string }
                  message: { type: string }

  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

Two things worth calling out. First, `components/schemas/Operation` here is copied field-for-field from `references/advanced-resource-patterns.md` — same `name`/`done`/`response`/`error` properties, same `required: [name, done]`, same `$ref` into `ErrorResponse.properties.error` rather than a redefined error shape. The two files describe the same spec from two different angles (this one the full skeleton, that one the async-operations pattern in depth) and must never drift apart; the `GET /v1/operations/{id}` path shown above is the same polling endpoint documented there, included here so `Operation` has a concrete referencing endpoint rather than sitting unused in `components`. Second, `components/parameters/IdempotencyKey` and `components/securitySchemes/BearerAuth` are copied unchanged from `SKILL.md`'s Idempotency Header and Authentication sections respectively — `IdempotencyKey` is defined once here as a reusable `components.parameters` entry and referenced via `$ref: "#/components/parameters/IdempotencyKey"` on every mutating endpoint's `parameters` list, rather than repeated inline on each `POST`/`PUT`/`PATCH` operation.
