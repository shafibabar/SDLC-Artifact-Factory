# MDM Governance — Stewardship, Golden-Record Lifecycle, Multi-Domain

Reference for the SKILL body's "Multi-Domain and Governance" section. Covers the stewardship operating model (Data Domain Owner, Business vs Technical Data Steward, Data Governance Council), the golden-record lifecycle state model including un-merge/split, and multi-domain considerations (shared-hub-vs-per-domain infrastructure, cross-domain relationships, the Tenant/Organisation question, MDM program maturity).

Grounded in Cervo & Allen (*Multi-Domain Master Data Management*) and Loshin. **Scale everything here down to this repo's solo-operator context**: the value is in *naming* which domain a rule belongs to and who arbitrates conflicts, not in standing up literal councils and named seats. Heavyweight governance ceremony for three entities and one operator violates `CLAUDE.md`'s frugality constraint.

---

## 1. Why single "Data Steward" is too coarse

`data-classification` and this skill both assume one undifferentiated "Data Steward" with blanket authority. Cervo & Allen split that role, because different failures need different fixes and different domains may need different owners:

| Role | Owns | A failure here is |
|---|---|---|
| **Data Domain Owner** | One master-data domain's rules, matching behaviour, and quality (a `Person` owner, an `Organisation` owner, a `DataSource` owner) | A wrong or missing rule for that whole domain |
| **Business Data Steward** | Deciding *what a rule should be* — e.g. which source wins for `Person.display_name`, where to set match thresholds | A wrong rule (a business judgment error) |
| **Technical Data Steward / Data Custodian** | Correctly *implementing and enforcing* the rule in code and pipelines | A bug or misconfiguration (an implementation error) |
| **Data Governance Council** | Arbitrating when two Data Domain Owners' rules conflict; accountable for the whole multi-domain program | An unresolved cross-domain conflict |

A cross-domain conflict example the single-steward model cannot express: `Person`'s survivorship escalates a record to `Restricted` because of contained PII, while the `Organisation` domain's rules would classify the containing entity differently. The Council (at solo scale, Shafi) is the documented arbitration path.

**Solo-operator scaling.** Represent this as a *decision-rights table Shafi approves*, not a literal committee:

| Domain | Data Domain Owner | Business steward decisions | Technical steward decisions | Conflict arbiter |
|---|---|---|---|---|
| Person | Shafi (delegated) | source priority, thresholds | pipeline implementation | Shafi |
| Organisation | Shafi (delegated) | matching key, hierarchy rules | pipeline implementation | Shafi |
| DataSource | Shafi (delegated) | dedup rules | connector implementation | Shafi |

The row structure is the deliverable; who fills each cell can all be Shafi today.

### Three distinct steward queues

Three human-in-the-loop queues already exist implicitly and should be named as separate work, because each is a different judgment:

1. **Match/clerical-review queue** (this skill) — "are these the same entity?"
2. **Sensitivity-review queue** (`data-classification`) — "how sensitive is this?"
3. **Quality quarantine queue** (`data-quality-rules`) — "is this extraction trustworthy?"

A real steward UI must distinguish the three; conflating them hides which kind of defect a stewardship action is clearing.

---

## 2. Golden-Record Lifecycle State Model

A master record is not assembled once — it moves through states. Give the eventual `Person`/`Organisation`/`DataSource` Aggregate a documented state machine instead of one implied only by the `match_decisions` retraction mechanic.

```
                 first source record matched
                          │
                          ▼
   ┌──────────────►   ACTIVE   ◄───────────────┐
   │                    │   │                   │
   │        merged into │   │ split / un-merge  │ reinstated
   │        another     │   │ (retract match)   │ (retract the merge)
   │                    ▼   ▼                   │
   │              MERGED-INTO ─────────────► ACTIVE (new canonical_id)
   │                    │
   │      retired (source(s) removed / tombstoned)
   │                    ▼
   └──────────────  TOMBSTONED ───► (reinstated on un-tombstone)
```

