# Structural Data Minimisation — The ExtractedEntitySummary Domain Primitive

Reference for `privacy-design`. The body states, as decision-shaping guidance, that data
minimisation in this repo is *structural* — the safe representation is the **only**
representable one, so "log the raw PII" has no data path rather than merely a policy against
it. This file is the concrete construction: a Go **Domain Primitive** that makes storing or
logging raw extracted PII a *compile-time* impossibility, not a code-review catch. It ties
the pattern to `secure-by-design`'s Domain Primitive concept and `access-control-model`, and
records exactly which STRIDE cell the pattern discharges for `threat-modeling`.

---

## The problem this discharges

The platform extracts PII entities from scanned files (person names, emails, national-ID
numbers). The privacy constraint is absolute: **raw extracted file contents are never
persisted — only entity types and counts.** Stated as a *rule*, this is fragile. A debug
log, a cache, an error message, or a struct field can capture raw text:

```go
// The failure mode the rule cannot prevent by itself:
log.Printf("extracted entity: %q (%s) in %s", match.Text, match.Type, asset.Path)
//                              ^^^^^^^^^^ "John Smith", "078-05-1120" — a privacy defect
```

Every mitigation that depends on a developer *remembering* not to write `match.Text` is a
discipline control. The stronger control removes `match.Text` from the type system entirely
downstream of extraction, so there is nothing to log.

---

## The Domain Primitive (per *Secure by Design*)

A **Domain Primitive** is a small, immutable, self-validating value type that makes an
entire class of illegal state *unrepresentable*. Instead of validating a dangerous
representation after the fact, it restricts what can exist to a safe representation at
construction. `secure-by-design`'s "Applies To" row for this skill names the exact shape:
an `ExtractedEntitySummary` type constructible **only** from `(EntityType, Count)`, with no
constructor path that accepts raw text at all.

```go
package pii

import "fmt"

// EntityType is a closed enum of detectable PII categories. It carries NO
// instance data — a category, never a value.
type EntityType string

const (
    EntityPersonName EntityType = "person_name"
    EntityEmail      EntityType = "email"
    EntityNationalID EntityType = "national_id"
    EntityPhone      EntityType = "phone"
)

func (t EntityType) valid() bool {
    switch t {
    case EntityPersonName, EntityEmail, EntityNationalID, EntityPhone:
        return true
    default:
        return false
    }
}

// ExtractedEntitySummary is the ONLY representation of an extraction result that
// crosses the extraction boundary. Its fields are unexported, so no other package
// can build one with a struct literal, and there is NO field that can hold raw
// matched text. The safe representation is the only representable one.
type ExtractedEntitySummary struct {
    entityType EntityType
    count      int
}

// NewExtractedEntitySummary is the sole constructor. It accepts a category and a
// count — and nothing else. There is deliberately no variant that takes the raw
// span, the offsets, or the source text. "Log the raw PII" has no argument to pass.
func NewExtractedEntitySummary(t EntityType, count int) (ExtractedEntitySummary, error) {
    if !t.valid() {
        return ExtractedEntitySummary{}, fmt.Errorf("unknown entity type %q", t)
    }
    if count < 1 {
        return ExtractedEntitySummary{}, fmt.Errorf("count must be >= 1, got %d", count)
    }
    return ExtractedEntitySummary{entityType: t, count: count}, nil
}

func (s ExtractedEntitySummary) Type() EntityType { return s.entityType }
func (s ExtractedEntitySummary) Count() int       { return s.count }

// String and any log rendering can only ever emit the safe fields. Even a
// careless `%+v` on this value cannot leak raw PII, because the value never held it.
func (s ExtractedEntitySummary) String() string {
    return fmt.Sprintf("%d×%s", s.count, s.entityType)
}
```

### Why the guarantee holds

1. **Unexported fields + sole constructor.** No package outside `pii` can build an
   `ExtractedEntitySummary` with a struct literal (`pii.ExtractedEntitySummary{...}` won't
   compile from outside). The only way in is `NewExtractedEntitySummary`.
2. **The constructor's parameter list contains no raw text.** There is no overload, no
   optional field, no `WithRawText`. The dangerous value is not in the type's vocabulary.
3. **The extraction function returns this type, not a richer one.** The matcher may work
   with raw spans in-process (it has to, to count them), but its *return signature* is
   `[]ExtractedEntitySummary` — the raw span is a local that goes out of scope and is never
   returned, stored, or logged. The boundary is the function signature.

```go
// The extractor's signature IS the privacy control. Raw spans are locals only.
func Extract(ctx context.Context, content []byte) ([]ExtractedEntitySummary, error)
```

Contrast with the discipline approach, where `Extract` returns `[]Match{Text, Type,
Offset}` and every caller must remember never to persist or log `.Text`. Here the
temptation does not exist because the data does not cross the boundary.

### Relationship to `access-control-model` and `secrets-management`

This is the same totality pattern those skills use, applied to a different value:
- `access-control-model` proposes `TenantID` / `Permission` Domain Primitives so a
  malformed tenant ID cannot be constructed.
- `secrets-management` uses a `Secret` redaction type whose `String()`/`LogValue()` never
  render plaintext — but the manifesto's stronger form is to construct that `Secret` at the
  point of reading, so a bare secret `string` never exists in application code.
- `ExtractedEntitySummary` applies the identical move to PII: construct the safe type at the
  point of extraction so the raw representation never exists downstream.

One repo-wide rule emerges: **construct the safe Domain Primitive at the boundary where the
dangerous value is first produced, and give it no path back to the dangerous form.**

---

## The STRIDE cell this discharges (for `threat-modeling`)

In a STRIDE-per-element pass over the DataAsset ingestion → classification flow, the
classification *process* element and the extracted-summary *data store* element each carry an
**Information disclosure** threat: *raw PII captured in a log, cache, or error message, then
read by an unauthorised party.* STRIDE's Information-disclosure category is the violation of
**confidentiality**, and its mitigation lane is a confidentiality control.

| STRIDE element | Threat (Information disclosure) | Mitigation of record |
|---|---|---|
| Classification process | Raw extracted span written to a debug log or error | `ExtractedEntitySummary` — raw text has no data path out of `Extract` |
| Extracted-summary data store | Store holds raw PII text | Schema holds `(EntityType, Count)` only; no raw-text column exists |

Recording the never-persist constraint *as the mitigation of a named Information-disclosure
cell* — rather than as a standalone rule — gives the privacy control a home inside the same
grid the security team already reviews, and makes it auditable: the cell is either mitigated
(the type/schema enforces it) or it is an open finding. This is how a privacy control becomes
visible to a security threat model instead of living in a separate document.

---

## Verification (for `compliance-verification`)

The guarantee is testable without running the system:

- **Compile-time:** a test file in a package *other than* `pii` that attempts
  `pii.ExtractedEntitySummary{entityType: "x", count: 1}` must fail to compile — proving the
  struct-literal path is closed. (Assert via `go vet` / a build tag that is expected to fail.)
- **Signature contract:** a reflection or AST test asserting `Extract`'s return type contains
  no field named `Text`/`Raw`/`Span` — the boundary holds.
- **Schema:** a migration test asserting the extracted-summary table has no `text`/`content`
  column — the store cannot hold raw PII even if code tried.

Each of these is a privacy behaviour a test *exercises*, satisfying the accountability FIPP's
demand that the control be demonstrable, not asserted.
