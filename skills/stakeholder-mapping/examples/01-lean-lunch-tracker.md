# Example 1 — A lean internal tool: the map is skipped, a delivery list on request (simplest case)

Self-contained. A product built by one person for one 20-person office, at the **lean** profile, where `phase-requirements.json` **skips** the stakeholder map. It shows where the "who decides" line lives instead, and the half-page delivery list written when the user later asked for one. There is no buying committee: nothing is sold.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Vision (approved): "Everyone in the office gets the lunch they chose, on time, without the admin chasing anyone."
>
> The user, after the strategy kernel was approved: "The office manager has to OK the chat bot, and IT controls what gets installed in our chat. Can you do a stakeholder map so I don't get blocked?"

## Working it

- **Default at lean: no artifact.** Internal stakeholders are the product owner alone, and the buyer is not a separate party: the office pays for lunch, not for the tool. The Lean Canvas Customer Segments block already says "the office's 20 staff; the admin runs the order".
- **The user asked directly**, so a delivery list is written: the **delivery half only**. A buying committee would be invented: no organisation decides to buy anything.
- **No grid.** With four people, a grid adds nothing; each gets a High/Low note and one action.
- **The one risk is a Context setter.** IT has the power to refuse the chat integration and no interest in lunch. That is the profile that silently blocks a launch, so the request goes to IT with the answer to their concern attached, before anyone installs anything.
- **Decision rights in one line**, because the product owner is the only person who decides; the agents draft and build.

## Output — the delivery list (written on request)

```markdown
---
name: stakeholder-map
product: lunch-tracker
version: 1.0.0
phase: strategy
owner: product-strategist
created: 2026-10-23
summary: Lunch tracker needs IT to approve the chat bot's permissions and the office manager to agree the cost split; IT is the one launch risk.
profile: lean
traces_to: strategy/vision-statement.md
---

# Stakeholder Map (lean, delivery only)

## 1. Delivery Stakeholders

Scale: High / Low with a reason.

| Stakeholder | Power | Interest | Quadrant | Engagement need |
|---|---|---|---|---|
| The product owner (builds and runs it) | High — decides everything | High — it is their tool | Manage Closely | — |
| Office admin (sends the combined order) | Low — cannot stop it, but can ignore it | High — it removes their 10:30 chase | Keep Informed | Try it for a week before launch; say what the restaurant needs in the order |
| Office manager (owns the lunch budget) | High — can refuse the per-person split | Low — lunch already works "well enough" | Keep Satisfied | One message: the split matches what the payroll deduction does today |
| IT (controls chat integrations) | High — can refuse the bot | Low — no stake in lunch | Keep Satisfied | The bot's permission list (read one channel, post in one channel, no file or directory access) sent **with** the install request |

**Decision rights:** every decision is the product owner's (Accountable); the agents are Responsible for drafts and code only. IT **Agrees** (can veto) the chat integration.

**Pre-wiring:** IT first, with the permission list; then the office manager; then a one-week trial with the admin.

## 2. Customer Buying Committee

None: nothing is sold; the office does not buy the tool.
```

## What was left out, and why

| Standard component | Left out because |
|---|---|
| Grid diagram | Four people; the register already shows each quadrant |
| Engagement cadences | Each person needs one conversation before launch, not a schedule |
| Buying committee | No purchase decision exists |
| Blocker Risk Register | One risk (IT), handled in its register row |
| Re-score log | Re-scored only if the product grows past one office, which would move it to standard |
