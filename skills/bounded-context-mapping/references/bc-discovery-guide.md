# BC Discovery Guide
## Facilitation Procedure for Bounded Context Discovery Workshops

Self-contained reference for the `bounded-context-mapping` skill. Use this when facilitating a
BC discovery session or reviewing the output of one.

---

## Who Attends

A BC discovery workshop requires representation from every area of the domain under discussion.
Recommended attendance:

| Role | Purpose |
|---|---|
| **Domain expert** (one per candidate area) | Supplies the real Ubiquitous Language — the words that practitioners actually use in daily work |
| **Tech lead or architect** | Connects domain concepts to existing system boundaries and deployment units |
| **Product manager / owner** | Holds the strategic view — which capabilities are differentiating (Core) vs. commodity (Generic) |
| **Facilitator** | Keeps the session moving; does not make domain decisions |

A workshop covering 4–8 candidate BCs typically runs 3–4 hours with this group. Fewer than two
domain experts per candidate area is a risk — linguistic fractures only emerge when at least two
different perspectives on the same term are present simultaneously.

---

## Inputs Required Before the Workshop

The BC discovery session should not start from a blank slate. Required inputs:

1. **Event Storming output** — the timeline of Domain Events, Commands, and Aggregates produced
   by the preceding Event Storming session. This is the primary vocabulary source.
2. **Subdomain classification** — from `subdomain-distillation`: which areas are Core, Supporting,
   or Generic. This informs investment and pattern-selection decisions downstream.
3. **Organizational chart or team topology** — who currently owns what; team ownership is one
   of the four boundary signals.
4. **Existing system inventory** — a rough list of what services, applications, or modules exist
   today, if this is not a greenfield engagement.

---

## Step-by-Step: The Linguistic Fracture Line Technique

This technique is the primary tool for discovering Bounded Context boundaries. Run it after
Event Storming output is on the wall and before any architectural decisions.

### Step 1 — Extract Domain Nouns

From the Event Storming output, extract every domain noun that appears:
- As an Aggregate or entity name on a yellow or orange sticky
- As part of a Domain Event name (the subject noun: "DataAsset" in "DataAssetClassified")
- As part of a Command name (the object: "File" in "IngestFile")
- In verbal discussion where participants used domain language

Produce a deduplicated list of candidate nouns. For a medium-complexity domain, expect 15–40 nouns.

### Step 2 — Build the Term Divergence Table

For each candidate noun, ask a representative from each potential area of the domain to write
a one-sentence definition — what does this word mean *in their work*?

Record the definitions side by side in a **Term Divergence Table**:

```
| Term        | Area A definition              | Area B definition              | Fracture? |
|-------------|-------------------------------|-------------------------------|-----------|
| File        | A document stored in Drive    | A parsed, extracted data unit | YES       |
| User        | A person with login rights    | An audit trail actor          | YES       |
| Report      | A compliance summary PDF      | A scheduled data export       | YES       |
| Tenant      | A paying customer org         | A paying customer org         | NO        |
```

**A fracture exists** when two representatives give materially different definitions for the same
term. The boundary falls between the two areas that cannot agree on the word's meaning.

### Step 3 — Map Fractures to Candidate Boundaries

Every YES row in the Term Divergence Table is a candidate boundary. Draw a boundary between the
two areas whose definitions diverge. Name the boundary as a candidate Bounded Context.

A fracture on five or more terms between the same two areas is a strong signal. A single fracture
on one obscure term is a weak signal — validate it with the secondary signals (team ownership,
data ownership, deployment independence) before drawing a firm boundary.

### Step 4 — Validate with Secondary Signals

For each candidate boundary, check:

- **Team ownership**: do different teams currently own code or processes on either side?
- **Data ownership**: would data written on one side of the boundary be the authoritative record
  for that side only, not shared directly with the other?
- **Deployment independence**: would it make sense to deploy, scale, or version one side
  independently of the other?

A candidate boundary supported by at least two signals (linguistic + one other) is a confirmed
Bounded Context boundary. A candidate supported only by a single ambiguous fracture should be
revisited.

---

## Step-by-Step: The Data Ownership Exercise

Run this exercise after the Term Divergence Table to cross-validate boundaries and surface
any that the linguistic fracture technique may have missed.

### Procedure

1. List every persistent entity or record type in the domain (from the Event Storming Aggregates).
2. For each record type, ask: "Which team or process is the single authority that may *write* the
   master record for this entity type?" Write the owner in a Data Ownership Map.
