---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Northgale Assurance**, a claims-handling platform for a mid-sized property insurer, on the **enterprise** profile. Our Claims context had adjusters saying "Loss" and "Claim" interchangeably for the same thing: a policyholder's report that something was damaged, which then gets assessed and settled. We agreed "Claim" is the term and "Loss" is banned.

Here's where we are:

- I added "Loss: banned, use Claim" to the plugin's own glossary (the `glossary-management` one) so the terminology drift hook will catch it everywhere, in every product.
- The Go code still has a `LossRecord` struct and a `ReportLoss` handler, the public claims API still returns a `loss_id` field, and our Gherkin scenarios still say "Given a loss has been reported".
- Our Reinsurance context also uses "Loss", but for the aggregated loss amount on a treaty, which is a different thing from a Claim.

The ban is in the glossary, so I'd like to mark the Ubiquitous Language work as done and move on to Implement. Can you confirm that's fine?

Using this plugin's ubiquitous-language skill, answer in your reply, not in a file.
