# IA Validation Methods — Card Sorting and Tree Testing

An IA is a hypothesis about how users expect content grouped, labeled, and found. This
reference is the how-to for the two methods the SKILL.md body names — **card sorting** and
**tree testing** — plus the generative-vs-evaluative distinction that decides which to run
when, and how each method's results feed back into the taxonomy.

Personas assumed: **Data Steward** and **Compliance Officer**. Sample-size and logistics
guidance is scaled for a pre-launch, design-partner-stage product (3–5 named customers) as
well as for larger recruited panels, because this product's real constraint is a small
customer base (see the "small-N" notes throughout).

---

## Generative vs. Evaluative IA Research

The two methods answer different questions and belong at different moments:

| | Card sorting | Tree testing |
|---|---|---|
| Research type | **Generative** — discovers structure | **Evaluative** — tests a structure |
| Question answered | "How would users group and name this content?" | "Can users *find* things in the structure we designed?" |
| IA systems validated | Organization + labeling | Navigation (findability of the hierarchy) |
| When | Early — before or while drafting the taxonomy | After a candidate hierarchy exists, before UI is built |
| Input | A set of content items (cards) | A proposed hierarchy (a bare label tree) + find-it tasks |
| Output | Groupings and category names from users | Success rate, directness, and where users go wrong |

The natural sequence is **generative first, evaluative second**: card-sort to build a
taxonomy grounded in the users' mental model, draft the hierarchy, then tree-test that
hierarchy to confirm people can actually navigate it — and iterate. Running only one leaves
a gap: a card sort with no tree test yields categories nobody has proven findable; a tree
test with no prior card sort evaluates a structure that may never have matched the users'
model in the first place.

---

## Card Sorting

Participants sort content items (each on a "card") into groups that make sense to them. It
surfaces the user's mental model of the domain — the categories they expect and the words
they use — which is exactly the subjective, ambiguous top-level organization scheme that
most needs validation.

### Open vs. closed card sorts

**Open card sort** — participants create their *own* groups and name them. Nothing is
predefined. Use it **generatively**, when you do not yet have a taxonomy, to *discover* what
categories exist in users' minds and what they call them.

- Reveals: the natural grouping structure, category *names* in the users' own words, and
  items that are ambiguous (sorted inconsistently across participants).
