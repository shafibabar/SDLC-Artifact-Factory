# Evidence Labels and the Win/Loss Log

Self-contained. Read this when filling the evidence register (step 4), deciding what to ask the user for, or recording a closed trial, pilot or deal in the win/loss log (step 8). It covers why vendor facts need labels, the label set, the evidence request, and how win/loss outcomes feed the GTM strategy and the strategy kernel.

---

## 1. Why every vendor claim is labelled

The agents that apply this skill have no web-research tool. Anything they "know" about a competitor's price, features, deployment model or customers comes from model memory: possibly years old, possibly wrong, and indistinguishable in tone from a verified fact. Written as fact, such a claim travels: into the kernel's advantage, the canvas, the positioning statement and the price list. A requirement that research be "recent" cannot be met by memory, so the analysis states where each claim comes from instead.

## 2. The evidence register

Every claim about an alternative gets an ID (E1, E2, …) and a row; matrix cells cite the ID.

| Field | Holds |
|---|---|
| ID | E1, E2, … |
| Claim | One checkable statement: "Suite A's AR module needs a consultant to import history" |
| Source | Where it came from: the user's demo notes, a pricing page the user pasted, a lost-deal call, an analyst report. Or `model knowledge` |
| Date | The date of the source ("as of" date). For model knowledge, the model's knowledge cut-off if known, else "unknown" |
| Status | `verified` (a source the user supplied or a first-hand observation) · `user-reported` (the user's own statement, not yet documented) · `unverified (model knowledge)` |

Rules:
- **No blanket disclaimer.** A sentence at the top saying "some facts may be out of date" does not tell the reader *which* ones. Label claim by claim.
- **Prices are claims.** A competitor's price is the claim most likely to be stale. Give it a row like any other, or leave the cell `?`.
- **Unknown is allowed.** `?` with "ask the user" is better than a confident guess.
- **What depends on what.** A differentiation point whose "real" filter rests on an unverified claim is itself `hypothesis`, and the hand-off to the kernel says so.

## 3. The evidence request

Ask the user, early and specifically, for what would turn the claims that matter into verified ones. Record the request in the artifact so the next revision knows what is still open. Ask first for evidence behind the claims that a differentiation point depends on.

Typical asks:
- Pricing pages or quotes the user can paste (with the date they saw them).
- Notes from demos or trials of the alternatives.
- What customers said they used before, and what else they looked at.
- Lost-deal and churn reasons, in the customer's words.
- Analyst or review-site comparisons the user trusts.

Never fabricate a source, a date or a figure to fill the register.

## 4. The win/loss log (Lauchengco)

Competitive risks look forward and guess. The win/loss log looks back and records: after every closed trial, pilot, design-partner evaluation or deal, one row.

| Field | Holds |
|---|---|
| Date | When the decision was made |
| Account / trial | Who (anonymised if needed) and which segment |
| Weighed against | The alternative the buyer compared us with: a vendor, the spreadsheet, doing nothing |
| Outcome | `won` · `lost` · `no decision` (the group stayed with the status quo) |
| Stated reason | The buyer's own words, with the source (call notes, exit survey) |
| Differentiation point | Which point it confirms, contradicts, or does not touch |

**When it fires something:**
- An outcome that **contradicts** a differentiation point (a buyer who cared about none of it; a loss to an alternative the matrix said lacked nothing important) fires `gtm-strategy`'s **Positioning Refresh Trigger**: the positioning and message house are re-examined.
- A **pattern** of contradictions (or of no-decision losses) is evidence for the strategy kernel's **review trigger**: the diagnosis or the advantage may be wrong. Revise the kernel before the next OKR cycle, not mid-quarter on one deal.
- A repeated `no decision` usually means the buying group never agreed on the problem; record which role held out (`stakeholder-mapping`).
- Each row also updates the matrix where it brings evidence: a verified claim replaces an `unverified (model knowledge)` one.

**When the log starts:** at the first closed trial or deal. Before that, the log is present with "no entries yet; starts with [the closed beta / the first design partner]". At lean, keep a log only if users can actually choose an alternative.
