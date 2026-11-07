# Container Diagram Checklist

Run after `./scripts/validate-container-diagram.sh` exits clean. The script checks structure; these items need judgement.

## Decomposition
- [ ] Started from the Context Map, not from "one context, one service".
- [ ] Lean: one modular monolith, contexts as modules with their own schemas; any split names an overwhelming disintegrator.
- [ ] Standard and enterprise: every split names a disintegrator with evidence and the integrators it overrides; contexts kept together name the integrator.
- [ ] No context is split between deployables that both write its Aggregates; no deployable reaches another's database.
- [ ] A service another team runs is an external system, not a container here.
- [ ] Non-obvious splits have an ADR.

## Containers and connectors
- [ ] Every runnable unit and every datastore is a box: type, name, technology, responsibility; no Docker images as containers.
- [ ] Technology matches `sdlc-config.json` and the defaults; any deviation has an ADR.
- [ ] Persons and external systems match the system context diagram exactly; anything new was added there first.
- [ ] Every arrow points from the caller or publisher, says what flows, names the protocol and sync or async.
- [ ] With a broker, every topic's publisher and consumers are listed; the picture is not a hub that hides the pairs.
- [ ] No business rules in the broker, the gateway or the mesh.

## Gateway
- [ ] Gateway or none is decided and stated; lean says why none.
- [ ] The gateway holds routing, TLS, token validation and rate limits only; client-specific shaping is a backend-for-frontend.
- [ ] Services verify identity themselves.
- [ ] The north-south entry and the east-west mesh are both marked.

## Deployment view
- [ ] Drawn after multi-tenancy-design, showing exactly its model (or marked pending, with an open question); no assumed stamps or shared broker.
- [ ] One per environment whose shape differs; every container mapped to a node with a count.
- [ ] Regions, stamps, replicas and ports appear here and nowhere on the container picture.
- [ ] The variability guide says what changes per environment, region or tenant.

## The package
- [ ] Title, readers, question, key (types, sync and async, what an arrow means).
- [ ] ASCII primary; Mermaid only at standard or enterprise when asked, as `C4Container` / `C4Deployment`.
- [ ] Rationale explains the shape; each rule the decomposition relies on has a fitness function.
