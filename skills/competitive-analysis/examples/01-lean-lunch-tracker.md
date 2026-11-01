# Example 1 — A lean internal tool: alternatives only (simplest case)

Self-contained. A product built by one person for one 20-person office, at the **lean** profile, where this artifact is optional. It is written here because the office admin asked, before any building started, "why not just use the restaurant's group-order page?" It shows that at this size the analysis is half a page, that its real competitors are the current habit and doing nothing, and that no vendor research is needed.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Vision (approved): "Every working day, everyone in the office gets the lunch they chose, on time, and nobody owes or chases anybody."
>
> What the user knows: today the admin posts the menu in the office chat, collects replies by hand and keeps a running debts note on her phone. Two people tried the restaurant's group-order page last year.

## Working it

- **Alternatives first.** Doing nothing here means "everyone orders their own lunch": it is a real alternative, and it is what happens on days the admin is away. The current habit (chat thread plus a note) is the substitute to beat. The restaurant's group-order page is the only "vendor".
- **Criteria from the buyer.** The "buyer" is the admin and the regulars. Their words: "I don't want another app", "I just want the money sorted", "it has to work by 10:30". Three criteria, no category lens, no committee.
- **Evidence.** Every claim comes from the user (the admin) or the two colleagues who tried the group-order page. Nothing is from model memory, so nothing needs the `unverified` label.
- **What is left out at lean:** no positioning map, no SWOT, no risk table, no win/loss log (nobody is choosing between vendors).

## Output — the competitive analysis artifact

```markdown
---
name: competitive-analysis
product: lunch-tracker
version: 1.0.0
phase: strategy
created: 2026-10-22
summary: Lunch-tracker's real alternatives are the chat-and-notes habit and ordering alone; its only edge is ordering and settling inside the chat already in use.
owner: product-strategist
profile: lean
traces_to: strategy/vision-statement.md
---

# Competitive Analysis

## 1. Competitive Alternatives

| # | Alternative | Type | What the office does today | Evidence |
|---|---|---|---|---|
| A1 | Everyone orders their own lunch | Doing nothing | Happens when the admin is away; more deliveries, no group discount | Admin (user-reported) |
| A2 | Chat thread + debts note | Substitute | Admin posts menu, chases replies, tracks debts on her phone | Admin (user-reported) |
| A3 | Restaurant's group-order page | Direct | Each person orders on the restaurant's site under one group link | Two colleagues who tried it (user-reported) |

## 2. Buyer's Evaluation Criteria

| # | Criterion | Whose | Weight | Where it came from | Table stakes? |
|---|---|---|---|---|---|
| C1 | No new app to open | Regulars | high | Admin: "nobody will install another app" | no |
| C2 | Debts settle exactly, without chasing | Admin | high | Admin's debts note | no |
| C3 | Order reaches the restaurant by 10:30 | Admin | medium | Problem statement | yes |

## 3. Evidence Register

| ID | Claim | Source | Date | Status |
|---|---|---|---|---|
| E1 | The group-order page needs each person to log in on the restaurant's site | Two colleagues who tried it | 2025 | user-reported |
| E2 | The group-order page does not split one combined bill | Same | 2025 | user-reported |

**Evidence requested from the user:** none outstanding.

## 4. Capability Matrix

| Criterion (weight) | Lunch-tracker | A1 Order alone | A2 Chat + note | A3 Group-order page |
|---|---|---|---|---|
| C1 No new app (high) | ✓ (in the chat) | ✓ | ✓ | ✗ [E1] |
| C2 Exact settling (high) | ✓ | ✓ (nobody owes) | ✗ | ✗ [E2] |
| C3 By 10:30 (medium) | ✓ | ~ | ~ | ✓ |

Note the honest cells: ordering alone also needs no app and leaves no debts. What it loses is the group order itself.

## 7. Differentiation Points

| # | Point | Real | Valued | Defensible | Evidence status |
|---|---|---|---|---|---|
| D1 | Order and settle inside the chat the office already uses | A2 and A3 lack exact settling [E2] | C1, C2 | Not defensible against a determined copier, and it does not need to be: this is an internal tool | verified (user-reported) |

**Considered and cut:** "menu photos" — valued by nobody on the criteria list.

## 10. Hand-off to the Strategy Kernel

- **Advantage candidates:** D1, as leverage (an existing habit), not a market advantage.
- **The alternative to beat:** A2, the admin's current chat-and-note habit; if the tool is more effort than that, she will go back to it.
- **The advantage is not real if:** regulars still miss 10:30 when ordering in the chat.
- **Table stakes for requirements:** C3.
```

## What a weak first draft looked like

> "Competitors: Deliveroo for Business, Uber Eats group orders, ezCater. Our product is cheaper and simpler than all of them."

It lists vendors nobody in the office considered, from model memory, with no labels, and leaves out the two alternatives the office actually uses. "Cheaper and simpler" is not a criterion the admin named. It hands the kernel nothing it can rely on.
