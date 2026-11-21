# Example 3 — Enterprise: an existing system, a security slice inside Generic identity, and the order of work (hardest case)

Self-contained. **Fernbank** is a building society replacing its 12-year-old loan origination system, at the **enterprise** profile. Event Storming Big Picture was run with underwriters, branch staff and operations.

## Input

> **User:** "Credit decisioning is Core: our underwriting rules are why brokers send us cases. Identity and access is Generic, so we'll buy a product and leave it out of design. Document generation is Generic too. Plan: rewrite everything and cut over on one bank-holiday weekend. Oh, and the decisioning rules are buried in the application module with the document code."

## Working it

**Step 1: classification.**

| Subdomain | Type | Why |
|---|---|---|
| Credit decisioning | Core | Brokers choose Fernbank for its underwriting of non-standard incomes; complex; nothing buyable encodes it |
| Application intake | Supporting | Specific forms and checks, simple rules |
| Affordability calculation | Supporting | Rules set by the regulator, the same for every lender; complex but not an advantage; revisit if a product appears |
| Identity and access | Generic | Buy an identity product |
| Document generation | Generic | Buy a document service |
| Payments out (completion funds) | Generic | Use the bank's payment rails |

**Step 2: the security axis, separately.** Identity and access: checklist questions 1, 2 and 3 are all yes. The *product* stays bought, but the slice that decides **which underwriter may approve which loan size** (delegated lending authority), and that **nobody approves a case they submitted** (segregation of duties), is Fernbank's own model. A mistake there is a regulatory breach. That slice gets Core-level rigor: named terms (Lending Authority, Approval Limit) in the language, values that can't be created without a valid authority level, and an explicit trust boundary on the approval Aggregate. Payments out is also sensitive (financial) in its mapping of completion amounts.

**Step 3: the tangle.** The decisioning rules are mixed into the application module with document code. **Segregated Core** first: pull the decisioning concepts into their own module, accepting temporary duplication, so the Core is visible.

**Step 4: order of work, not a big bang.**
1. Credit decisioning: Core, and once segregated its risk is bounded. Moved with a **Strangler Fig**: Branch by Abstraction inside the old application module puts a decisioning interface in front of the rules, then a **Parallel Run** compares old and new decisions on live cases before any traffic moves. Lending decisions are costly to get wrong, so equivalence is shown, not assumed.
2. Document generation and identity: **replace** with bought products rather than migrate the custom code.
3. Intake and affordability: later, when the decisioning work needs them.

## Output — the reply

> Credit decisioning as Core is right. Two parts of the plan need to change.
> - **Identity stays in design, at least one slice of it.** Buy the product, yes. But who may approve which loan size, and the rule that nobody approves their own case, are Fernbank's rules, and a mistake there is a regulatory breach. That slice gets the same rigor as the Core.
> - **No single-weekend cutover.** First separate the decisioning rules from the document code so the Core is visible. Then move decisioning behind an interface in the old system and run old and new side by side on real cases, comparing decisions before switching any traffic. Document generation and identity are replaced with bought products, not migrated. Intake and affordability follow later.
>
> I've dated the classification. Affordability gets revisited if a regulatory calculation product appears.

## Why this is right

- Generic was not allowed to mean "no thought": the sensitive slice was named and given Core-level rigor, while the product stays bought.
- The tangle was addressed before the move (Segregated Core), and the move is incremental, with the Strangler Fig mechanic chosen for the risk (Parallel Run for lending decisions).
- Generic subdomains are replaced, not migrated. The order follows the type, the risk and where the value is.
