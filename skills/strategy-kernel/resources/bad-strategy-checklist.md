# Bad-Strategy Checklist — Run Before Hand-Off

Self-contained. Cross-check every strategy kernel against this list before presenting it to the user. Each row is a hard stop: a kernel that fails any row goes back with the failing row named, never with a vague "make it sharper". Rows 1–4 are Rumelt's four hallmarks of bad strategy (*Good Strategy / Bad Strategy*); rows 5–10 check the kernel's shape and its links to the other Strategy artifacts.

| # | Check | How to test it | Fails when |
|---|---|---|---|
| 1 | **Fluff** | Delete every adjective, buzzword and abstraction ("innovative", "best-in-class", "leverage", "world-class", "synergy"). Read what is left. | No decision is left standing |
| 2 | **Challenge faced** | Ask a reader who has not seen the vision: "What obstacle does this strategy address?" | They cannot answer in one sentence, or the answer is the goal restated ("we're not big enough yet") |
| 3 | **Goal or strategy** | Underline every number and every "become / grow / lead / achieve". Does the rest say *how*? | The kernel says *how much* and not *how*; targets stand where the policy should be |
| 4 | **Objectives** | Look at the proximate objectives handed to the OKRs. | A long list from every function (dog's dinner) or an end state with no next step (blue-sky) |
| 5 | **Crux** | Is the named challenge important (solving it unlocks much of the rest) *and* addressable (the team can act on it)? Are the challenges set aside listed? | It is unaddressable ("the market leader is huge"), trivial, or several challenges are named with none chosen |
| 6 | **Falsifiable** | Is there a stated piece of evidence that would show the diagnosis is wrong, with where it will come from? | Nothing could disprove it |
| 7 | **Policy rules out** | Count the tempting directions the policy says no to, and check each has a reason traced to the diagnosis. | Fewer than two (lean) or three (standard and enterprise), or exclusions with no reason |
| 8 | **Advantage** | Does the policy name the advantage, leverage or focus it relies on? Is a claimed advantage traceable to the competitive analysis (real alternatives, attributes that are real and valued)? | No source of power, or an advantage asserted with no alternative named |
| 9 | **Coherence** | For each action, find the action or policy clause it reinforces. Check pairs for conflict (two actions competing for the same people or pulling the product two ways). | An action reinforces nothing, or two actions work against each other |
| 10 | **Shape and trace** | Frontmatter has `name`, `version`, `phase`, `owner`, `created`, `summary`; the vision is named in `traces_to`; size matches the profile (lean ≈ 150 words; standard one page; enterprise line kernels name the parent kernel). | Any field missing, untraced, or the wrong size |

## Fast triage order

When reviewing someone else's draft, check in this order. The earlier rows are cheaper and catch the most common failures:

1. Row 3 (goals as strategy): the commonest failure.
2. Row 2 (no challenge named).
3. Row 1 (fluff).
4. Row 7 (policy rules nothing out).
5. Row 9 (actions not coherent).
6. The rest.

## What a passing kernel hands on

- **To `okr-authoring`:** the proximate objectives (no numbers). Each Objective in the OKR set must follow from the guiding policy.
- **To `roadmap-authoring`:** the coherent actions and their reinforcement links. Each roadmap item serves an action; each "not on this roadmap" entry cites a rules-out reason.
- **To `business-model-canvas` and `gtm-strategy`:** the advantage (the canvas's Unfair Advantage) and any focus choice (the GTM beachhead).
