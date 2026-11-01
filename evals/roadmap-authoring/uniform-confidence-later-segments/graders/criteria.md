---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It names the uniform confidence (every row High, including Later) as a defect, and in the rewrite confidence decays with the horizon: Next rows below High (e.g. Medium) and Later rows Low.
2. The rewritten Next and Later rows are themes phrased as customer/user problems, not feature or module names ("Offline mode", "Customer portal", "Sprinkler compliance module", "HVAC module", "AI defect detection" must not be the row names), AND the Next and Later rows carry no candidate solutions or features and no delivery dates (horizon labels such as "Q4 2027" as a section heading are acceptable; a date per item is not). Dependencies, scope notes and hypotheses in a row are not candidate solutions.
3. A sprinkler-related Later theme (whether phrased as the sprinkler firms' own problem or as the beachhead's problem with subcontracted sprinkler work) names sprinkler-maintenance firms as the segment it unlocks / the adjacent segment, with the shared certificate or regulator as the reason, AND the HVAC item is not kept as an equal Later theme: it is dropped, moved to "Not On This Roadmap", or explicitly flagged as not adjacent.
4. "Strategic: expands TAM / new vertical / Strategic" links are rejected and replaced by a Key Result, an Objective, or a "Guiding policy: [clause]" reference.
5. Every rewritten Next and Later row shows its stage of development (e.g. research, discovery, development, beta) as a field or column, as the date-free way of showing progress — a "gate", "evidence" or "condition" column alone does not count.
Fail if any of the five is missing.
