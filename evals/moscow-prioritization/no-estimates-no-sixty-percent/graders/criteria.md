---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does NOT produce person-week (or point, day or hour) estimates for the stories and does NOT check the Musts against a 60% capacity ceiling. It explains why (for example: the plugin has no effort estimates, AI agents build the product, or the percentage would be false precision) and replaces the ceiling with structural checks: the Musts must be the walking skeleton, and the release must keep a Should / Could tier that can be dropped.
2. The final Must list is the walking skeleton and only the skeleton: none of the six stories off the skeleton (US-2, US-4, US-6, US-8, US-9, US-10) is a Must, and the response gives a workaround or "the journey walks without it" reason for demoting them (for example: describe the problem at drop-off instead of US-2; phone the rider about a parts quote instead of US-4). Each skeleton story (US-1, US-3, US-5, US-7) is either a Must; or, if the response finds a workaround for it, is moved off the skeleton and replaced by a named manual step; or is put to the product owner (or committee) as an open question, saying that if it is demoted a named manual step replaces it on the skeleton so the Must list and the skeleton still match.
3. The Should and Could stories are put in an explicit order in which they would be dropped (a numbered or ordered cut list, or an explicit "drop first … then …").
4. At least one story is Won't this time, with a reason and a point at which to look at it again (a release or a trigger).
Fail if any of the four is missing.
