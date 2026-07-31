# CDM Entity Format, Source-to-Canonical Mapping, and Ownership

Reference for the SKILL body's "Where the Canonical Model Lives" and "Entity ownership and authority" sections. Covers the canonical entity format, the field-level source-to-canonical mapping the Anti-Corruption Layer implements, how to assign ownership/authority per attribute, the four MDM architectural styles (Loshin), and the relationship to `context-map-patterns` (ACL / Published Language).

---

## 1. The Canonical Entity Format

For each master entity, define the canonical shape: the union of attributes needed by *consumers* at the boundary, named in neutral, source-independent terms. Canonical attribute names use integration vocabulary documented in the glossary — never a source-local term.

```yaml
# Canonical entity: Person
canonical_entity: Person
identifier: person_id                 # canonical UUID assigned at first match
mdm_style: consolidation              # see section 4 — recorded, not inherited by default
attributes:
  - name: primary_email
    type: string
    system_of_record: identity-provider   # authoritative when sources disagree
    survivorship: source-priority
  - name: display_name
    type: string
    system_of_record: derived             # no single authoritative source
    survivorship: completeness-then-recency
  - name: source_identifiers            # all known keys, for matching + lineage
    type: array<SourceIdentifier>
    survivorship: union                   # never discard a contributing key
  - name: classification                # highest sensitivity of any contributing record
    type: SensitivityLevel
    survivorship: highest-sensitivity-wins
provenance:
  contributing_sources: [identity-provider, entity-extraction, data-source-crawl]
  lineage_required: true
```

Each attribute carries three things the golden record needs: its **type**, its **system of record** (authority), and its **survivorship rule** (how the winner is chosen — detailed in `match-merge-survivorship.md`). An attribute with no named authority and no survivorship rule is a defect: the "truth" defaults to whichever write happened last.

The `SourceIdentifier` value object keeps every source key so lineage and re-matching survive a merge:

```yaml
SourceIdentifier:
  source_system: string     # e.g. "google-drive", "s3", "identity-provider"
  source_record_id: string  # the key in that system
  first_seen: timestamp
```

---

## 2. System of Record vs System of Entry (Loshin, Ch. 4)

Loshin draws a precise distinction this repo's storage-tier use of "system of record" does *not* make. Keep both meanings, but never conflate them:

| Term | Meaning | Determined by |
|---|---|---|
| **System of Entry** | Any system where an attribute can be created or edited. There may be several. | Where the data physically originates or is editable |
| **System of Record** (MDM sense) | The one source whose value is authoritative for a given attribute when systems disagree. | The **survivorship rule** for that attribute — not by which store holds the golden record |

A worked example for the estate-mapping product's `Person.primary_email`:

- Systems of entry: the identity provider (a user edits their profile), the entity-extraction pipeline (an email is parsed from a PDF), the data-source crawl (an `owner.name` field).
- System of record: the identity provider — because the survivorship rule for `primary_email` is `source-priority: identity-provider`. If the identity provider has no value for a given Person, authority falls through to the next-priority source, so system of record is *per attribute, per record state*, not a fixed global label.

> Do not confuse this with `data-model-design`'s use of "system of record" for storage-tier authority (the relational store is the system of record for an Aggregate; a non-PostgreSQL store is a rebuildable projection). That is a *storage-architecture* claim; this is a *cross-source authority* claim. Both are valid and both are needed — they are homonyms owned by the same agent.

**Assign ownership per attribute, not per entity.** A source may be highly trusted for `display_name` yet low-trust for `primary_email`. A single "the identity provider owns Person" statement is too coarse and produces wrong merges.

---

## 3. Source-to-Canonical Mapping

For every source feeding the canonical model, document the field-level mapping. This mapping is the *specification the Anti-Corruption Layer implements* — the ACL code is a faithful translation of this table, nothing more.

| Source | Source field | Canonical field | Transformation |
|---|---|---|---|
| Entity extraction | `entity.value` (type=EMAIL) | `Person.primary_email` | lowercase, trim, validate RFC 5322 |
| Identity provider | `user.mail` | `Person.primary_email` | direct (authoritative) |
| Data source crawl | `owner.name` | `Person.display_name` | direct |
| Entity extraction | `entity.confidence` | (survivorship input) | weight; not stored as a canonical attribute |
| Google Drive | `file.id` | `DataSource.source_identifiers[]` | wrap as SourceIdentifier(source=google-drive) |
| S3 | `object.key` | `DataSource.source_identifiers[]` | wrap as SourceIdentifier(source=s3) |

Rules for a complete mapping:

- **Every required canonical field is either mapped or explicitly documented as un-populatable** by a given source. A required canonical field with no mapping and no "source cannot populate it" note is a gap — a defect.
- **Confidence and scores are survivorship inputs, not canonical attributes.** A 0.51-confidence extracted email must remain beatable by a better source later; promoting it to a stored fact destroys that.
- **The same real file seen via two connectors is one entity.** A file discovered through both Google Drive and S3 produces two source records that match into one `DataSource` golden record — the mapping wraps each connector's native key into a `SourceIdentifier`, and identity resolution (see `match-merge-survivorship.md`) links them.

