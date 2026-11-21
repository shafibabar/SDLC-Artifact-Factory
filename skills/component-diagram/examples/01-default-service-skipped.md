# Example 1 — A Default Service: No Diagram

Self-contained. **ShelfMark** runs lending for a regional library network: members borrow and reserve books, librarians check items in and out. **Standard** profile. The container diagram has three deployables: `catalogue` (search and item records), `loans` (borrowing, returns, reservations) and the web app. The Loans context has one Aggregate (`Loan`), a repository, HTTP handlers, and publishes `LoanOpened`, `LoanReturned` and `ReservationReady` through the outbox. Default stack (Go, chi, PostgreSQL, Redpanda).

## Input

> **User:** "Draw component diagrams for catalogue and loans so the architecture set is complete. Number the arrows so new developers can follow a checkout from start to finish."

## Working it

- **Loans:** one Aggregate, one repository, handlers, outbox events: exactly the default skeleton from `go-project-structure`. A diagram would restate it and answer no question anyone has (Fairbanks; Brown: component diagrams are optional, drawn where they add value; D047-13). **Skip.**
- **Catalogue:** also default, except that it rebuilds a search index from item events. Checking with the user: the index is the container diagram's search container, fed by a standard consumer; nothing inside the service departs from the skeleton. **Skip.**
- **Numbered arrows:** declined. A component diagram is a static module view of what may depend on what; it has no time dimension (Clements). The checkout flow belongs in a C4 dynamic diagram or a sequence diagram, which can be drawn for the onboarding guide.
- **The set is complete** when each service is accounted for: here, two one-line records.

## Output: the service records (no component-diagram artifact)

In `artifacts/shelfmark/design/architecture/container-diagram.md`, under *Open Questions → Hand-offs* (or in each context's design folder index):

```markdown
- catalogue: default skeleton (go-project-structure), no component diagram
- loans: default skeleton (go-project-structure), no component diagram
```

And in the reply to the user:

> Both services follow the default skeleton, so neither gets a component diagram; each has a one-line record instead. A diagram would repeat `go-project-structure` without answering anything. For the checkout walkthrough, a sequence diagram (or a C4 dynamic diagram) shows the steps in order; a component diagram can't, because it shows what depends on what, not what happens when.

## Why this is right

- Each service was checked against the default and recorded, so "complete" means accounted for, not drawn.
- The step-numbering request got its reason (no time dimension in a module view) and an alternative that does show order.
- No artifact means nothing for the validator to check; the record lines are the output.
