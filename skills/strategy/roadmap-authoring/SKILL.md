---
name: roadmap-authoring
description: >
  Teaches how to build an outcome-based product roadmap — one that communicates
  direction and sequencing without committing to feature specifications. Covers
  theme-based and Now/Next/Later formats, how to connect roadmap items to OKRs,
  confidence levels, dependency notation, and how to communicate uncertainty
  honestly. Used by the product-strategist agent after OKRs and GTM strategy
  are defined.
version: 1.0.0
phase: strategy
owner: product-strategist
tags: [strategy, roadmap, product-discovery, okr, sequencing]
---

# Roadmap Authoring

## Purpose

A roadmap communicates **where the product is going and in what order**, without locking the team into a delivery schedule for features that have not yet been fully understood.

The single most common roadmap failure is treating it as a release schedule — a list of features with dates. This creates false certainty, creates commitments that cannot be honoured, and prevents the team from responding to what they learn.

An outcome-based roadmap communicates: the outcomes we intend to achieve, the order in which we intend to achieve them, and our current confidence in that sequence.

---

## What a Roadmap Is Not

| Anti-pattern | Why it fails |
|---|---|
| Feature list with dates | Locks delivery before discovery; creates promises that undermine trust when broken |
| Sprint plan disguised as a roadmap | Too granular; changes every two weeks; not useful for stakeholders |
| Wishlist with no sequencing rationale | Every item looks equally important; does not communicate strategy |
| Competitor copy | Builds what competitors built, not what your ICP needs |

---

## Roadmap Formats

### Format 1 — Now / Next / Later (recommended for early-stage products)

Three time horizons with decreasing specificity:

| Horizon | Meaning | Specificity |
|---|---|---|
| **Now** | Currently in active development or next quarter | Outcome-level, with defined success criteria |
| **Next** | Planned for the following 2–3 quarters | Outcome-level, confidence > 70% |
| **Later** | Directionally committed but timing uncertain | Theme-level, confidence 30–70% |

### Format 2 — Quarterly Theme Roadmap (recommended for post-launch products)

Organises the roadmap into quarterly periods, each anchored by 1–2 themes. A theme is a strategic outcome, not a feature category.

```
Q3 2026 — Theme: "Frictionless Onboarding"
  Outcome: Any SMB can connect their first storage source and see their first compliance gap within 30 minutes
  OKR link: KR2 — 80% of trials reach first value within 30 minutes
  Confidence: High

Q4 2026 — Theme: "Compliance Coverage Depth"
  Outcome: SOC 2 CC6 and CC7 controls are automatically mapped and evidence is generated
  OKR link: KR3 — 5 paying customers with SOC 2 audit support delivered
  Confidence: Medium

H1 2027 — Theme: "Multi-Framework Intelligence"
  Outcome: GDPR and ISO 27001 mapping available alongside SOC 2
  OKR link: Strategic — expands TAM
  Confidence: Low
```

---

## Step-by-Step Production

1. **Gather inputs.** Read the OKR set, GTM strategy, and vision statement. The roadmap is the delivery sequence that makes the OKRs achievable.

2. **Choose the format.** Use Now/Next/Later for the first roadmap. Use quarterly themes once there is enough validated learning to plan further ahead.

3. **Define roadmap items as outcomes, not features.** Each item answers: "What will users be able to do, or what will be measurably true, that is not true today?" Not: "What will we build?"

4. **Sequence by value and dependency.** The first item in "Now" or Q1 must deliver the most validated, highest-value outcome with the lowest uncertainty. Items that are prerequisites for later items must appear before them.

5. **Assign confidence levels.** Every item gets a confidence level: High (> 80%), Medium (50–80%), Low (< 50%). Confidence reflects how well the outcome is understood, not whether the team can build it.

6. **Link each item to an OKR or the vision.** If an item cannot be linked to an OKR or directly to the vision, it should not be on the roadmap.

7. **Note dependencies.** If a roadmap item depends on an architectural decision, a third-party integration, a regulatory approval, or another roadmap item, note it explicitly.

8. **Add explicit unknowns.** A good roadmap names what is NOT on it and why. Stakeholders trust a roadmap more when it acknowledges uncertainty honestly.

---

## Outcome vs Feature — Examples

| Feature (wrong) | Outcome (right) |
|---|---|
| "Build Google Drive connector" | "Users can see all files stored in Google Drive classified by sensitivity within 5 minutes of connecting" |
| "Add GDPR module" | "Compliance team can generate a GDPR Article 30 data processing register automatically from discovered entities" |
| "Improve dashboard performance" | "Dashboard loads to an interactive state in under 2 seconds for estates with up to 1 million files" |
| "Fix onboarding" | "80% of new users complete setup without contacting support" |

---

## Communicating Uncertainty

A roadmap that communicates false certainty destroys trust when reality diverges. Use these conventions:

| Confidence | Visual treatment | Meaning |
|---|---|---|
| High | Solid border, specific outcome | Well-understood; low change risk |
| Medium | Dashed border, outcome-level | Direction set; details may change |
| Low | Dotted border, theme-level only | Strategic intent; timing and scope uncertain |

Always include a roadmap preamble that states: "This roadmap reflects our current understanding and will be updated as we learn. Confidence levels indicate how certain we are about the sequence and scope, not whether the items are important."

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Outcome framing | Every item describes what will be true, not what will be built | Any item is a feature or a task |
| OKR traceability | Every item links to an OKR or the vision statement | Items with no traceable strategic purpose |
| Confidence levels | All items have explicit confidence levels | No indication of certainty or uncertainty |
| Sequencing rationale | The order of items reflects value and dependency logic | Items ordered by gut feeling or political pressure |
| Honest unknowns | "Later" items are less specific than "Now" items | All items at same level of specificity regardless of horizon |

---

## Output Format

```markdown
---
artifact: strategic-roadmap
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
format: [now-next-later | quarterly-themes]
---

# Strategic Roadmap

> This roadmap reflects current understanding and will be updated as we learn.
> Confidence levels indicate certainty of sequence and scope, not importance.

## Now (Current quarter)

| Outcome | OKR Link | Confidence | Dependencies |
|---|---|---|---|

## Next (Following 2–3 quarters)

| Outcome | OKR Link | Confidence | Dependencies |
|---|---|---|---|

## Later (Directional — timing uncertain)

| Theme | Strategic rationale | Confidence |
|---|---|---|

## Explicitly Not On This Roadmap

[List of capabilities or directions deliberately excluded and why]
```

See `references/roadmap-template.md` for a worked example with the first product.
