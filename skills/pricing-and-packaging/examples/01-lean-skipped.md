# Example 1 — A lean paid consumer app: the artifact is skipped (simplest case)

Self-contained. A small consumer app built by one person, at the **lean** profile, where `phase-requirements.json` **skips** the pricing-and-packaging artifact. It shows where the pricing decision lives instead, why a tier matrix would be waste here, and the trigger that would bring the artifact in.

## Input

> Product: **Partwise**, a phone app that plays a choir singer's own vocal part from a score so they can practise between rehearsals. Built and run by one person.
>
> Lean Canvas (approved), Revenue block: subscription, per singer per month. WTP: 9 singers asked, stated £2–4 acceptable, £6 expensive, £10 too expensive; 14 singers paying £2.99 through the beta (committed). Cost to serve: about £0.30 per singer per month (audio rendering).
>
> The user: "Should we do Basic, Pro and Premium tiers? Maybe £1.99, £3.99 and £6.99, with Premium adding themes and an ad-free mode?"

## Working it

- **Default at lean: no artifact.** The phase plan skips it; the price lives in the Lean Canvas Revenue block, one price point with its basis.
- **Is there more than one pricing segment?** No. Every singer asked values the same leader (their part, played back, at their tempo). WTP ranges overlap. One segment means one offer (rule 2).
- **The proposed tiers fail the skill's own tests anyway:**
  - The leader (part playback) is in all three tiers; Pro and Premium differ only in fillers (themes, ad-free). There is **no fence**, so almost everyone would buy Basic at £1.99.
  - £1.99 is below the committed £2.99 with no network effect or lock-in: planned **minivation**.
  - Ads in a practice app were never tested; if singers dislike them, ads are a **killer** in the cheapest tier.
- **Kept instead, in the Lean Canvas Revenue block:**

```markdown
**Revenue:** subscription, £2.99 per singer per month. WTP: stated £2–4 (9 singers); committed £2.99 (14 paying beta singers). Cost to serve ~£0.30. One offer, no tiers: one segment, one leader. Price strategy: maximisation; test £3.49 for new sign-ups after 50 paying singers.
```

## The trigger that would bring the artifact in

Choir **directors** have started asking to buy for a whole choir of 30–60 singers. If interviews show directors value different leaders (assigning parts, seeing who practised) and pay from a choir budget at a different WTP, that is a second pricing segment. At that point the product moves to the **standard** profile, or the user asks for the artifact, and it is written with two offers and a fence (the director dashboard, held only by the choir plan).
