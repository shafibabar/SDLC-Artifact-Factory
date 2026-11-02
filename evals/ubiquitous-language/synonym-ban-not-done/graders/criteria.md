---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the work is not done: a synonym ban is complete only when the code (`LossRecord`, `ReportLoss`), the API field (`loss_id`) and the Gherkin scenarios use "Claim" too, because the team uses one language in speech, writing, diagrams and code, the code is the model, and a document that no longer matches the code is worse than none (strategic-design supplement, Core Concepts: Evans Ch. 2 "a change in the language is a change to the model" and "a glossary is a record of the language, not the language"; domain-driven-design-evans, Model-Driven Design; Wave 2 findings, ubiquitous-language eval idea (b) and example 3).
2. It says the ban must not live in the plugin's own `glossary-management` vocabulary: Northgale's terms, banned synonyms and homonyms belong in the product's own per-Bounded-Context Ubiquitous Language artifact (here, the Claims context's), the plugin glossary is not edited per product, and the drift hook reads both (decision D047-9; Wave 2 findings W2-37).
3. It limits the ban to the Claims context and keeps Reinsurance's "Loss": since the Ubiquitous Language holds only inside its Bounded Context, Reinsurance's aggregated "Loss" is a different concept in another context (a homonym across the boundary), so a product-wide or plugin-wide ban of "Loss" would wrongly flag it (strategic-design supplement, Core Concepts: "ubiquitous only inside its Bounded Context"; learning-ddd-khononov: a Bounded Context boundary is where a term can mean something different).
Fail if any of the 3 is missing.
