# Pattern Catalogue

Each relationship pattern in depth: what it is, where it comes from, when it fits and doesn't, what it obliges each side to, and how it reads when one agent builds every internal context. The detail behind `SKILL.md` § 2. Grounded in Evans (*Domain-Driven Design*, Ch. 14), Vernon (*Implementing Domain-Driven Design*, Ch. 3) and Khononov (*Learning Domain-Driven Design*, Ch. 4), as summarised in `research/domain-driven-design/strategic-design-supplement.md`. Stack-neutral (D047-10): how a translator or a contract test is coded is `integration-design`, `go-contract-test` and the other implementation skills.

## Cooperation group

### Partnership
- **Is:** two teams whose contexts succeed or fail together plan their changes jointly; neither is simply upstream.
- **Source:** not in the 2003 book; Vernon (IDDD Ch. 3) and Evans's later *DDD Reference*.
- **Fits:** two teams that communicate well and work in step, with a shared delivery that neither can ship alone.
- **Doesn't fit:** one team (or one agent): there is no second party. A power imbalance (use Customer/Supplier or Conformist). Teams that rarely talk.
- **Obliges:** joint planning; both sides review changes to the shared interface.
- **House guidance:** treat it as a phase with a stated exit (to Customer/Supplier or Shared Kernel), not a permanent arrangement. This is the plugin's rule, not the books'.

### Shared Kernel
- **Is:** two contexts share an explicit, small part of the model and change it only by agreement, with shared tests.
- **Source:** Evans 2003.
- **Fits:** when duplicating the model costs more than coordinating changes to it (Khononov). Natural when *one* team owns both contexts, which is the usual case for internal contexts in an agent-built product.
- **Doesn't fit:** a growing set of shared types; no agreed list of members; three or more contexts needing the same thing (prefer a Published Language).
- **Obliges:** a written list of the kernel's members; shared tests both sides run; no change without both sides.
- **Related vocabulary:** Ford's data-ownership patterns (common or joint ownership) are the data-layer analogue (*Software Architecture: The Hard Parts*), not a second governance model.

## Customer–supplier group

### Customer/Supplier
- **Is:** a clear upstream (supplier) and downstream (customer); the supplier commits to the customer's needs.
- **Source:** Evans 2003.
- **Fits:** two parties who can negotiate, with one or a few downstreams.
- **Obliges:** **consumer-driven contract tests**. Evans has the downstream write automated acceptance tests that run in the upstream's suite; Newman and Cruz & Prescott describe the modern form: the consumer records what it reads, and the provider verifies it in its own pipeline before deploying.
- **Moves to:** Open Host Service when private per-consumer contracts become unmanageable (several consumers).

### Conformist
- **Is:** the downstream takes the upstream model as it is.
- **Source:** Evans 2003, who counts it as a legitimate, cheap choice, not a failure.
- **Fits:** the upstream model is good enough, the downstream isn't Core, and the upstream won't accommodate (a vendor, a large platform).
- **Doesn't fit:** adopting the upstream's terms would change a meaning, import a concept the downstream lacks, or break an invariant (`./selection-guide.md` § 3); or the downstream is Core.
- **Obliges:** nothing from the upstream; the downstream notes the upstream's version and release pace to plan for drift.

### Anticorruption Layer
- **Is:** the downstream translates the upstream model into its own language, so the foreign model never reaches its core. Built from facades, adapters and translators (Evans).
- **Source:** Evans 2003.
- **Fits** (Khononov): the downstream is Core; the upstream is messy or legacy; the upstream contract changes often.
- **Doesn't fit:** nothing to translate. A layer that copies fields one-to-one is Conformist with extra code (a pass-through translator).
- **Obliges:** the downstream owns and maintains the translation; the upstream need not know it exists. To a vendor, integration tests against the vendor's API, since a vendor won't run your contract tests.

### Open Host Service
- **Is:** the upstream publishes one protocol for all consumers, instead of a translator per consumer.
- **Source:** Evans 2003.
- **Fits:** several consumers. It separates the upstream's internal model from its public one, and can serve several versions at once (Khononov).
- **Obliges:** versioned protocol discipline for every consumer: versioning, deprecation windows, change notice (`event-schema-design`, `api-contract-design`). Contract tests for the *named* consumers who agreed to them; they are pair-specific (Cruz & Prescott), not owed to every consumer.
- **Watch for:** the union-of-wishes protocol that adds every consumer's special request.

### Published Language
- **Is:** a documented shared exchange language: the event or payload schema.
- **Source:** Evans 2003; Khononov folds it into Open Host Service rather than listing it separately.
- **Pairs with:** Open Host Service. How strict the contract is (typed and strict, or loose with tolerant readers) is a separate choice (Ford): strict contracts catch errors earlier but couple more; passing a large shared structure when a consumer reads a few fields is *stamp coupling*.

## No integration

### Separate Ways
- **Is:** no integration.
- **Source:** Evans 2003. Khononov adds two reasons: the teams can't communicate, or the capability is Generic and each side can get its own.
- **Fits:** integrating would cost more than it returns.
- **Check first:** the Event Storming wall shows no event one side needs from the other. A false Separate Ways creates duplication and drift.

## Legacy

### Big Ball of Mud
- **Is:** a region with no coherent model.
- **Source:** Foote and Yoder's 1997 term; added to the map vocabulary by Vernon and the *DDD Reference*.
- **On the map:** one boundary round it; don't extend it; new contexts reach it through one Anticorruption Layer. Moving pieces out of it is `subdomain-distillation`'s legacy guidance (the Strangler Fig).
