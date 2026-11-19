# Example 1 — Lean: A Small App Asking for Verb Endpoints, 200-with-Error Bodies and Offset Paging

Self-contained. **Pantrybook** is a recipe box app for one household cooking club: one web front end, one backend service, **Recipes**, with three resources (recipes, collections and shopping lists). **Lean** profile, one consumer (the club's own front end), a few dozen users.

## Input

> **User:** "My developer wants `POST /searchRecipes` to return everything, every response as 200 with `{"ok": false, "error": "..."}` on failure so the front end has one code path, `?page=2&size=50` for paging, and no versions: we'll just change it when we need to."

## Working it

- **Resources, not verbs.** `POST /searchRecipes` is a read, so it is `GET /v1/recipes` with named filters (`?ingredient=...`). Collections and shopping lists are their own plural resources.
- **Errors in the status code.** A `200` with a failure body hides the error from retries and monitoring. Use the right 4xx or 5xx and the one error envelope; the front end's single code path is the envelope, not the status.
- **Cursor paging.** Recipes are added all the time, so offsets skip or repeat rows. `?cursor=...&limit=...` with a capped `limit` and a stable order.
- **A version from day one, proportionate to lean.** The path starts `/v1/`. Additive changes (a new optional field) need no new version, and the front end ignores fields it does not know (Tolerant Reader). There is no parallel-version machinery yet; a breaking change would add `/v2/` when there is a second consumer to protect.
- **Spec first, at the manifest path.** `design/recipes/openapi.yaml`, copied into the service repository at Implement; at lean the summary is skipped.
- **Auth and idempotency.** A global bearer scheme, with the service verifying the token itself; the health endpoint is excluded. A `POST` that creates a recipe could be double-submitted, so it carries an `Idempotency-Key`; the `GET`s do not.

## Output: the reply (a spec only at lean), shown as `design/recipes/openapi.yaml`

````yaml
openapi: 3.1.0
info:
  title: Recipes API
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
  /v1/recipes:
    get:
      summary: List recipes, optionally filtered by ingredient
      operationId: listRecipes
      parameters:
        - { name: ingredient, in: query, schema: { type: string } }
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, default: 25, maximum: 100 } }
      responses:
        "200": { description: A page of recipes in a stable order, with nextCursor }
        "401": { $ref: "#/components/responses/Error" }
    post:
      summary: Add a recipe
      operationId: createRecipe
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201": { description: The recipe was created }
        "400": { $ref: "#/components/responses/Error" }
        "401": { $ref: "#/components/responses/Error" }
  /v1/recipes/{id}:
    get:
      summary: Get one recipe
      operationId: getRecipe
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: The recipe }
        "404": { $ref: "#/components/responses/Error" }
  /v1/collections:
    get:
      summary: List the club's collections
      operationId: listCollections
      parameters:
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, default: 25, maximum: 100 } }
      responses:
        "200": { description: A page of collections }
  /v1/shopping-lists:
    get:
      summary: List shopping lists
      operationId: listShoppingLists
      parameters:
        - { name: cursor, in: query, schema: { type: string } }
        - { name: limit, in: query, schema: { type: integer, default: 25, maximum: 100 } }
      responses:
        "200": { description: A page of shopping lists }
components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      description: Client-generated unique value; a repeat returns the first result. Retention is stated in the summary of the service.
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
    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string, example: RECIPE_NOT_FOUND }
            message: { type: string }
````

> **Reply summary:** reads are `GET`s on nouns; failures use real status codes in one envelope; cursor paging with a capped limit; `/v1/` from day one with additive change and no new version until something breaks; the spec is written first at `design/recipes/openapi.yaml` and copied into the service repository at Implement; the service verifies the bearer token itself; no tenant path variable, because this is one household club.
