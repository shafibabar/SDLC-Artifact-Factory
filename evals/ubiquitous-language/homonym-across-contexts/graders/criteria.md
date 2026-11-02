---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not pick one product-wide definition of "Booking". It says the Ubiquitous Language is ubiquitous only inside its Bounded Context, so Reservations and Billing each keep their own definition of the word, and that when one term has to mean two things the fix is two contexts with two definitions, not one broader or "winning" definition (strategic-design supplement, Core Concepts: Evans Ch. 2 and Ch. 14, Khononov Ch. 2–3).
2. It treats "Booking" as a homonym at the boundary between the two contexts, not as a synonym to ban. It explains (in its own words) that a synonym ban applies when two words mean the same thing inside one context, and here one word means two different things in two contexts, so neither context is told to stop using its word (Wave 2 findings, ubiquitous-language eval idea (a) and example 2; strategic-design supplement on "no synonyms" inside a context).
3. It names the translation at the boundary: how a Reservations Booking becomes or relates to the Billing concept (for example, when the boat arrives the reserved Booking gives rise to Billing's stay record, with a stated mapping of what carries over), and says this translation belongs on the Context Map relationship between the two contexts, for example an Anticorruption Layer or a published exchange (learning-ddd-khononov: a Bounded Context boundary is a linguistic boundary where translation becomes necessary; strategic-design supplement, Context Map patterns).
4. It records each context's definition in the product's own per-Bounded-Context Ubiquitous Language (one entry per context, with the other context's meaning noted as a homonym), not as a single global entry in the plugin's own `glossary-management` vocabulary (decision D047-9; Wave 2 findings W2-37).
Fail if any of the 4 is missing.
