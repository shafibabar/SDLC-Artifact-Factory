# Shaping Read Models

The detail behind `SKILL.md` § 1: what a Read Model holds, what it copies, when to split it and how to name it. Self-contained. Grounded in Khononov (*Learning Domain-Driven Design*: Read Models answer to queries and are decoupled from Aggregate boundaries) and Brandolini (*Introducing EventStorming*: a read model is the information an actor needs before a decision), as summarised in `research/domain-driven-design/learning-ddd-khononov.md` and `research/domain-driven-design/introducing-eventstorming-brandolini.md`. No code: tables and indexes are `data-model-design`'s, code is `go-repository-pattern`'s.

## 1. Two boundaries, two forces

| | Aggregate | Read Model |
|---|---|---|
| Drawn around | a rule that must hold in one transaction | one caller's question |
| Source of truth | yes | no: derived, replaceable |
| Spans | one consistency boundary | as many Aggregates (and, through published events, contexts) as the question needs |
| Changes when | the rules change | the screen or caller changes |

Never ask "which Aggregate does this Read Model belong to?" Ask "which question does it answer, for whom, and what do they need to see?" Where Event Storming Process Modelling ran, its green stickies (the information an actor looks at before issuing a Command) are the first list of Read Models.

## 2. What goes in

1. **Fields the caller shows, filters or sorts on.** Every field names at least one caller that uses it. A field "in case" widens every read and makes every later change harder.
2. **Display values, not just identifiers.** If the caller shows a name, carry the name. On rung 1 that is a join; on rung 2 the projector copies it when the event arrives.
3. **Identifiers the caller navigates with.** A list carries the ID of a related thing it links to, not that thing's whole detail.
4. **Value Objects flattened to what is shown.** A money amount becomes amount and currency; a status becomes its display term. Read Models hold no behaviour.
5. **The tenant**, on every row.
6. **Freshness fields** on projected Read Models: the version applied per row; an *as of* time on summaries (`./consistency-patterns.md`).

### Copy or reference?

| The caller… | Decision |
|---|---|
| shows a related thing's name or status on every row | copy the display value |
| navigates to the related thing | carry its ID only |
| shows a count or total over many things | carry the computed figure, not the items |
| filters or sorts by a related value | copy it, so the filter runs on the Read Model |
| needs the related thing's full detail | that is another Read Model, fetched when opened |

### The N+1 test

If serving one page would need one extra read per row to resolve something (twenty rows, twenty lookups of a dish name), the missing value belongs in the Read Model.

**The cost of copying:** when the source value changes, the rows that copied it must change. On rung 1 the join does this for free. On rung 2 the projector handles the change event (`DishRenamed`, `ProductRetitled`) and updates every row holding the old value. If the source context does not publish that change, copying is not safe: note it as an open question for the context map (`context-map-patterns`) rather than copying a value that silently goes stale.

## 3. Variable-structure fields

A field whose content varies per row (a list of tags, line items, extracted entities) can be stored as a structured document column when the caller reads it whole. Move it to its own Read Model (or child rows) when:
- callers filter or sort by something inside it;
- it grows without bound on one row (a hot, ever-larger row);
- different callers need different parts of it often.

## 4. When to split one Read Model into several

| Trigger | Why |
|---|---|
| Different callers need different fields | the wide model makes every caller pay for every field |
| Different staleness or freshness needs | one view can't promise both |
| Different update rhythm | a list changes per event, a summary is recomputed more coarsely |
| Unbounded embedded collections | see § 3 |

Do not split before one of these applies: each Read Model is one more thing to keep right, and on rung 2 one more projector.

## 5. Three common kinds

| Kind | Answers | Typical shape |
|---|---|---|
| **List** | "which ones match?" (browse, filter, page) | one row per item, many copied display values, only the columns the list shows |
| **Detail** | "everything about this one" | one row per item, may hold structured sub-documents |
| **Summary** | "how many, how much, how are we doing?" | one row per tenant or per grouping; counts and totals; always an *as of* |

A **search** Read Model is a list served from a search index (full-text, facets); a **lookup** answers a single fast question another context asks.

## 6. Naming

- The Read Model is named for what it answers, in the context's Ubiquitous Language: `ShiftsNeedingPeople`, `KitchenPrepSheet`, `GearSearch`, `OverdueInvoices`. Not `<Aggregate>View`, which drags the Aggregate's shape back in.
- Storage names follow from it (`kitchen_prep_sheet`); the physical naming rules are `data-model-design`'s.
- A projector is named for the Read Model it writes (`KitchenPrepSheet` projector), one per Read Model unless two share every event and are rebuilt together.
