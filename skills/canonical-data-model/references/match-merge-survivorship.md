# Match/Merge and Survivorship — Producing the Golden Record

Reference for the SKILL body's "Matching" and "Survivorship" sections. Covers record linkage (deterministic vs probabilistic, the blocking pre-filter, similarity functions, the Fellegi-Sunter framework and its three match bands), the merge/survivorship rules that pick the surviving value per attribute, the `match_decisions` schema, per-(source, attribute) trust scores, a worked golden-record assembly, and match precision/recall as an MDM-specific quality axis.

Grounded in Loshin (Ch. 5–6). Loshin's Fellegi-Sunter framework is the classical, still-valid statistical baseline for record linkage — treat learned/ML matching as a legitimate alternative for the scoring step only.

---

## 1. Match then Merge — Two Distinct Steps

The golden record is produced by two steps that must stay separate:

1. **Match (identity resolution)** — decide that two source records describe the *same* real-world entity. Produces a *match decision*, recorded and reversible.
2. **Merge (survivorship)** — for each attribute of the matched cluster, pick which contributing source's value survives.

Separation is what makes a bad merge reversible: retract the match decision (never re-run survivorship destructively), then replay assembly without it. A design that merges attributes directly into a mutable golden row, discarding which source contributed what, cannot be un-merged without manual data surgery.

---

## 2. Blocking — the pre-filter that makes matching tractable

Comparing every record pair is O(n²) and infeasible at estate scale — every document across every customer's Google Drive / S3 / PDF estate. **Blocking** partitions candidate records into small comparison groups by a cheap, high-recall key, so full similarity scoring runs only *within* a block, never across the whole tenant's record set.

| Entity | Example blocking key | Rationale |
|---|---|---|
| Person | normalised surname + first char of email domain | high recall, cheap; typos in given name don't split the block |
| Person | Soundex/NYSIIS of surname | tolerates phonetic spelling variants |
| DataSource | file size bucket + first 8 bytes hash | groups the same file seen via two connectors |
| Organisation | normalised legal-name stem (drop "Inc/Ltd/GmbH") | tolerates suffix variation |

A good blocking key is **high-recall (never separates a true pair) even at the cost of precision** (it may group non-matches — the scoring step sorts those out). Blocking is always tenant-scoped: blocks never span tenants.

---

## 3. Similarity Functions — chosen per attribute type

Probabilistic matching scores each attribute pair with a similarity function suited to that attribute's failure modes:

| Attribute type | Similarity function | Handles |
|---|---|---|
| Name (given/surname) | edit distance (Levenshtein / Jaro-Winkler) | typos, transpositions |
| Name (phonetic variants) | Soundex / NYSIIS encoding then exact compare | "Catherine"/"Kathryn" |
| Email | exact after normalisation (lowercase, trim) | case/whitespace noise |
| Address / multi-token | token-set / Jaccard similarity | word reordering, abbreviations |
| Date | exact or windowed | format normalisation |

Each function returns a per-attribute agreement in [0,1] that feeds the composite score below.

---

## 4. Fellegi-Sunter Probabilistic Record Linkage and the Three Match Bands

The mathematics behind "probabilistic fuzzy match" is the **Fellegi-Sunter** framework. Each matching attribute contributes an *agreement weight* derived from two probabilities:

- **m-probability** — the chance the attribute agrees *given the pair is a true match* (high for a reliable attribute).
- **u-probability** — the chance the attribute agrees *by chance given a non-match* (low for a discriminating attribute; e.g. two random people rarely share an email, high for a common surname).

The weight for an agreeing attribute is `log2(m/u)`; for a disagreeing attribute `log2((1-m)/(1-u))` (negative). Summing weights across attributes yields a composite match score. That score is split into **three explicit bands**, not one pass/fail threshold:

| Band | Score range | Action |
|---|---|---|
| **Auto-match** | above the upper threshold | apply the match automatically |
| **Clerical review** | between the two thresholds | route to a Data Steward review queue for a human match decision |
| **Auto-non-match** | below the lower threshold | do not merge |

