# Discovery Techniques

The detail behind `SKILL.md` § 2–3: the term divergence table, the record-ownership pass, the "one context or two?" test, resolving a contested boundary, and the God and Nano-Context patterns. Grounded in Evans (*Domain-Driven Design*, Ch. 14), Khononov (*Learning Domain-Driven Design*) and Vernon, as summarised in `research/domain-driven-design/strategic-design-supplement.md`. Heuristics marked *house* are this plugin's. Examples use several products.

## 1. The term divergence table

The main technique: it finds where words change meaning.

1. **Collect the domain nouns:** from the Event Storming wall (subjects of Domain Events, objects of Commands, actors, read models), domain story work objects, and each context's language document. Expect 15–40 for a medium domain.
2. **For each noun, write one sentence per area of the business:** what does it mean *there*? In agent-run mode, cite the artifact each meaning comes from; a meaning no artifact gives is *assumed*.
3. **Mark a fracture** where the sentences differ materially:

| Term | Catalogue | Enrolment | Certification | Fracture? |
|---|---|---|---|---|
| Course | A published description with modules and a price | A cohort a learner joins, with start date and seats | The set of assessments that leads to a certificate | Yes |
| Learner | — | A person with a seat in a cohort | A candidate with an assessment record | Yes |
| Module | A unit of content | A unit of content | A unit of content | No |

4. **Each fracture is a candidate boundary** between the areas that disagree. Many fractures between the same two areas is a strong signal; one fracture on an obscure word is weak, so confirm it (§ 2–3) before drawing a firm line.

## 2. The record-ownership pass

Cross-checks the table and catches boundaries it missed.

1. List every record type (from the Aggregates on the Event Storming wall).
2. For each, ask: which area is the single authority that may **write** the master record?
3. Group records by writer; each group is a candidate context.
4. **Contested ownership** (two areas both think they own a record) is itself a boundary signal: the record belongs to one context, and the other reads it through events or a read model.

```
Catalogue        writes: Course Listing, Price
Enrolment        writes: Cohort, Seat
Certification    writes: Assessment, Certificate
Reporting        reads only: Cohort summary, Certificate summary
```

An area that only reads is a consumer of other contexts' facts, not a context with its own model, unless its own language and rules say otherwise.

## 3. "One context or two?"

```
Does at least one important term mean something different on each side?
  NO  → Keep one context. The split is premature.
  YES → Does each side write records the other doesn't?
          NO  → One side is a consumer: a read model or projection, not a second context.
          YES → Two candidate contexts. Then check the coupling:
                Would most operations need the other side synchronously, every time?
                  YES → (house) Suspect one model split on a technical axis; look for the
                        real fracture elsewhere before confirming two.
                  NO  → Confirm two contexts; hand the line to context-map-patterns.
```

**Not part of the test:** how many teams there are (a constraint, not a signal) and whether each side needs to deploy separately (`container-diagram`'s question).

**House threshold:** more than about three steady-state synchronous calls between two candidate contexts usually means one model split on a technical axis.

## 4. Resolving a contested boundary

1. **Ask for the wrong-answer case:** "a real scenario where using the other side's meaning of this word gives a wrong result." If nobody can produce one, the fracture may be real in words but not in the model.
2. **Check who writes what** (§ 2).
3. **Ask what a mistake would cost:** if mixing the two meanings would cause real business harm, even briefly, the boundary is material.
4. **Default to fewer, larger contexts** (Khononov's start-wide heuristic; Evans and Vernon warn against premature splitting). A wide context can be split later as the model settles; a fragmented one is far harder to merge once built. Record the candidate split and what would trigger it.
5. In agent-run mode, a boundary still contested after this goes to the product owner as an open question, with the boundary used meanwhile.

## 5. God Context, Nano-Context, technical layers

| Pattern | Looks like | Why it fails | Correction |
|---|---|---|---|
| **God Context** | One context absorbs most concepts; its key words have several meanings | The language degrades into an overloaded namespace | Run the term divergence table inside it; there are usually two or three languages hiding |
| **Nano-Context** | A context per Aggregate or per table; 30 contexts for a medium domain | Aggregates are transactional units inside a context; integration overhead explodes | Apply § 3 strictly; merge contexts that share a language |
| **Technical layers** | "API context", "Worker context", "Database context" | They share one language; the line is technological | Draw lines where the language changes |
