# MoSCoW and Kano — Two Different Axes, and a Worked Prioritization

Reference material for `moscow-prioritization`. The SKILL.md body states that MoSCoW and
Kano answer different questions. This file makes the relationship precise, gives the full
category-to-category mapping, and works a prioritization of this repo's backlog through
both lenses so the two are visibly complementary rather than redundant.

The Kano model is Noriaki Kano's feature-classification framework. Its adoption here
follows Dan Olsen, *The Lean Product Playbook*, which uses Kano to classify a Feature Set
by the *shape of the satisfaction-response curve* before that set is binned into a
delivery-window prioritization method such as MoSCoW.

---

## 1. Why they are different axes, not two flavors of the same thing

| | MoSCoW | Kano |
|---|---|---|
| **Question answered** | Given a *fixed capacity constraint*, which scoped stories are IN this release versus deferred? | For a *given feature*, what is the shape of the curve between how well it is built and how satisfied customers are? |
| **Unit** | Per story — binary (in / out of this release) | Per feature — a curve classification (flat, linear, exponential) |
| **Depends on** | A delivery window / capacity — meaningless without one | Nothing about a delivery window; only the presence/absence and quality of the feature |
| **Output** | Must / Should / Could / Won't bins for one release | Basic / Performance / Delighter (+ Indifferent / Reverse) classes |
| **When run** | After the feature set is scoped, against a specific release | Once candidate features exist, typically *before or alongside* MoSCoW binning |
| **Changes when** | The delivery window or capacity changes | The market's expectations shift (today's Delighter is tomorrow's Basic) |

They are orthogonal. Kano tells you *where marginal investment pays off* and *which items
differentiate*; MoSCoW tells you *what fits in the next release*. A feature has one Kano
class and, independently, one MoSCoW bin per release.

---

## 2. The Kano classes (as used by Olsen)

Each candidate feature is classified by how its presence/absence and quality move
satisfaction:

- **Basic (Threshold / Must-be):** expected table stakes. Absence causes strong
  dissatisfaction; presence beyond the baseline adds *no* satisfaction — a flat,
  diminishing-returns curve. Customers simply expect it and stop noticing once met.
- **Performance (One-dimensional):** satisfaction scales roughly *linearly* with how well
  it is delivered. More/better genuinely produces more satisfaction; less produces
  dissatisfaction.
- **Delighter (Attractive / Excitement):** unexpected. Absence causes *no* dissatisfaction
  (nobody expected it); presence produces disproportionate delight — an exponential curve.
  Differentiation and word-of-mouth come disproportionately from these.
- **Indifferent:** customers do not care either way — investment here is waste.
- **Reverse:** some segment actually prefers the feature's *absence*.

Kano classification uses a paired **functional / dysfunctional** survey question per
feature ("How would you feel if it had this?" / "…if it did NOT?"), cross-referenced in a
Kano table — which separates the cost of *absence* from the value of *presence*, something
a single importance rating conflates. Classes are also **segment-specific**: a Delighter
for the Compliance Officer can be Indifferent for the IT lead, so classify per persona,
never on a blended average.

---

## 3. The mapping — how a Kano class informs a MoSCoW bin

There is **no fixed one-to-one mapping** — that is the whole point. But the cross-tab is a
powerful sanity check. The interesting cells:

| Kano class | Typical MoSCoW bin | Sanity-check signal |
|---|---|---|
| **Basic** | **Must** (usually) | A Kano-Basic that is *not* a MoSCoW-Must is a likely miscategorization — its absence causes strong dissatisfaction, which usually fails the necessity test. Look again. |
| **Performance** | Must → Should → Could, by capacity | Invest *incrementally* — buy the amount of Performance the ~60% Must budget and the Should/Could buffer afford, not all of it. |
| **Delighter** | **Should or Could** (rarely Must) | A Delighter absent does *not* fail the necessity test, so it is rarely a Must — but it may be the release's only differentiator. Flag Delighters so they are protected from being cut as generic "nice to have." |
| **Indifferent** | **Won't** (or drop) | If customers do not care, do not spend a release slot on it. |
| **Reverse** | **Won't** for the segment that dislikes it | Building it actively harms a segment — exclude, or gate behind a setting. |

The two cases the SKILL.md body names, expanded:

