# Resource and Method Design

Reference for `api-contract-design` steps 3 and 4. Grounded in Geewax (*API Design Patterns*: resource-oriented design, standard and custom methods, field masks, singleton sub-resources). OpenAPI fragments below are the contract itself, not implementation code; the code is the `go-*` and `python-*` skills.

## Naming resources

Resources are domain concepts from the Ubiquitous Language, not tables or implementation terms.

| Good | Poor | Why |
|---|---|---|
| `/v1/invoices` | `/v1/invoice-rows` | a table name leaks storage; every migration becomes a breaking change |
| `/v1/delivery-slots` | `/v1/slots` | vague; the domain term disambiguates |
| `/v1/refund-requests` | `/v1/requests` | ambiguous across contexts |

- Plural nouns for a collection (`/invoices`), the id for one item (`/invoices/{id}`).
- Kebab-case in paths (`/delivery-slots`), not camelCase or snake_case.
- Nest at most one level (`/invoices/{id}/lines`), not deeper; a deeper child is its own top-level resource with a filter.
- Name the resource from the Bounded Context's language; when two contexts use one word differently, each context's API uses its own.

## Mapping Commands and queries

| HTTP method | Maps to |
|---|---|
| `POST` | a Command that creates a resource or triggers an action |
| `PUT` | a Command that replaces a resource entirely |
| `PATCH` | a Command that changes part of a resource |
| `DELETE` | a Command that removes a resource |
| `GET` | a Query, served by a Read Model |

Every Command in the Command Catalog has an endpoint; every Read Model has a `GET`. The Catalog supplies the Commands, their rejections by kind and their idempotency keys; this skill assigns methods, paths and status codes.

## Custom methods

Most Commands are a create or a field update on a resource. A few are not: cancelling a running job, publishing a draft, approving an invoice are one-way actions with side effects, not a value the resource durably holds. The disciplined form is a **custom method**: `POST /{resource}/{id}:verb`.

- **Check first** whether the action is a state change the resource holds (a `status` field updated by `PATCH`). If it is, use that; a custom method is the fallback for the minority that are not.
- A custom method is not a return to free-floating verbs. `POST /classifyInvoice` has no resource in the path; `POST /invoices/{id}:approve` is scoped to one.
- It is a `POST`, so it needs the idempotency decision (`./responses-and-errors.md`) and its own error responses.

```yaml
paths:
  /v1/invoices/{id}:approve:
    post:
      summary: Approve an invoice for payment
      operationId: approveInvoice
      responses:
        "200": { description: The invoice is approved }
        "409":
          description: The invoice is already in a terminal state
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }
```

## Partial updates and field masks

An omitted field in a `PATCH` body means "leave unchanged"; an explicit `null` means "clear it". These are different instructions, and the contract states both. For a nested object where the client changes one inner field, an explicit mask removes the doubt: `PATCH /invoices/{id}?updateMask=dueDate,note`. On the response side, a `fields` query parameter on a `GET` lets a caller ask for a subset of a large resource; it is a convenience, not a requirement of every collection.

## Singleton sub-resources

A settings-like child with exactly one instance per parent and no independent lifecycle (`/projects/{id}/settings`) supports `GET` and `PATCH` only: no collection, no `POST`, no `DELETE`. Name it as a singleton instead of defaulting to a one-level child collection.

## Filtering and sorting

Filters are named query parameters using canonical field names (`?status=overdue&customerId=...`); repeat the parameter for several values. Every filterable and sortable field is declared in the spec, and only fields the Read Model indexes are sortable; an undocumented filter does not exist. This is a deliberate choice over a single filter-expression string (Geewax): it needs no expression parser and is easy for a product owner to review. Adopt an expression language only for a concrete need for compound or boolean filters.

## Chatty resources

A detail view that needs N follow-up calls per item sends a front end into a request storm. Shape the Read Model, and its `GET` response, to serve the whole view in one call.