| State | Meaning | Entered by |
|---|---|---|
| **Active** | A live golden record consumers may reference | First match; or reinstatement |
| **Merged-into** | This record was consolidated into another `canonical_id` | A match linking two previously-separate clusters |
| **Tombstoned / retired** | All contributing sources removed, or the entity retired | Source deletion; retention disposal |
| **Reinstated** | An un-merge or un-tombstone restored it | Retraction of the merge/tombstone decision |

### Un-merge / split

Because the golden record is a replayable Read Model over *active* match decisions, un-merge is not data surgery:

1. Identify the wrongly-included source record(s).
2. Set `retracted_at` (and `retracted_reason`) on their `match_decisions` rows — never `DELETE`.
3. Replay assembly. The record they wrongly influenced reverts; the retracted source records re-resolve on the next matching pass (possibly forming a new `canonical_id`).

A **split** is the same mechanism when a single golden record turns out to be two real entities: retract the decisions that bound the wrong cluster together and let re-matching form two clusters. Every retraction is auditable — the history of what was merged and un-merged survives.

---

## 3. Multi-Domain MDM (Cervo & Allen)

Three master entities (`Person`, `DataSource`, `Organisation`) sharing one `match_decisions` shape and one survivorship section is, in substance, a **multi-domain MDM** design. The first architectural decision a multi-domain program must *record* (this repo made it implicitly and never named it):

### Shared hub vs per-domain infrastructure

> Is `Person`'s matching mechanism, thresholds, and steward queue **shared hub infrastructure** that `Organisation` and `DataSource` also use — or does each domain define its own from scratch?

This repo's file layout (one skill, one table shape) implies a shared hub. Make it deliberate, and **before adding a fourth master entity, decide explicitly** whether it reuses the shared mechanism or needs its own thresholds/queue. The decision stops being free once a fourth domain exists — this is a distinct question from Loshin's per-entity *style* choice (Registry/Consolidation/…): style asks "how is *this* entity's golden record built"; hub asks "do these entities *share* the machinery."

### The Tenant vs Organisation question

`multi-tenancy-design` registers tenants in a "tenant registry service"; this skill names `Organisation` as a master entity with its own golden record. These are owned by different agents and never cross-reference. Resolve, in writing, before either skill grows:

- **Same thing** ⇒ the tenant registry *is* the `Organisation` domain's system of entry; cross-reference the two skills.
- **Different things** ⇒ `Tenant` is an undocumented *fourth* master domain alongside `Person`, `DataSource`, `Organisation`, and needs its own golden-record treatment.

Leaving it implicit means two skills silently disagree on what the master-entity roster is.

### Cross-domain relationships vs the Context Map

Relationships *between master entities* (`Organisation` owns `DataSource`, `DataSource` contains `DataAsset`, `DataAsset` references `Person`, `Person` is a member of `Organisation`) are a **different artifact** from the Context Map. The Context Map (`context-map-patterns`) shows how *services* integrate (ACL, OHS, Customer/Supplier). A cross-domain relationship graph shows how *real-world master entities* relate, independent of which service owns which. Keep them as two diagrams — one diagram trying to be both misrepresents one of them. The Apache AGE edge types (`CONTAINS`, `REFERENCES`, `OWNED_BY`, `DERIVED_FROM` in `data-model-design`) already carry these relationships; the gap is naming the master-entity graph as its own concern.

### "Domain" is an overloaded word

Cervo & Allen's "Data Domain" (a master-data category — the `Person` domain, the `Organisation` domain) is a *different axis* from DDD's **Subdomain** (Core/Supporting/Generic, per `subdomain-distillation`). Same word, unrelated classifications. Any artifact introducing "Data Domain Owner" must sit a one-line disambiguation next to the DDD sense so readers don't conflate them.

---

## 4. Party Model and Hierarchy Management (Loshin)

Two of this repo's three master entities — `Person` and `Organisation` — are both *parties*. Loshin's **Party Model** represents them as two kinds of a shared `Party` supertype that can hold roles, relationships, and hierarchy memberships once, rather than letting `Person` and `Organisation` evolve incompatible relationship/role mechanics independently.

