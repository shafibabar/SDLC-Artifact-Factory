# Read Models Checklist

Run after `./scripts/validate-read-models.sh` exits clean. The script checks structure; these items need judgement.

## Inputs
- [ ] The rung of every Read Model matches the context's rung in `cqrs-decisions.md`; nothing was projected here that the decision left on rung 1, and a query rung 1 cannot serve went back to enterprise-architect with its evidence.
- [ ] Every screen, caller and question in the stories, screens and Event Storming read models has a Read Model, or a stated reason it needs none.

## Shape
- [ ] One Read Model per query shape; none mirrors an Aggregate "for reuse".
- [ ] Every field is shown, filtered or sorted on by a named caller.
- [ ] Display values the caller shows are carried, not resolved one row at a time.
- [ ] Every copied value names the event that changes it, and the source context actually publishes that event.
- [ ] The API can return each Read Model without reshaping it.
- [ ] Names come from the context's Ubiquitous Language, not `<Aggregate>View`.
- [ ] Tenant on every row and in every query; per-region views keep each tenant's data in its region.

## Projections
- [ ] Every event that creates, changes or removes rows is listed, including other Aggregates' and contexts' published events.
- [ ] The idempotency guard fits each event: "apply only if newer" for single-row updates; a processed-event record for deletes, many-row updates and running totals.
- [ ] Staleness matches `cqrs-decisions.md`; freshness is visible (version per row, *as of* on summaries); the lag alert sits below the accepted staleness.
- [ ] The writer sees their own change by the decided method, or the document says why the writer never reads this view.
- [ ] A cache, if any, has a time-to-live within the accepted staleness and is not the Read Model itself.
- [ ] The rebuild source holds the full history, or the document says what a rebuild cannot recover.
- [ ] Rebuilds go into a copy and switch in one step; nothing is patched by hand or truncated live.
- [ ] Every replaced event type keeps a handler or reads through an upcaster.
- [ ] Projectors only write their view: no Commands, no published events, no messages to people.
- [ ] No business rule reads any Read Model.

## Hand-off
- [ ] data-architect can derive tables, keys and indexes from the fields, keys and filters.
- [ ] `api-contract-design` can map each Read Model to one GET.
- [ ] `traces-to` names `cqrs-decisions.md`, the Aggregate design, the event catalog (and other contexts' catalogs copied from) and the NFRs.
