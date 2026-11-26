# Deriving Test Cases

Self-contained. Use before writing tests: derive the cases from the rule, not from the code you are about to write. Method from Jorgensen, *Software Testing*; behaviour focus from Khorikov.

## Choose the technique by the shape of the rule

| The rule has | Technique | Cases |
|---|---|---|
| An ordered or numeric input with limits | Boundary value analysis | At each limit: just below, on it, just above; plus one ordinary value. Include values outside the valid range |
| Inputs that fall into groups treated alike | Equivalence classes | One case per valid class and per invalid class. Where classes can interact, combine them |
| Several true/false conditions deciding one outcome (three or more especially) | Decision table | All 2^n rules. Collapse two only when a condition truly cannot affect the outcome, and say so. Every combination has a rule; no identical rules disagree. Three booleans are eight cases, not three happy ones |
| A lifecycle with named states and guarded moves | State transitions | Every state against every event, refused ones included; short sequences where order matters |
| An invariant, a round trip, or a very large input space | Property, in addition | See `./property-based-testing.md` |

Choose depth by risk: single-variable boundaries for low-risk code; combined boundaries or class combinations where an interaction would be costly. Risk adds depth and never removes a coverage obligation.

## What each refused or failing path asserts

For a method that changes state, prove three things (the domain-model standard in `python-domain-model`):

1. The exact exception class with `pytest.raises`, and its typed attributes. Never `Exception`; message text is not a contract.
2. Nothing changed.
3. No Domain Event was recorded; on success, exactly the expected one.

Put the assertions **after** the `with pytest.raises(...)` block: a line inside it, after the call that raises, never runs (seen).

## Then, and only then, read the gate output

Behaviour-derived cases come first. For each line not run or branch not taken, ask which behaviour that path serves and add the case that states it. If no behaviour needs the path, delete the code. Never add a call with no assertion to move a number: it raises coverage and proves nothing (Khorikov).

## Say what was left out

State which technique produced the cases, which combinations were collapsed and why, and which inputs were not tried. Coverage cannot show a missing rule: tests check only what someone specified.
