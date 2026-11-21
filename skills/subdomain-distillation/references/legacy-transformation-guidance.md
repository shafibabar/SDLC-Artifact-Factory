# Legacy Transformation Guidance

The detail behind `SKILL.md` § 7. Applies only to a system that already exists; a new product doesn't need it. Grounded in Evans (*Domain-Driven Design*, Ch. 15: Segregated Core), Khononov (*Learning Domain-Driven Design*: types change over time) and Newman (*Building Microservices*: the Strangler Fig and its mechanics), as summarised in `research/`. The sequencing rules in § 1 are this plugin's own guidance, built on those sources; they are labelled as such.

## 1. Classification decides the order

For a new product, the type mainly decides effort. For an existing system it also decides **which subdomain is touched first**. Getting that wrong either spends credibility on a change nobody values, or takes on large risk before anyone trusts the new approach.

**This plugin's sequencing rules:**

1. **Start with a Core subdomain.** Its value secures the funding and attention a transformation needs. A transformation that starts with something Generic struggles to justify itself.
2. **…whose risk is bounded.** Not the most tangled, riskiest part of the system, even if it is Core. A failed first step kills appetite for the rest. Choose a Core piece where a mistake has a contained blast radius.
3. **…and where people already feel the pain.** A subdomain the business already complains about builds momentum faster than one chosen on technical grounds.
4. **Replace Generic subdomains; don't migrate them.** If a product now exists for something the old system built by hand (a common result of a type changing over time, Khononov), replacing it is usually cheaper and safer than untangling and preserving custom code that never needed to be custom.
5. **Supporting subdomains wait**, and are migrated when the Core work needs them or when they block something.

## 2. Moving a piece: the Strangler Fig

Once the first subdomain is chosen, it moves while the old system keeps running (Newman). A new implementation grows around the old capability and gradually takes its traffic until the old code path can be deleted. Newman's three mechanics:

| Mechanic | What it does | Use when |
|---|---|---|
| **Intercepting at the edge** | A routing layer in front of the old system sends specific requests to the new implementation and everything else to the old one | The capability is reachable through distinct requests or URLs |
| **Branch by Abstraction** | An interface is introduced inside the old system in front of the capability; callers depend on the interface while the implementation behind it is swapped | The capability is called from inside the old code, not from outside |
| **Parallel Run** | Old and new run side by side on the same input; outputs are compared before traffic moves | Getting it wrong is costly (money, compliance), so equivalence must be shown, not assumed |

Where the edge-routing layer goes is an architecture decision for `container-diagram`.

If the chosen Core subdomain's code is tangled with generic or supporting concerns (common in old systems), **Segregated Core** (`./classification-techniques.md` § 5) is the first step: the separated Core is what the Strangler Fig then moves.

## 3. Classification is contested in an existing organisation

In a new product, classification is mostly a modelling judgement. In an existing organisation, people disagree about what is Core: departments, leaders and engineers carry different histories and incentives. The domain-modeler drafts the classification with its evidence, but a disputed label is a **business priority** decision for the product owner, not something the agent settles on its own authority. Present the disagreement, the evidence on each side and what each choice would mean for the order of work.

## 4. Transformation order table

Recorded in the classification artifact for an existing system:

| Subdomain | Type | Tangle and risk | Order | Why |
|---|---|---|---|---|
| [name] | Core / Supporting / Generic | Low / Medium / High | 1st, 2nd, … / Replace / Later | [one line, citing the rule in § 1] |
