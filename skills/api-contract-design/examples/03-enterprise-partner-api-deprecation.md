# Example 3 — Enterprise: A Field Renamed in a Live Partner API Is a Breaking Change

Self-contained. **Parcelhub** sells shipping to retailers; about 60 retail partners call its **Shipments** API to book parcels. **Enterprise** profile, a partner-facing API, live as v1. Some partners release only twice a year. A new carrier needs weights in grams, so `weightKg` must become `weightGrams`.

## Input

> **User:** "Rename `weightKg` to `weightGrams` in v1 and tell partners with a 30-day notice. Have every endpoint require an Idempotency-Key. We'll build the endpoints and generate the OpenAPI file from the code once it settles."

## Working it

- **A rename is breaking.** Any partner that reads `weightKg` breaks, known or not. v1 is not edited in place. The new shape is **v2**, run beside v1; v1 stays unchanged until it is retired.
- **Additive alternative, first.** A new optional `weightGrams` field added to v1 is additive and needs no new version, with `weightKg` kept. Here the carrier needs grams *and* the old unit is being dropped, so the change is breaking and v2 is the route.
- **Sunset sized to partners.** 30 days is too short for partners who ship twice a year. v1 is deprecated with a `Deprecation` response header and a sunset date, announced to every partner in the consumer registry, and kept running for 9 months; v1 is retired only when the registry shows no remaining caller.
- **Tolerant Reader.** The contract tells partners to ignore unknown response fields, so later additive changes never need a version.
- **Idempotency.** A key on every endpoint is declined: `GET`, `PUT` and `DELETE` are safe or idempotent already. It goes on the booking `POST` and the cancel custom method, kept 72 hours so partner retries across a weekend are safe.
- **Spec first, as a product.** A partner-facing contract is designed and reviewed with partners before the code; it is not generated afterwards. It lives at `design/shipments/openapi.yaml`, copied into the service repository at Implement.
- **Auth.** A global OAuth 2.0 client-credentials scheme for partners, verified by the service itself; the gateway is only the first check. Partner identity comes from the credential, so there is no tenant path variable.

## Output: `design/shipments/openapi.yaml` (v1 and v2) and `design/shipments/api-contract-summary.md` (frontmatter omitted in a reply)

````yaml
openapi: 3.1.0
info:
  title: Shipments API
  version: 2.0.0
  description: Consumers must ignore response fields they do not recognise.
security:
  - PartnerAuth: []
paths:
  /healthz:
    get:
      operationId: getHealth
      security: []
      responses:
        "200": { description: The service is up }
  /v1/shipments:
    post:
      summary: Book a parcel (deprecated; use v2)
      operationId: bookShipmentV1
      deprecated: true
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201":
          description: Booked. The Deprecation and Sunset headers are returned.
          headers:
            Deprecation: { schema: { type: string } }
            Sunset: { schema: { type: string } }
        "422": { $ref: "#/components/responses/Error" }
  /v1/shipments/{id}:
    get:
      summary: Get a shipment (deprecated; use v2)
      operationId: getShipmentV1
      deprecated: true
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: The shipment, with weightKg }
        "404": { $ref: "#/components/responses/Error" }
  /v2/shipments:
    get:
      operationId: listShipments
      parameters:
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, default: 25, maximum: 100 } }
      responses:
        "200": { description: A page of shipments in a stable order }
        "401": { $ref: "#/components/responses/Error" }
    post:
      operationId: bookShipment
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201": { description: Booked, with weightGrams }
        "422": { $ref: "#/components/responses/Error" }
  /v2/shipments/{id}:
    get:
      operationId: getShipment
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: The shipment, with weightGrams }
        "404": { $ref: "#/components/responses/Error" }
  /v2/shipments/{id}:cancel:
    post:
      summary: Cancel a booked shipment (a one-way action)
      operationId: cancelShipment
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "200": { description: Cancelled }
        "409": { $ref: "#/components/responses/Error" }
components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      description: Partner-generated unique value; a repeat within 72 hours returns the first result.
      schema: { type: string }
  responses:
    Error:
      description: An error, in the standard envelope
      content:
        application/json:
          schema: { $ref: "#/components/schemas/ErrorResponse" }
  securitySchemes:
    PartnerAuth:
      type: oauth2
      flows:
        clientCredentials:
          tokenUrl: https://auth.example.com/token
          scopes: {}
  schemas:
    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string, example: SHIPMENT_ALREADY_DISPATCHED }
            message: { type: string }
````

````markdown
# API Contract Summary: Shipments

- **Audience:** partner (about 60 retail integrations)

## Endpoints

| Method | Path | Command / Read Model | Auth | Idempotency |
|---|---|---|---|---|
| POST | /v1/shipments | BookShipment (deprecated) | PartnerAuth | Yes: Idempotency-Key, 72 hours |
| GET | /v1/shipments/{id} | ShipmentDetail Read Model (deprecated) | PartnerAuth | No: safe method |
| GET | /v2/shipments | ShipmentList Read Model | PartnerAuth | No: safe method |
| POST | /v2/shipments | BookShipment | PartnerAuth | Yes: Idempotency-Key, 72 hours |
| GET | /v2/shipments/{id} | ShipmentDetail Read Model | PartnerAuth | No: safe method |
| POST | /v2/shipments/{id}:cancel | CancelShipment | PartnerAuth | Yes: Idempotency-Key, 72 hours |

## Breaking Change Log

| Date | Change | Version | Sunset of the prior version |
|---|---|---|---|
| 2026-11-19 | `weightKg` replaced by `weightGrams` | v2 | v1 retired after 9 months, once no partner calls it |

## Consumer Registry

- 60 retail partner integrations: each has a named contact and a Consumer-Driven Contract test; v1 callers are notified individually.
````

> **Reply summary:** the rename is breaking, so v2 runs beside an unchanged v1; v1 is deprecated with a `Deprecation` and `Sunset` header and nine months' notice sized to partners who release twice a year; the key goes only on the booking and cancel `POST`s; the spec is written first at `design/shipments/openapi.yaml`; the service verifies the partner token itself; and no tenant path variable is added.
