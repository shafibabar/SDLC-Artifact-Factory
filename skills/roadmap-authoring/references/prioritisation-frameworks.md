# Prioritisation Frameworks for Roadmap Themes

Self-contained. Read this when choosing how to order roadmap themes, or when scoring them at standard or enterprise. The frameworks are the ones Lombardo, McCarthy, Ryan and Connors survey in *Product Roadmaps Relaunched*. The book does not prescribe one; its point is that **the choice of framework, and the scores, are visible in the artifact**, so stakeholders argue about the inputs rather than the outcome, and that a framework supports judgement without replacing it.

Two rules from Rumelt (*Good Strategy / Bad Strategy*) run **before** any framework, and override it:

1. **Weakest link first.** If one capability caps the value of everything else, its theme goes first in Now, whatever its score.
2. **Coherence.** Now themes must reinforce each other or the guiding policy. A high-scoring theme that reinforces nothing is still a cut candidate.

The framework orders what is left.

---

## Which framework, by scale

| Profile | Default | Why |
|---|---|---|
| **lean** | **Critical path** | One person, few themes, little data. Ordering by what blocks the customer from reaching value is fast and needs no scores |
| **standard** | **Value / effort / confidence scorecard** | Several themes compete for one team; scores make the trade visible to the stakeholders in the engagement plan |
| **enterprise** | **Scorecard per product area**, plus the cross-area dependency order | Swimlanes compete for shared platform work; dependencies across areas often decide the order before the scores do |
| any | **Kano**, as a supplement | When the question is "which needs are table stakes?" before scoring the rest |

Record the choice in the artifact's **How this was prioritised** line. At standard and enterprise, show the scores.

---

## Critical path

Walk the steps a customer must go through to get value from the product, in order. Anything that blocks that path comes first; anything that only improves a step already passable comes later.

- **Use when:** early product, solo product owner, themes that are mostly "can the customer get through at all".
- **Output:** the themes listed in the order the customer meets them, with the blocking step named.
- **Watch for:** treating every step as blocking. A step is blocking only if a real customer stops there today.

## Kano model

Sort customer needs into **basic expectations** (absence causes dissatisfaction; presence earns nothing), **performance needs** (more is better, roughly in proportion) and **delighters** (unexpected; absence costs nothing). Basic expectations must be met before delighters earn anything.

- **Use when:** deciding what is table stakes for a segment, often the next bowling-alley segment (Moore).
- **Output:** each theme tagged basic / performance / delighter for the target customer.
- **Watch for:** delighters decay into basics over time; re-check at each revision.

## Desirability / feasibility / viability

Score each candidate on whether customers want it, whether it can be built with the means at hand, and whether it serves the business (the KRs). A theme weak on any one is a risk to name, not to hide.

- **Use when:** a theme's risk is mixed and the team needs to see which kind of risk dominates.

## Value / effort / confidence scorecard

The book's ROI-style scorecard, in the shape this plugin uses (the exact scales are this plugin's convention; the book's own scorecard shape is recalled with less certainty):

| Theme | Value (1–5, against the KRs it serves) | Effort (1–5, 5 = largest) | Confidence (0.5 / 0.8 / 1.0 for Low / Medium / High) | Score = Value × Confidence ÷ Effort |
|---|---|---|---|---|

- **The confidence factor** stops a high-value guess beating a well-understood theme on paper alone.
- **Value is scored against the KRs**, not against stakeholder enthusiasm. A theme serving no KR has no value score, and should not be on the roadmap.
- **Use the score to order, then apply judgement**, and say in the revision history when judgement overrode the score and why.

---

## What this is not

- **Not MoSCoW.** `moscow-prioritization` works at release scope in Ideate (which stories are in the Minimum Usable SubseT). Roadmap prioritisation orders strategic themes. The two meet when the story map's release slices test the Now horizon.
- **Not a replacement for the guiding policy.** A theme the policy rules out does not get scored; it goes to "Not On This Roadmap".
