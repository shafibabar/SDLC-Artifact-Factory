# Checklist: Component Diagram

Resource for `component-diagram`. Run after `./scripts/validate-component-diagram.sh` is clean; the script checks structure, this list checks judgement.

## Draw or skip
- [ ] Every service in the container diagram is accounted for: a diagram, or one line saying the default skeleton applies.
- [ ] Each drawn service names its departures from the default; a diagram with no departure should be a one-line skip instead.
- [ ] Lean: no component diagrams.

## Components
- [ ] Exactly one container boundary; nothing inside it is another container.
- [ ] Each box is a grouping behind an interface (a package or module), not a struct, class, function or query.
- [ ] Each box has name, type and technology, one-sentence responsibility; no responsibility joins two duties with "and".
- [ ] Names in the Ubiquitous Language.

## Arrows
- [ ] Every arrow labelled and pointing inward; no two-way arrows; no cycles.
- [ ] Ports declared in the domain; adapters implement them.
- [ ] No entry point reaches the database or an external system directly.
- [ ] Protocols only on arrows leaving the boundary.
- [ ] No step numbers or runtime order (that is a dynamic diagram).

## Package
- [ ] ASCII picture and key first; Mermaid only as an optional copy.
- [ ] Container context, element catalog (components and relationships), Dependency Rule statement.
- [ ] A named fitness function that fails the build on a forbidden import.
- [ ] Variability from the deployment view and multi-tenancy-design; no assumed per-tenant stamp.
- [ ] Rationale for each departure; cross-cutting reasoning raised as an ADR.
