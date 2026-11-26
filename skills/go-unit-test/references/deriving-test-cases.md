# Deriving Test Cases

Self-contained. Use before writing a table: derive the rows from the rule, not from the code you are about to write. Method from Jorgensen; behaviour focus from Khorikov.

## Choose the technique by the shape of the rule

| The rule has | Technique | Rows |
|---|---|---|
| An ordered or numeric input with limits | Boundary value analysis | At each limit: just below, on it, just above; plus one ordinary value. Include the values outside the valid range |
| Inputs that fall into groups treated alike | Equivalence classes | One row per valid class and one per invalid class. Where classes can interact, combine them (every combination of the valid classes) |
| Several true/false conditions deciding one outcome (three or more especially) | Decision table | All 2^n rules. Collapse two rules only when a condition truly cannot affect the outcome, and say so. Check every combination has a rule and no two identical rules disagree |
| A lifecycle with named states and guarded moves | State transitions | Every state against every event, refused ones included. Where the order of moves matters, add short sequences (N-switch coverage) |
| Untrusted or free-form input | Fuzzing, in addition | See `./fuzzing.md` |

Choose how deep by risk: single-variable boundaries for low-risk code; combined boundaries or class combinations where an interaction would be costly. Risk adds depth and never removes a coverage obligation.

## What each rejected or failing path asserts

For a method that changes state, prove three things (the domain-model standard in `go-domain-model`):

1. The exact error, with `errors.Is` or `errors.As`.
2. Nothing changed.
3. No Domain Event was recorded; on success, exactly the expected one.

For a function with several ways to fail, give each its own row.

## Then, and only then, read the gate output

Behaviour-derived rows come first. Run the two gates; for each block not run or condition never true or false, ask which behaviour that path serves and add the row that states it, with its assertion. If no behaviour needs the path, delete the code. Never add a call with no assertion to move a number: it raises coverage and proves nothing (Khorikov).

A condition that cannot be made true or false through the public surface is either dead code (remove it) or a gap for the product owner (list it); it is not silently excluded.

## Say what was left out

State which technique produced the rows, which combinations were collapsed and why, and which inputs were not tried. Coverage cannot show a missing rule: tests check only what someone specified.