3. Group records by owner. Every distinct owner group is a candidate Bounded Context.
4. Look for records that have contested ownership (two groups both believe they own the master
   record). Contested ownership is itself a boundary signal — the record probably belongs in one
   context, with a Read Model or integration event serving the other.

### Data Ownership Map Format

```
Context: DataAsset Management
  - DataAsset (master record)
  - StorageSource (master record)
  - ExtractionJob (master record)

Context: Compliance Intelligence
  - ComplianceGap (master record)
  - AuditRecord (master record)

Context: Identity & Access
  - Tenant (master record)
  - User (master record)

Context: Reporting
  - ReportDefinition (master record)
  READ-ONLY SOURCES: DataAsset summary (from DataAsset Management), ComplianceGap summary (from
  Compliance Intelligence)
```

A context that only appears in the "READ-ONLY SOURCES" column for every record it uses is not
a BC in the strict sense — it is a consumer context whose boundary is defined by what it
reads, not by what it writes.

---

## "One BC or Two?" Decision Tree

Use this decision tree when a candidate boundary is contested or ambiguous.

```
Is there at least one term that means something different on each side?
  NO → Boundary is probably premature. Keep as one BC.
  YES →
    Do both sides have distinct data they each write exclusively?
      NO → One side is a consumer; treat as a Read Model / projection context.
      YES →
        Would the teams on each side want to evolve their models independently?
          NO → Consider a Shared Kernel; confirm both teams will coordinate changes.
          YES →
            Is the coupling between them dominated by events (async) or by sync calls?
              EVENTS → Confirm as two separate BCs with PL/OHS pattern.
              SYNC CALLS (many, tight) → Check if this is actually one model
                                         being split arbitrarily. If the sync
                                         calls cannot be eliminated, reconsider
                                         whether one BC is correct.
```

**Practical threshold:** If two candidate BCs would have more than three synchronous call
patterns between them at steady state, they are likely one BC that has been split on a
technical axis (e.g., persistence vs. logic) rather than a linguistic axis. Merge them and
look for the real fracture elsewhere.

---

## Resolving Contested Boundaries

When two domain experts disagree about whether a boundary exists:

1. **Ask for the canonical example.** "Give me a real business scenario where the two meanings
   of [term] would lead to a wrong answer if you used the other side's definition." If no one
   can produce a concrete scenario, the fracture may be linguistic but not material.

2. **Check deployment history.** Has either side ever needed to deploy its changes without
   coordinating with the other? Historical deployment events are strong empirical evidence of
   real independence.

3. **Apply the Vernon three-question test** (from `aggregate-design`): would using the wrong
   definition cause real business harm — not just surprise — even momentarily? If yes, the
   fracture is material enough to draw a firm boundary.

4. **Default to fewer, larger BCs.** Evans and Vernon both warn against premature splitting.
   A God Context is recoverable — add a boundary later as you learn more. A Nano-Context
   fragmentation is much harder to undo once services are deployed.

---

## Anti-Patterns in BC Discovery

### The God Context
**What it looks like:** One context absorbs most of the domain's concepts. The Term Divergence
Table has many YES rows but they are all attributed to one catch-all area rather than leading
to distinct boundaries.

**Why it fails:** The God Context grows until it is itself a monolith with no internal linguistic
clarity. Every addition "belongs here" by default, and the Ubiquitous Language degrades into
an overloaded namespace.

**Correction:** Look for the linguistic fracture lines inside the God Context. Run the Term
Divergence Table *within* the God Context's vocabulary only. There are almost always two or
three distinct languages hiding inside a God Context.

### The Nano-Context
**What it looks like:** Every Aggregate or database table is declared its own "context."
The workshop produces 30 BCs for a medium-complexity domain.

**Why it fails:** Aggregates are a transactional-consistency mechanism *within* a context, not
a context boundary themselves (Evans explicitly distinguishes these granularities; the
`bounded-context-mapping` body's "Context per Aggregate" anti-pattern entry covers this).
Integration overhead explodes. Each service boundary adds a network call, a schema contract,
and a failure mode.

**Correction:** Apply the "one BC or two?" decision tree strictly. If two candidate contexts
share a Ubiquitous Language and cannot produce a concrete scenario where the split prevents a
wrong answer, merge them.

### Mistaking Technical Layers for Context Boundaries
**What it looks like:** "API Context," "Database Context," "Worker Context" appear on the map.

**Why it fails:** These layers share one language — there is no linguistic fracture between
"the API layer" and "the worker layer" in the same domain area. The boundary is technological,
not semantic.

**Correction:** Draw boundaries where the language changes, not where the technology changes.
A REST API and its backing database are implementation details of one Bounded Context.
