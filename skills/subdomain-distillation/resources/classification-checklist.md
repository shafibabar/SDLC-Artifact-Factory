# Classification Checklist

Check `artifacts/<product>/design/subdomain-classification.md` against this list before the domain-modeler's review gate. Any "no" is fixed first.

## Inputs and timing

- [ ] It was drawn from the Event Storming Big Picture (named in `traces-to`), not from a feature list alone. Anything classified before the Big Picture is marked provisional.
- [ ] It carries a `classified-on` date.

## Finding the subdomains

- [ ] Every row is a subdomain with one type, not a department or a feature heading with mixed types inside.
- [ ] Splitting stopped where the parts would all get the same type; same-type siblings are one row, not one row per feature.
- [ ] No row is described as a Bounded Context or a service. Contexts are drawn later (`bounded-context-mapping`), services in `container-diagram`.

## Each label

- [ ] All three tests are answered with evidence: advantage, complexity, solved elsewhere.
- [ ] No subdomain is Core because it is hard; none is Core while being simple.
- [ ] No subdomain is Generic only because it will be outsourced. Outsourcing fits Supporting; buying or adopting fits Generic.
- [ ] One or two Core subdomains, or a stated reason for more.
- [ ] The sourcing and modelling columns follow from the type (Core: Domain Model; Supporting: Transaction Script or Active Record; Generic: a thin integration).
- [ ] Every label has a revisit trigger.

## Security axis

- [ ] The security checklist was run for every subdomain, and the result recorded, including "none".
- [ ] Every flagged subdomain names its slice and the rigor it gets, whatever its type.

## Standard and enterprise

- [ ] A Domain Vision Statement about the Core model (not the product's market).
- [ ] A Highlighted Core.
- [ ] For an existing system: the transformation order, with Generic subdomains considered for replacement.

## At the gate

- [ ] Disputed labels are open questions for the product owner, with the label assumed meanwhile.
