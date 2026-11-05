# Evolving a Schema

The detail behind `SKILL.md` § 2: classifying a change, making additive changes safely, the breaking-change protocol, and the different rules for stored events. Grounded in Young (*Versioning in an Event Sourced System*), Kleppmann (*Designing Data-Intensive Applications*, Ch. 4), Newman (*Building Microservices*, the tolerant reader) and Khononov (*Learning Domain-Driven Design*, upcasting), as summarised in `research/domain-driven-design/versioning-event-sourced-system-young.md`, `research/software-architecture/designing-data-intensive-applications-kleppmann.md`, `research/software-architecture/building-microservices-newman.md` and `research/domain-driven-design/learning-ddd-khononov.md`. The rule itself is D047-1.

## 1. Classify the change first (Young's test)

| The change | Class | What to do |
|---|---|---|
| Add an optional field whose default is **true for old events** | additive | in place; same type; new schema version |
| Add a new event type | additive | a new subject; nothing else changes |
| Add an enum value | additive, **with notice** | in place, but announce it and wait out a window first: a consumer matching every value with no default branch breaks on the new one |
| Make an optional field required; add a required field | breaking | new type |
| Rename a field (even with an alias) | breaking | new type: a reader of the old name silently gets nothing |
| Change a field's type or unit (`amount` decimal → `amountMinor` integer) | breaking | new type |
| Remove a field a consumer may read | breaking | new type |
| The meaning changed: a different thing happened in the business | **a different event** | a new event with a new business name; no converter exists (Young) |

Young's rule: if every field of the new shape can be derived from the old one, it is a new *version* of the same fact; if the meaning changed, it is a new *event*. For **published** events this plugin is stricter than Young on the first case: a convertible but breaking change still gets a new, descriptive type, not a `_v2` (D047-1).

**Defaults must tell the truth about history.** A new field's default is what old events will be read as. "Zero" for an unknown amount, or `false` for "was it express?" when old events never recorded it, silently rewrites history. Prefer an explicit "unknown" (an absent optional field, or an `UNKNOWN` enum value).

## 2. Additive changes: the weak-schema rules

Readers are **tolerant** (Newman, Young's weak schema): they read the fields they know by name, ignore the rest, and fill missing optional fields with defaults. Under that discipline, only add; never rename; never change a field's type or meaning; give every new field a correct default. Kleppmann's terms:
- **backward compatible:** new readers can read old data;
- **forward compatible:** old readers can read new data.

Message-passing between services needs both, because producers and consumers deploy independently.

## 3. The breaking-change protocol

A breaking change is **never made in place** on a published type.

1. **Name a new type** that says what is different: `charge.captured` → `charge.captured-in-minor-units` for a unit change; a new verb when the meaning shifted (`booking.confirmed` → `booking.provisionally-held`). Never a `.v2` suffix.
2. **Register its schema** (or add its schema file) before any producer emits it. The old one stays.
3. **Publish both** for the same business fact, from the same transaction, during the transition window.
4. **Announce a deprecation date** for the old type, with named consumers and a window (typically 4–8 weeks).
5. **Confirm by telemetry** that no consumer group has read the old type within the window (consumer-group offsets or consumption metrics), not by asking around.
6. **Stop publishing the old type.** Keep its schema registered forever: retained or replayed records still carry it.

**Why not `.vN` in the type.**
- Every consumer must enumerate versions, and change code for each one, even when the change doesn't touch the fields it reads.
- The suffix drifts from the registry's own version count, so it is unclear which is authoritative.
- It says nothing about what changed, where a descriptive name does.

The CloudEvents Primer's advice matches: a compatible change shows as a new `dataschema` URI; an incompatible one shows as a new `type`, with both emitted for a period.

**Negotiation** (Young) is the alternative when a published event has many consumers: each consumer states the version it can read, and the producer side converts. It saves emitting every shape on every write, but it is a lot of machinery; use it only at that scale.

## 4. Stored events are different

An event-sourced Aggregate's own events are its record and must stay readable forever. There is no retiring them, so the published-event protocol doesn't apply:

- **Additive:** weak schema, as above.
- **Convertible shape change:** **upcasting**, a small chain of converters (v1 → v2 → v3) run when events are read. The stored bytes never change. Keep sample events of every historical shape as test fixtures.
- **Wrong stream structure** (split, merge, too many old versions): **copy-and-replace**. Write a transformed new stream, switch readers, and leave the old one untouched. Record the decision in an ADR.
- **Never edit stored events in place.** That destroys the audit trail and can't be undone. A wrongly recorded fact is fixed with a **correcting event**, as an accountant posts a correcting entry.

Upcasting is never used for published events: it would hide a contract change behind a translation consumers can't see. A new type is never used for stored internal events: a type you must replay forever can't be retired.

Internal events can change more freely than published ones (one team owns every reader). Published events should be coarser than the internal stream in the first place (`aggregate-design`).