Go sketch of an ACL translating a foreign extraction record into the canonical shape (the ACL lives in the consuming context, per `integration-design`):

```go
// Package acl translates the entity-extraction context's foreign model into
// the canonical Person shape. It depends on the canonical model, never the
// reverse — the consuming context's domain code never imports the foreign type.
func toCanonicalPerson(e extraction.Entity) (canonical.PersonContribution, error) {
    if e.Type != extraction.EMAIL {
        return canonical.PersonContribution{}, ErrNotAPerson
    }
    email, err := normalizeEmail(e.Value) // lowercase, trim, RFC 5322 validate
    if err != nil {
        return canonical.PersonContribution{}, err
    }
    return canonical.PersonContribution{
        Attribute:  "primary_email",
        Value:      email,
        Source:     "entity-extraction",
        Confidence: e.Confidence, // survivorship input, not a stored fact
        SourceID:   canonical.SourceIdentifier{SourceSystem: "entity-extraction", SourceRecordID: e.ID},
    }, nil
}
```

---

## 4. MDM Architectural Styles (Loshin, Ch. 7)

The golden record is *one* of four MDM implementation styles. This repo's `Person` design is a **Consolidation** implementation done well — but the style should be a recorded choice per master entity, not an unexamined inheritance. As the master-entity roster grows (`Organisation`, potentially a `Device` or `LegalHold`), later additions deserve the same deliberate choice.

| Style | Golden record stored? | Sources writable? | System of entry count | Fits when |
|---|---|---|---|---|
| **Registry** | No — a thin index maps source keys to a shared identifier; queries fan out to sources at read time | Yes | Many | Read-heavy identity resolution ("is this the same Person?") with no need to *edit* the entity centrally |
| **Consolidation** | Yes — physically merged, assembled and stored, read-mostly, refreshed on batch/event cadence | Yes (sources only) | Many | Reporting / audit-evidence; a stable rebuildable golden record. **This repo's `Person`.** |
| **Coexistence** | Yes — stored golden record *and* writable sources, bidirectional sync | Yes (both) | Many | The golden record must be editable but sources also remain authoritative |
| **Transaction Hub / Centralized** | Yes — the master store is the single system of entry | No (sources become thin clients) | One | All creates/updates flow through the hub; strongest consistency |

**When to reconsider Consolidation for a new entity:** if the product only needs to *resolve identity* across mentions of an `Organisation` (never edit its data), a lighter **Registry** style — no stored golden record, just an identity map — may fit better and is cheaper to operate. Record the choice and its rationale (ADR-worthy) rather than defaulting to Consolidation because `Person` did.

The four styles are also why "which store holds the golden record" is not the same as "system of record": in Registry there is no stored golden record at all, yet each attribute still has a system of record via its survivorship rule.

---

## 5. Relationship to context-map-patterns (ACL / Published Language)

The canonical model is the connective tissue between two `context-map-patterns` relationship patterns:

- **Anti-Corruption Layer (ACL).** A consuming context protects its own model from a foreign one by translating through the ACL. The canonical model is the ACL's *translation target* — the ACL maps the foreign shape to canonical, and canonical to the local model. Without a canonical model, every pair of contexts needs a bespoke translator (O(n²) translators); with one, each context translates only to/from canonical (O(n)).
- **Published Language.** When the canonical model is *published* as the agreed shared shape that events and APIs carry across a boundary, it becomes a Published Language. The event payload that crosses a context boundary carrying master data uses this published canonical representation, and its wire schema is governed by `event-schema-design`.

The discipline that ties them together: the canonical model is a **boundary artifact**. A context's internal code never imports it; only the ACL and the boundary adapters do. This is DMBOK's *semantic* interoperability layered on top of *technical* interoperability — agreeing bytes (event-schema-design) without agreeing meaning (this model) yields "successfully transmitted nonsense."

---

## Checklist

- [ ] Each master entity has a canonical YAML with typed attributes, a system of record per attribute, and a survivorship rule per attribute.
- [ ] Ownership is assigned per attribute, not per entity.
- [ ] "System of record" (MDM authority) is disambiguated from `data-model-design`'s storage-tier usage wherever both could be read.
- [ ] Every source has a complete field-level mapping; un-populatable required fields are documented, not silent.
- [ ] Confidence/scores are survivorship inputs, never stored canonical attributes.
- [ ] Each entity's MDM architectural style (Registry / Consolidation / Coexistence / Transaction Hub) is a recorded choice with rationale.
- [ ] The canonical model is named as the ACL's translation target in `integration-design`, and as a Published Language where events carry it.