```
        Party  (identifier, party_type, golden-record machinery shared)
        ├── Person        (given_name, surname, primary_email, ...)
        └── Organisation  (legal_name, registration_id, ...)
```

Modelling `Person` and `Organisation` under a shared `Party` supertype means the `match_decisions` mechanism, survivorship engine, and steward queues apply to both without duplication — which is exactly the shared-hub decision of section 3, made concrete.

**Hierarchy management** is the discipline of maintaining one or more *simultaneous* hierarchical views over the same entities. The same set of organisations can nest differently depending on the question:

| Hierarchy view | Edge semantics | Answers |
|---|---|---|
| Legal / ownership | containment (`PART_OF`) | which legal entity owns which subsidiary — regulatory / ownership |
| Operational / reporting | reporting line (`ADMINISTERS`) | which team operationally manages which — who runs what |

Model these as **two named edge types** in the Apache AGE graph, not one generic `PART_OF`. Collapsing them loses the ability to answer either question once an org restructures operationally without a change in legal ownership (or vice versa). This product's compliance premise — data estates belong to legally structured, multi-subsidiary customers — makes "which legal entity owns this data source, and does that differ from who administers it" a real recurring question, not hypothetical.

Note the drift this closes: `data-model-design`'s Apache AGE vertex list (`DataAsset`, `Entity`, `DataSource`, `Person`) has **no `Organisation` vertex** today, despite this skill naming `Organisation` as a master entity — the graph model and the canonical model have silently disagreed on what master entities exist. Adding an `Organisation` vertex plus at least one hierarchy edge type closes it.

Hierarchy management is roadmap-sequenced (section 6): build it when a genuinely hierarchical, multi-subsidiary customer first appears, not before.

---

## 5. MDM Program Maturity (self-assessment)

Cervo & Allen's staged maturity model scores an MDM program across dimensions — executive sponsorship, governance formality, data-quality operating rigor, technology/architecture fit, organizational adoption — on a staged scale (roughly ad hoc/reactive → managed → defined → optimized). This repo's whole value proposition is assessing *someone else's* data-governance maturity, yet it has never scored its own three-entity MDM design.

Before offering maturity assessment as a customer-facing capability, run a small honest self-audit against this model — the product's credibility in assessing customer maturity is undermined if its own program has never been scored. Treat the scoring *technique* as useful; treat the model's assumption of a dedicated program office and steering committee as inapplicable at this repo's scale.

---

## 6. Sequencing (frugality)

Hierarchy management, the four MDM styles, per-domain owners, and cross-domain relationship modeling are most valuable once a genuine fourth or fifth master domain exists (an `Asset`, a `Device`, a distinct `Tenant`) or a real cross-domain conflict appears. With exactly three entities, one operator, and no confirmed conflicts, treat these as **roadmap, not urgent backlog**. Build the governance artifact when the product's second real cross-domain question appears — e.g. "does this Organisation's DataSource inventory change our classification of Persons found in it" — not preemptively. The value delivered now is *naming the decisions* (shared hub, Tenant-vs-Organisation, per-domain ownership) so later growth is deliberate, not the ceremony of enforcing them.

---

## Checklist

- [ ] Steward authority split into Data Domain Owner / Business Steward / Technical Steward, expressed as a decision-rights table (all Shafi today is fine).
- [ ] Cross-domain conflict arbitration path named (the Council role = Shafi at solo scale).
- [ ] Three steward queues (match / sensitivity / quality) named as distinct work.
- [ ] Golden-record lifecycle state model documented; un-merge and split are retraction + replay, never DELETE.
- [ ] Shared-hub-vs-per-domain infrastructure decision recorded; re-decided before any fourth master entity.
- [ ] Tenant vs Organisation resolved in writing.
- [ ] Cross-domain relationship graph kept distinct from the Context Map.
- [ ] "Data Domain" disambiguated from DDD "Subdomain".
