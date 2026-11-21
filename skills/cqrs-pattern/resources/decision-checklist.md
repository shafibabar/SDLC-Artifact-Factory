# CQRS Decisions Checklist

Run after `./scripts/validate-cqrs-decisions.sh` exits clean. The script checks structure; these items need judgement.

## The ladder
- [ ] Every context starts at the Simple Read Model; each projected context names a trigger with evidence from the NFRs, the screens or a measurement.
- [ ] No trigger is a wish ("might scale", "best practice", "Core subdomain", "we have a broker").
- [ ] Event-sourced Aggregates (from `aggregates.md`) put their context on projections.
- [ ] No context adopts event sourcing because it wants projections.
- [ ] Every context records *revisit when*: a signal, not a date.

## Consistency
- [ ] Every projected view states the lag the business accepts and why, and which guarantees it gives (read-your-writes, monotonic reads, consistent prefix); "eventually consistent" alone is not a promise.
- [ ] Only views someone acts on with no rule in the Aggregate behind them are kept off projections for lag reasons.
- [ ] Read-your-writes is provided for the writer in every projected context, and the record says how.
- [ ] Views served from replicas or regions say how monotonic reads are kept.
- [ ] No rule is checked against a Read Model; guards stay in the Aggregate.

## Across services
- [ ] Every query that needs data from more than one service is listed.
- [ ] Each uses API Composition unless a trigger is named; a CQRS view names its owner and the published events that feed it.
- [ ] No query reads another service's tables.

## Hand-off
- [ ] The domain-modeler can design each Read Model knowing whether it is a query over the write tables or a projection, and its staleness.
- [ ] `traces-to` names the Aggregate designs, the event catalogs, the NFR specification and the context map (and the container diagram, once cross-service queries are settled).