- **MoSCoW-Must + Kano-Basic:** SOC 2 control mapping. Expected (Basic — auditors and the
  Compliance Officer simply assume it exists), and its absence fails the release on the
  legal/contractual criterion (Must). Building it *better* than the compliance bar adds no
  satisfaction — so meet the bar and stop; do not gold-plate a Basic.
- **MoSCoW-Should + Kano-Delighter:** a feature the Data Steward would not miss if absent
  (fails the necessity test → not a Must) but that produces outsized delight and
  word-of-mouth if present (Delighter). MoSCoW alone would file this next to genuinely
  low-value Shoulds; Kano flags it as the differentiator to protect first when the buffer
  is under pressure.

**The forcing function:** a feature set with **zero Delighters** is differentiation-free by
construction — every item is either table stakes (Basic) or linear grind (Performance).
Run the Kano pass partly to confirm at least one Delighter survives the MoSCoW cut.

---

## 4. Worked prioritization — data-estate / compliance backlog

Release: MVP, 8-week window, ~16 person-weeks capacity, Must ceiling ~9.6 person-weeks.
Primary persona: the Data Steward. Secondary: the Compliance Officer. Each story is scored
on **both** axes, then reconciled.

| Story | Kano class (primary persona) | MoSCoW bin | Reconciliation note |
|---|---|---|---|
| US-001 Connect Google Drive via OAuth | Basic | **Must** | No source, no product; Basic + necessity-test pass — consistent. |
| US-005 Run initial scan, classify files by sensitivity | Performance→Basic | **Must** | The release goal ("first gap in 30 min") fails without it. Classification *accuracy* is Performance — buy accuracy incrementally, do not perfect it now. |
| US-009 View compliance gap report | Basic | **Must** | The gap report *is* the first-value moment — Basic and necessity-critical. |
| US-014 SOC 2 access-audit logging | Basic | **Must** | Legal/contractual criterion. Kano-Basic — meet the audit bar and stop; over-building adds no satisfaction. |
| US-010 Export gap report as PDF | Performance | **Should** | The Compliance Officer can present from the app meanwhile; absence degrades audit-prep but does not block it. |
| US-021 One-click "remediation suggestion" per gap | **Delighter** | **Should** | Would not be missed if absent (not a Must) — but this is the release's differentiator. **Protect from cuts before other Shoulds.** |
| US-006 Real-time scan-progress bar | Performance | **Could** | A static "scan running" state suffices; live progress is comfort. Absence barely noticed. |
| US-030 Custom report theming / logos | Indifferent | **Could / Won't** | Kano-Indifferent for the Steward — do not spend a Must or Should slot; drop if capacity is tight. |
| US-003 Connect SharePoint | Basic (for a *different* segment) | **Won't (this release)** | Design-partner evidence: Google Drive + S3 covers the ICP. Acknowledged, target Release 3. |

**Capacity check:** the four Musts (US-001, 005, 009, 014) estimate at ~9 person-weeks ≈
56% of the 16-week capacity — inside the ~60% ceiling. US-010's promotion to Must (which
the Compliance Officer might argue) would push Musts over the ceiling — so the necessity
test governs: the Officer is the *secondary* persona and can present from the app, so it
holds at Should.

**What the Kano lens added that MoSCoW alone missed:** US-021 (remediation suggestion) is
a Should on both readings — but Kano marks it a Delighter and therefore the differentiator
to defend when the Should/Could buffer is squeezed, rather than a generic "nice to have"
cut alongside US-006 and US-030. And US-030 (theming) is a Should-looking cosmetic that
Kano exposes as Indifferent — safe to drop first. MoSCoW ranked *release necessity*; Kano
ranked *satisfaction leverage*; together they say **keep US-021, cut US-030 first.**

---

## 5. Sequencing the two techniques

1. Identify candidate features/needs (see `jtbd-analysis`).
2. **Kano pass** — classify each candidate (Basic / Performance / Delighter /
   Indifferent / Reverse), per persona, not blended.
3. **MoSCoW pass** — bin the scoped stories into Must / Should / Could / Won't against
   the release's capacity constraint (`references/moscow-rubric.md`).
4. **Reconcile** — every Kano-Basic that is not a Must gets a second look; confirm at
   least one Delighter survives as a Should/Could and is flagged for protection; drop
   Indifferent/Reverse items to Won't.

Kano informs, but never replaces, the Must/Should/Could/Won't decision — the release
constraint still decides what ships.
