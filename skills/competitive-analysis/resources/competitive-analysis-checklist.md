# Competitive Analysis Checklist — Run Before Hand-Off

Self-contained. Cross-check every competitive analysis against this list before presenting it to the user. Each row is a hard stop: an analysis that fails a row goes back with the failing row named. Rows marked *(standard+)* do not apply at lean.

| # | Check | How to test it | Fails when |
|---|---|---|---|
| 1 | **Alternatives first** | Is section 1 the first content section? Is doing nothing listed? For a B2B buying group, is no decision listed? | Vendors only; doing nothing absent; substitutes as one afterthought row |
| 2 | **Criteria before scores** | Are the buyer's criteria listed, weighted and sourced before the matrix? | Criteria appear only as matrix rows, or come from the product's feature list |
| 3 | **Axes from the buyer** *(standard+)* | Are the map's axes the two heaviest criteria in section 2? | Axes chosen because the product sits alone there |
| 4 | **Every claim labelled** | Pick any cell about an alternative. Does it cite an evidence ID with a source and date, or `unverified (model knowledge)`? Are prices treated as claims? | Any unlabelled vendor fact; a blanket disclaimer instead of per-claim labels; an invented source or date |
| 5 | **Evidence requested** | Is the list of evidence asked of the user present? | Model knowledge used with no request for verification |
| 6 | **Honest substitutes** | Does at least one substitute or doing nothing score ✓ or ~ somewhere it is genuinely strong? Are composite cells decomposed into the whole product? | Every alternative ✗ on every row (the flattering matrix) |
| 7 | **Three filters** | Does each differentiation point cite its evidence (real), its criterion (valued) and why it can't be copied or bought (defensible)? | "Better UX", "AI-powered", "first mover"; a point valued by no listed criterion |
| 8 | **Evidence status passed on** | Is a point resting on an unverified claim marked `hypothesis`? | An unverified point handed to the kernel as fact |
| 9 | **Looks back** *(standard+)* | Is the win/loss log present, with outcome won / lost / no decision and the point each row confirms or contradicts, or the date it starts? | Forward-looking risks only |
| 10 | **Hand-off** | Does section 10 name the advantage candidates, the alternative to beat, and what would show the advantage is not real? | The kernel must guess |
| 11 | **Shape and scale** | Frontmatter has `name`, `version`, `phase`, `owner`, `created`, `summary`; size matches the Scale table in the skill | Missing `summary`; a lean analysis padded with a SWOT and map |

## Fast triage order

1. Row 4 (unlabelled vendor facts): the most damaging, because they travel into pricing and positioning.
2. Row 1 (no doing-nothing alternative).
3. Rows 3 and 6 (the flattering matrix).
4. Row 7 (unfiltered differentiation points).
5. The rest.