- Data Steward example: give 40 cards ("Snowflake connection", "PII scan result", "SOC 2
  gap", "audit trail entry", "asset owner"…). See whether stewards cluster by *source*, by
  *sensitivity*, or by *task* — that cluster choice is your top-level organization scheme.

**Closed card sort** — you provide the group names (a proposed taxonomy) and participants
sort cards *into* your predefined categories. Use it **evaluatively**, when you
already have candidate categories, to test whether your labels and boundaries match how users
think.

- Reveals: whether your category labels are understood, which items land where you expected,
  and which categories are "magnets" (catch everything) or "ghosts" (catch nothing).
- Compliance Officer example: give the categories "Compliance", "Data Sources", "Data
  Assets", "Reports", "Settings" and see whether "Gap Report" reliably lands in "Compliance"
  vs. "Reports" — an item that splits 50/50 signals an ambiguous label needing a facet or a
  clearer name.

**Hybrid (semi-open)** — provide some categories but let participants add their own; a middle
option when you have a partial taxonomy.

### How to run a card sort

1. **Choose the cards** — 30–60 content items sampled across the whole product (too few
   misses structure; too many exhausts participants). Use real content, not made-up labels.
2. **Recruit per segment** — sort with **Data Stewards and Compliance Officers separately**,
   never blended. Olsen's segmentation warning applies directly: the same content can cluster
   differently for a steward (by *source/asset*) than for a compliance officer (by
   *framework/control*). A blended average hides that neither segment is well served.
3. **Sample size** — card sorting stabilizes quickly. Research (Tullis & Wood) shows
   correlation with the "true" grouping plateaus around **15 participants** per segment for a
   closed sort; **8–12** per segment is enough for a qualitative open sort to surface the main
   patterns. At design-partner scale, 4–6 stewards yields usable directional signal — treat it
   as qualitative, not statistical.
4. **Run it** — moderated (watch and ask "why did you group these?") for rich rationale on a
   small N, or unmoderated (tool-based) to scale. Ask participants to name their groups (open)
   and to flag any card they were unsure about.
5. **Analyze** — build an item-by-item agreement matrix (how often each pair of cards was
   grouped together); a dendrogram/cluster analysis shows which items reliably co-occur.
   Category names from an open sort become label candidates.

### How card-sort results feed the taxonomy

- Strong, cross-participant clusters become **top-level categories** in the organization
  system (§1 of the systems reference).
- The words participants used to name groups become **preferred-term candidates** for the
  controlled vocabulary — reconcile against the Ubiquitous Language (glossary wins on domain
  terms; user words win on ambiguous everyday labels).
- Items sorted inconsistently are **ambiguous** — resolve by making them a facet (an asset's
  *sensitivity* is a filter, not a parent) rather than forcing one hierarchy home.
- Magnet and ghost categories from a closed sort signal labels to rename or merge.

---

## Tree Testing

Tree testing (also "reverse card sorting") evaluates **findability** on a proposed hierarchy
*before any UI is built*. Participants see only the bare, text-only label tree — no visual
design, no search box, no page content — and are asked to complete find-it tasks by
clicking down through the tree to where they believe an item lives. It isolates the
navigation structure from every confound (styling, search, copy), so a failure is
unambiguously an IA problem, not a UI one.

### Why "before UI"

Tree testing is the cheapest possible IA validation because it needs no design and no code —
just the label hierarchy from your taxonomy. Finding that 60% of Compliance Officers look for
"Gap Report" under "Reports" instead of "Compliance" costs one test now; finding it after the
compliance-remote has been built and shipped costs a rebuild across a fragment boundary.

### How to run a tree test

1. **Build the tree** — export the proposed hierarchy (the §6 site-map's labels) as a plain
   nested list. No icons, no styling.
2. **Write tasks** — realistic find-it tasks phrased in the *user's* words, not the tree's
   (never leak the answer label). E.g. "You need to see which SOC 2 requirements your estate
   currently fails — where would you go?" The correct answer is the Gap Report node under
   Compliance.
3. **Recruit per segment** — again stewards and compliance officers separately; tasks differ
   by role (stewards do classification/asset tasks; officers do gap/control/report tasks).
4. **Sample size** — tree testing is quantitative and needs more participants than card
   sorting to produce stable success rates. For **statistically meaningful** results aim for at
   least **50 participants** per segment; **10–15** per segment gives directional, qualitative
   signal suitable for the design-partner stage. Scale rigor to the customers actually
   available — do not let the 50-participant target block running the cheaper 10–15 pass now.
5. **Measure** three things per task:
   - **Success rate** — % who ended at the correct node.
   - **Directness** — % who got there without backtracking (a low directness with high success
     means the label is findable but the path is confusing).
   - **First click / where they went** — the wrong nodes people chose reveal *which competing
     label* stole the traffic (the fix is usually renaming or moving one of the two).

### How tree-test results feed the taxonomy

- Low success on a task → the item is in the wrong branch or its label is misread; move it or
  rename it and re-test.
- A consistent wrong destination → two labels compete; disambiguate them (rename, or add the
  item to both via contextual navigation while keeping one canonical home).
- Low directness, high success → the label is right but the tree is too deep or a mid-level
  label is vague; flatten or rename the intermediate node.
- Iterate: tree testing is fast enough to run several rounds, revising the tree between each,
  until success and directness clear an agreed bar before handing the IA to the
  frontend-engineer.

---

## Choosing the Method — Quick Guide

| Situation | Method |
|---|---|
| No taxonomy yet; need to discover categories and their names | Open card sort |
| Have candidate categories; want to test if labels/boundaries match users | Closed card sort |
| Have a full hierarchy; want to know if users can find things in it | Tree test |
| Shipped IA "feels" wrong but no data | Tree test the current tree to locate the failure |
| Adding a new section to an existing microfrontend | Closed card sort the new items against existing sections, then tree-test the merged tree |

Card sorting and tree testing are complements, not alternatives: card sorting builds the
structure from the user's mental model; tree testing proves the resulting structure is
navigable. A validated IA has been through both before a single screen is built.
