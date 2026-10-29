# MoSCoW and Kano — Two Different Axes

Self-contained reference for `moscow-prioritization`. Read it when a story's Kano class is offered as the reason for its MoSCoW bin ("it's Basic, so it's a Must"), when ordering the contingency, and when the backlog has no differentiator left after the cut. A worked case is in `../examples/02-standard-rebound.md`.

The Kano model is Noriaki Kano's. This plugin uses it as Dan Olsen does in *The Lean Product Playbook*: classify the feature set by the shape of its satisfaction curve, then bin it with a delivery-window method such as MoSCoW. Mike Cohn (*User Stories Applied*) also uses Kano, as a way to reason about *why* a feature matters, which is a different question from how much room the release has. MoSCoW itself is DSDM's.

---

## 1. Why they are different axes

| | MoSCoW | Kano |
|---|---|---|
| **Question** | For this release, what is guaranteed and what is contingency? | For this feature, how does satisfaction respond to its presence, absence and quality? |
| **Unit** | Per story, per release | Per feature, per persona or segment |
| **Depends on** | A release; meaningless without one | Nothing about a release; only customer expectations |
| **Output** | Must / Should / Could / Won't this time | Basic / Performance / Delighter (+ Indifferent / Reverse) |
| **Changes when** | The release or its constraint changes | The market's expectations shift (today's Delighter is tomorrow's Basic) |

A feature has one Kano class per persona and, independently, one MoSCoW bin per release. Kano says **where extra investment pays off** and **what differentiates**; MoSCoW says **what this release guarantees**.

---

## 2. The Kano classes

- **Basic (threshold, must-be):** expected table stakes. Absence causes strong dissatisfaction; doing it better than the baseline adds no satisfaction. Meet the bar and stop.
- **Performance (one-dimensional):** satisfaction rises roughly in line with how well it is delivered. Buy it incrementally.
- **Delighter (attractive, excitement):** unexpected. Absence causes no dissatisfaction; presence causes disproportionate delight and word of mouth.
- **Indifferent:** nobody cares either way. Investment is waste.
- **Reverse:** some segment prefers its absence.

Olsen classifies with a **paired question** per feature: the functional form ("how would you feel if it had this?") and the dysfunctional form ("…if it did not?"), each answered like it / expect it / neutral / can tolerate it / dislike it, cross-referenced in the Kano table. The pair separates the cost of absence from the value of presence, which a single importance rating mixes up. Classes are **segment-specific**: classify per persona, never on a blended average. With a handful of design partners, a survey is not feasible: classify from interview snapshots and label the class **directional**.

Three different meanings of "must" are in play and must not be confused: the **MoSCoW Must** (a release guarantee), the **Kano must-be** (Basic, a satisfaction class) and the **Planguage Must** (an NFR's minimum acceptable level, `nfr-specification`).

---

## 3. How a Kano class informs a MoSCoW bin

There is no fixed one-to-one mapping. The cross-tab is a sanity check:

| Kano class | Typical bin | Signal |
|---|---|---|
| **Basic** | Often Must | A Basic that is **not** a Must gets a **second look** with the Must test and the workaround clause. If a workaround exists, it stays a Should, but is cut late, because its absence is felt sharply. Never promote on the class alone |
| **Performance** | Must, Should or Could by release | Invest incrementally: the skeleton gets the minimum, the contingency buys more |
| **Delighter** | Should or Could (rarely Must) | Absent, it fails the Must test, so it is rarely a Must. It may be the release's only differentiator: **protect it**, last in its tier's cut order |
| **Indifferent** | Won't this time (or close) | Do not spend a release on it; drop it first if it slipped into the contingency |
| **Reverse** | Won't, for the segment that dislikes it | Exclude, or gate it behind a setting |

Illustration, not a rule: audit logging that a regulator requires is typically **Kano-Basic** (auditors assume it, and over-building it adds nothing) and a **MoSCoW Must** (illegal without it). The two answers agree for different reasons; that is the point of keeping the axes apart.

**The forcing function:** a contingency with **zero Delighters** is differentiation-free by construction. Run the Kano pass partly to confirm at least one Delighter survives in the release or in the next one.

---

## 4. Sequencing the two

1. Candidate features and needs exist (`jtbd-analysis`, `user-persona`).
2. **Kano pass:** classify each candidate per persona.
3. **MoSCoW pass:** the Must test and workaround clause on every story; Musts = walking skeleton; bin the rest.
4. **Reconcile:** every Basic that is not a Must gets its second look; Delighters are flagged and placed last in their tier; Indifferent and Reverse go to Won't.

Kano informs the contingency order and catches miscategorised Basics. It never replaces the Must test: the release's guarantee is still decided by "what happens if it is not delivered, and is there a workaround?"
