# The Customer's Buying Committee — Reference

Self-contained. Read this when writing the buying-committee half of the map: choosing roles, filling belief / objection / proof, labelling likely profiles, naming the Mobilizer and the Blocker, and, at enterprise, planning collective learning and the consensus kit. Sources: Brent Adamson, Matthew Dixon, Pat Spenner and Nick Toman, *The Challenger Customer*; Dixon and Adamson, *The Challenger Sale*; Geoffrey Moore, *Crossing the Chasm*.

## 1. Why the committee is mapped separately

The committee is a set of **roles in a kind of organisation**, not people the team knows. It is a hypothesis about a segment, confirmed only by real conversations with design partners. So it gets no grid placement and no cadence: you cannot meet "the finance director of a 20-person accounting firm" monthly. What it gets is what each role must believe, what will stop it, and what evidence answers it.

## 2. Start from Moore's split

Every committee starts with two roles that are often different people:
- **Economic buyer**: owns the budget and the organisational risk. A pragmatist economic buyer judges total cost of ownership, whole-product completeness and references, not technical elegance.
- **User / champion**: feels the pain, often found the product.

Then add the functions that review the purchase: security, finance or procurement, legal or privacy, IT or operations, the wider user team. A self-serve trial still meets them at procurement, when a user's card purchase becomes an invoice and a security questionnaire.

## 3. The consensus problem and "no decision"

B2B purchases are decided by a group spanning functions, each with its own priorities and personal risks. The book's central claim: the more people involved, the less likely the group buys at all. Deals rarely die because a rival wins; they **stall**, because the group cannot agree on what the problem is and drifts back to the status quo. **No decision** is the main competitor. The committee section therefore states, per role, **what staying put costs them** (and notes the role for whom it costs nothing: that is the no-decision risk). Individual stakes weigh as heavily as company stakes: more work for a team, a reputation risk. Settling for the option nobody objects to is the lowest-common-denominator trap.

## 4. Seven profiles: attitudes, not titles

*The Challenger Customer* sorts customer stakeholders by **behaviour toward change**, not job title:

| Group | Profile | Recognise it by |
|---|---|---|
| **Mobilizers** (can move the organisation) | Go-Getter | Driven by results; "how do we make this happen?" |
| | Teacher | Driven by ideas; persuades colleagues; carries a new way of thinking |
| | Skeptic | Tests every claim; hard to win; very influential once convinced |
| **Talkers** (accessible, cannot build consensus) | Guide | Shares inside information freely; cannot move the organisation |
| | Friend | Likes you, takes every meeting; the person most often mistaken for a champion |
| | Climber | Supports what makes them look good |
| **Blocker** | Blocker | Defends the status quo; little interest in change |

Rules for the map:
- Write every profile as **likely** ("Skeptic, likely"). A CISO can be any profile. "CISO = Blocker" stated as fact is a defect.
- Do **not** plan to convert the Blocker. The book's advice is to equip a Mobilizer to deal with them inside the organisation.
- **The Mobilizer test:** offer an insight that challenges how they see their problem. A Talker asks what it means for them; a Mobilizer asks what it means for the company and acts on it, or (Skeptic) pressure-tests it. The map says which design-partner conversation will run that test.
- **Friend-as-champion:** the contact who answers every email and loves the beta may be a Friend. If they never bring a colleague in, look for who does.

## 5. Per-role row

| Field | What goes in it |
|---|---|
| Role | Function and seniority, never a person's name |
| Must believe to say yes | The one belief this role needs, in its own terms |
| Likely objection | What it will say, in its words |
| Proof that answers it | A specific artifact or evidence: a security brief, an import on their own data, a reference customer, a pilot result |
| Likely profile | Mobilizer (which) / Talker (which) / Blocker — "likely" |
| Loses by staying put | What no decision costs this role; "nothing" is an important answer |
| Confirmed by | Which design-partner conversation, beta observation or win/loss entry will confirm or replace the hypothesis |

## 6. Enterprise additions

- **A committee per segment or tenant type.** An enterprise tenant and an SMB tenant buy through different groups even on the same product.
- **Collective learning.** Get the committee to agree on the **problem** (the cost of the status quo) before anyone compares solutions. If members first meet over competing proposals, each defends its own priority and the group stalls. The map names the session or material that does this, and who brings it in (the Mobilizer, not the vendor).
- **Consensus kit.** One page per role: its concern, the answer, the proof, so the Mobilizer can win colleagues over. The map lists the pages; the GTM's messaging says how they are delivered.
- **Salience for outside parties.** Regulators, supervisors and external auditors are not committee members, but their urgency changes the committee's: a scheduled supervisory review turns a dormant claim into a definitive one. Record them with their salience class (see `./stakeholder-analysis-tools.md` §2).
- **Unteaching.** Committees arrive with a picture of the problem formed elsewhere. *The Challenger Sale*'s reframe (an insight that disrupts that picture and leads to something only this product does) is written in the GTM's messaging; the map records which role holds the picture that must change.

## 7. What transfers to a product with no sales team

The Challenger books are written for field sales in long B2B deals. What transfers to a self-serve or product-assisted motion is the **map** (who decides, who can mobilise, who blocks, what no decision costs) and the **content** (the reframe and the consensus kit, delivered through the trial, the docs and a short assisted call). The field-sales choreography does not.

## 8. Blocker concerns: choose the lever

| Kind of concern | Lever |
|---|---|
| Security or infrastructure trust ("this tool is itself a data risk") | A factual brief delivered before the request: architecture, data flow, verification offer |
| Trust in the product's automated decisions ("can I rely on what it classifies / matches / recommends?") | Transparency into how each output was reached, with its evidence and a way to correct it (Srinivasan, *Simple Data / MDM*: trust in automated decisions is its own concern) |
| A powerful person who is not motivated | Beside the facts, a short change story: a comparable organisation, what changed, what it cost to wait (Dietz and Silverman, *Business Storytelling For Dummies*) |

No statistics from the Challenger research are reproduced here; if an artifact needs a figure, it must be checked against the book.
