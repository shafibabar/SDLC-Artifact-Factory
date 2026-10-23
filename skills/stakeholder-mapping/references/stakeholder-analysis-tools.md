# Stakeholder-Analysis Tools (delivery side) — Reference

Self-contained. Read this when placing delivery stakeholders on the grid, choosing the scale, deciding when to re-score, writing decision rights, or planning who to see before a review. Each tool is credited to its source; none of them comes from the Challenger books (those cover the customer side, in `./buying-committee.md`).

## 1. The power/interest grid (Mendelow; Eden and Ackermann)

Aubrey Mendelow's matrix (early 1980s and 1991, popularised in Johnson and Scholes, *Exploring Corporate Strategy*) relates a stakeholder's **power** over the product's success to their **interest** in its outcome. Two axes, four quadrants, one strategy each:

| Quadrant (this plugin) | Mendelow | Eden and Ackermann | Strategy |
|---|---|---|---|
| **Manage Closely** | Key players | Players | Involve in decisions; early input; regular two-way contact |
| **Keep Satisfied** | Keep satisfied | Context setters | Meet their needs; do not over-communicate; **watch for interest rising**, and pre-empt their concern |
| **Keep Informed** | Keep informed | Subjects | Communicate regularly; often allies and early warnings |
| **Monitor** | Minimal effort | Crowd | Watch for changes in power or interest |

**The scale.** The grid is qualitative: high or low on each axis, with a one-line reason ("can refuse the production deployment"; "reads release notes, never asks"). A three-point score has no source and leaves the midpoint undefined. If the team wants a number, use **1–5, where 3 and above is high**, and state that rule in the artifact's register heading.

**Cadences are this plugin's convention, not Mendelow's.** Typical defaults: Manage Closely weekly or bi-weekly; Keep Satisfied monthly plus event-driven; Keep Informed monthly or at milestones; Monitor at gates. Change them to fit the people.

**Acting on the grid (Eden and Ackermann, *Making Strategy*, 1998).** The grid is a starting point for action, not a census. Ask: who could move from Subject to Player if a coalition formed (design partners who start influencing a reviewer)? Which Context setter must be kept from becoming a hostile Player? At enterprise, draw **influence links** (who influences whom), because a stakeholder's power often runs through someone else: the platform team's view reaches the security reviewer through the SRE lead. A short list of `A → B: how` lines is enough.

## 2. Stakeholder salience (Mitchell, Agle and Wood, 1997)

Attention follows three attributes: **power** (can they impose their will), **legitimacy** (is their claim proper or recognised), **urgency** (is it time-sensitive and critical to them).

| Attributes | Class |
|---|---|
| Power only | Dormant |
| Legitimacy only | Discretionary |
| Urgency only | Demanding |
| Power + legitimacy | Dominant |
| Power + urgency | Dangerous |
| Legitimacy + urgency | Dependent |
| All three | Definitive |

Salience adds the time dimension the grid lacks. A security reviewer with power and legitimacy is **dominant**; the day a deployment request lands, urgency appears and they become **definitive**. Rule: **any stakeholder who gains urgency is re-scored that day**, not at the next gate. Use salience explicitly for regulators and auditors at enterprise: a supervisor is dormant until a review is scheduled.

## 3. Decision rights: RACI and its variants

RACI comes from practice; no single author is credited.

| Letter | Meaning |
|---|---|
| **R** Responsible | Does the work to reach the decision or outcome |
| **A** Accountable | Owns the outcome; **exactly one per row**; a person who can be asked why |
| **C** Consulted | Two-way input before the decision |
| **I** Informed | One-way notice after |

**Agents and hooks.** In this plugin AI agents draft artifacts and hooks enforce gates. Both may be **R**. Neither may be **A**: accountability belongs to a person (usually the product owner) who approves, can be questioned, and can override.

**Variants.** RASCI adds Support; RACI-VS adds Verify and Sign-off; CAIRO adds Out of the loop; DACI (Driver, Approver, Contributors, Informed) suits one-off decisions; Bain's **RAPID** (Recommend, Agree, Perform, Input, Decide) separates **Decide** from **Agree**, where Agree is a **formal veto**. Use an **Agree** column when a security, privacy or compliance sign-off can block a release, so the veto is visible in advance instead of surfacing at the gate as an overlooked "C".

**Typical failures:** too many Cs (everyone consulted, nothing decided); an R with no authority to do the work; an A so senior they never engage; two As.

## 4. Pre-wiring: shuttle diplomacy and nemawashi (Lombardo et al.)

*Product Roadmaps Relaunched* treats buy-in as work done before a review, not in it. **Shuttle diplomacy**: meet key stakeholders one at a time, learn their concerns, show how their input shaped the draft, resolve objections privately. **Nemawashi**: prepare the ground informally with everyone a decision affects, so the formal meeting confirms an alignment. The aim is alignment on direction, not consensus on every item.

In the map: for each gate review, list the order in which delivery stakeholders are seen, and why that order (the veto holder before the group; the person whose concern shapes the draft first). For a solo product owner this collapses to one move: before asking for approval, list the decisions the owner is most likely to push back on, with the reason for each (`roadmap-authoring` does this at lean).

## 5. What this artifact is not

- **Not a service ecosystem map.** Stickdorn et al., *This Is Service Design Doing*, map actors and value exchanges inside a service, built with the people who run it. That answers how the service works; this answers who must agree. Same word, different artifact.
- **Not a persona set.** Personas are written in Ideate (`user-persona`) from the committee roles; delivery stakeholders do not become personas.