The middle **clerical-review** band is the key departure from a single cutoff: it separates "confident match" from "worth a human glance." Set the two thresholds conservatively so the clerical-review queue stays small — an unbounded clerical queue is a silent, unstaffed backlog (the same "quarantine as a black hole" failure `data-quality-rules` warns about for a different queue). The clerical-review queue is distinct from `data-classification`'s sensitivity-review queue and `data-quality-rules`' quarantine queue — reviewing *are these the same Person?* is a different judgment from *how sensitive is this?*

Deterministic matching (exact match on a verified strong key — verified email, government ID) skips scoring entirely and lands directly in auto-match. Use it whenever a shared strong identifier exists; fall back to probabilistic scoring only when none does.

---

## 5. The match_decisions Table

Every match decision is recorded for lineage (see `data-lineage-design`) so a Golden Record always traces to its contributing source records, and so a merge is reversible. Un-merge is a *retraction* (set `retracted_at`), never a `DELETE` — retraction is itself auditable.

```sql
CREATE TABLE match_decisions (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,                      -- matching never crosses tenants
    canonical_id      UUID NOT NULL,                      -- the canonical entity this record matched into
    entity_type       TEXT NOT NULL,                      -- 'person' | 'organisation' | 'datasource'
    source_system     TEXT NOT NULL,
    source_record_id  TEXT NOT NULL,
    method            TEXT NOT NULL CHECK (method IN ('deterministic','probabilistic','manual')),
    band              TEXT CHECK (band IN ('auto-match','clerical-review','auto-non-match')),
    score             NUMERIC(6,3),                       -- composite Fellegi-Sunter weight (null for deterministic)
    decided_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_by        TEXT,                               -- steward id when method='manual'
    retracted_at      TIMESTAMPTZ,                        -- un-merge = set this; never DELETE
    retracted_reason  TEXT,
    UNIQUE (tenant_id, source_system, source_record_id, canonical_id)
);
```

The Golden Record is a deterministic **Read Model** over the source records plus the *active* (non-retracted) match decisions. It is never hand-edited: a correction is a change to a source record, a retraction of a match decision, or a new survivorship rule — followed by replay of assembly.

---

## 6. Survivorship Rules — picking the surviving value per attribute

| Rule type | Chooses | Example |
|---|---|---|
| **Source priority** | value from the highest-priority source that has one | IdP email beats extracted email |
| **Recency** | most recently updated value | latest crawl of `display_name` |
| **Completeness** | a non-null value over a null | any name beats no name |
| **Confidence** | value with the highest extraction confidence | the 0.92 email beats the 0.51 email |
| **Aggregation / union** | combine rather than pick one | union of all `source_identifiers` |
| **Highest-sensitivity-wins** | the most sensitive classification | see the sensitivity exception below |

Two invariants (from the SKILL body, detailed here):

- **Deterministic termination.** Every rule *chain* must end in a deterministic tie-breaker (e.g. lowest source record id, or lexicographically-first source system). Otherwise two runs over the same sources can disagree and the golden record cannot serve as compliance evidence. Example chain for `display_name`: `completeness → recency → lowest source_record_id`.
- **Reversibility.** Because `match_decisions` are recorded, an incorrect merge is reversible by retraction + replay.

### The sensitivity-survivorship exception

`classification` never survives by recency or source priority. It always uses **highest-sensitivity-wins** (the max rule from `data-classification`): a newer or higher-priority but *lower-sensitivity* source must never downgrade a Golden Record's protection. If any contributing record is `Restricted`, the golden record is `Restricted`.

### Per-(source, attribute) trust scores

Rather than hardcoding survivorship prose per attribute, express source authority as a tunable **trust score per (source, attribute) pair** so a Business Data Steward can adjust "how much do we trust the identity provider's `display_name` vs an extracted document's" without an engineer rewriting the canonical YAML:

