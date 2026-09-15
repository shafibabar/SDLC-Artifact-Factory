# Chunk 53: Domain-modeling cluster refactor — 8 skills rebuilt under skill-authoring-standards (GitHub issue #521, sub-issues #522–#529)

**Status:** complete

**Completed:** 2026-07-31

**Deliverables:**
- All 8 domain-modeling skills rebuilt to v2.0.0: domain-event-catalog (330→170 lines), bounded-context-mapping (250→155), context-map-patterns (256→130), command-catalog (261→149), cqrs-pattern (248→187), read-model-design (237→117), event-schema-design (223→187), domain-storytelling (242→206). All bodies at or near the ≤200-line threshold.
- 27 new references/ files: domain-event-catalog (event-format.md, outbox-and-cdc.md, versioning-and-retention.md, catalog-template.md), bounded-context-mapping (bc-discovery-guide.md, bc-definition-artifact.md, context-map-template.md, service-decomposition.md), context-map-patterns (integration-patterns-catalogue.md covering all 8 Evans/Vernon patterns, pattern-selection-guide.md, worked-example.md), command-catalog (command-format.md, validation-patterns.md, command-aggregate-mapping.md, catalog-template.md), cqrs-pattern (cqrs-variants.md, projection-patterns.md, go-implementation.md), read-model-design (read-model-format.md, denormalization-patterns.md, consistency-patterns.md, go-implementation.md), event-schema-design (cloudevents-format.md, schema-versioning.md, schema-registry.md, go-event-structs.md), domain-storytelling (notation-guide.md, facilitation-guide.md, worked-examples.md).
- 8 contract tests added — all probe facts that exist ONLY in references/ (grep-verified against body before writing). Research base: Evans, Vernon, Khononov DDD books; Newman microservices; Kleppmann DDIA. 96 of 148 skills now have contract tests (up from 88). 45 files changed, 8,504 insertions. All sub-issues #522–#529 closed, parent #521 closed.