```sql
CREATE TABLE source_trust (
    tenant_id    UUID NOT NULL,
    entity_type  TEXT NOT NULL,
    attribute    TEXT NOT NULL,
    source_system TEXT NOT NULL,
    trust        NUMERIC(4,3) NOT NULL CHECK (trust BETWEEN 0 AND 1),
    PRIMARY KEY (tenant_id, entity_type, attribute, source_system)
);
```

A source-priority rule then becomes "highest `trust` wins, ties broken deterministically" — a data-driven survivorship rule the steward tunes.

---

## 7. Worked Golden-Record Assembly

Three source records for one real person, already matched into `canonical_id = P1` (all `tenant_id = T1`):

| Source | display_name | primary_email | confidence | updated_at | classification |
|---|---|---|---|---|---|
| identity-provider | (null) | jane.doe@acme.com | — | 2026-07-01 | Internal |
| entity-extraction (PDF) | Jane Doe | j.doe@acme.com | 0.62 | 2026-07-20 | Restricted |
| data-source-crawl | J. Doe | (null) | — | 2026-07-10 | Confidential |

Applying the rules:

```
primary_email  ← source-priority: identity-provider > extraction > crawl
                 → "jane.doe@acme.com"  (IdP wins; extraction's 0.62 email is beaten, kept only as survivorship input)
display_name   ← completeness → recency → lowest source_record_id
                 → "Jane Doe"  (IdP is null; extraction 2026-07-20 beats crawl 2026-07-10)
classification ← highest-sensitivity-wins
                 → "Restricted"  (extraction's Restricted beats Internal/Confidential; recency is IRRELEVANT)
source_identifiers ← union
                 → [idp:..., extraction:..., crawl:...]
```

Resulting Golden Record `P1`: `{primary_email: jane.doe@acme.com, display_name: "Jane Doe", classification: Restricted, source_identifiers: [3 keys]}`. Re-running assembly over the same three source records + active match decisions yields byte-identical output — reproducible, and defensible as evidence.

If the extraction record was later found to be a *different* Jane Doe (a false merge), retract its `match_decisions` row (`retracted_at = now()`) and replay: the golden record loses the Restricted classification and reverts to Confidential — no manual surgery.

---

## 8. Match Quality — an MDM-specific dimension

The six generic data-quality dimensions (`data-quality-rules`) do not name the MDM-native failure mode: a **false merge** (two different people wrongly consolidated into one golden Person) or a **false split** (one person left as two records). Measure identity-resolution quality directly:

- **Match precision** — of all pairs the process auto-matched, the fraction that were truly the same entity. Low precision ⇒ false merges ⇒ tighten the auto-match upper threshold.
- **Match recall** — of all true matches present in the data, the fraction the process found. Low recall ⇒ false splits ⇒ loosen thresholds or improve blocking recall.
- **False-merge rate** — the headline compliance risk: two people's data conflated into one golden record. This is a golden-record correctness failure, distinct from extraction-confidence or classification failures.

Track these as their own metric (extending `data-quality-rules` or the metrics plan), not folded into the generic Uniqueness dimension, which only checks within-record deduplication.

---

## Checklist

- [ ] Blocking key defined per entity; high-recall; tenant-scoped.
- [ ] Similarity function chosen per attribute type.
- [ ] Probabilistic matching uses three bands (auto-match / clerical-review / auto-non-match), not one threshold; thresholds set so the clerical-review queue stays small.
- [ ] Deterministic matching used wherever a verified strong key exists.
- [ ] `match_decisions` records every decision; un-merge is retraction, never DELETE.
- [ ] Each attribute has a survivorship rule ending in a deterministic tie-breaker.
- [ ] `classification` uses highest-sensitivity-wins, never recency.
- [ ] Golden Record is a replayable Read Model, never hand-edited.
- [ ] Match precision/recall / false-merge rate tracked as an MDM-specific quality axis.
