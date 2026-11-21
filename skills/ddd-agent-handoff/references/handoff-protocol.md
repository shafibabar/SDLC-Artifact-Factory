# Handoff Protocol

The detail behind `SKILL.md` §§ 2–5. Self-contained. Grounded in Fournier & Nowland (*Platform Engineering*: X-as-a-Service as the default interaction, collaboration as a temporary mode that returns to it; the modes originate in *Team Topologies*), summarised in `research/devops-and-delivery/platform-engineering-fournier-nowland.md`, and in Evans (*Domain-Driven Design*: refactoring toward deeper insight), summarised in `research/domain-driven-design/domain-driven-design-evans.md`.

In this plugin, agents run one after another under the product owner, who approves artifacts. A "mode" is therefore not two teams meeting; it is **when the receiving agent looks at the producer's work**: after approval (hand-over) or before it (joint review).

## 1. The two modes

| | Hand-over | Joint review |
|---|---|---|
| When the receiver reads the artifact | after the product owner approves it | as a draft, before approval |
| Flags | come back after approval; a fix returns the artifact to draft | go back and forth until none is open; then approval |
| Use | the default | a named reason (§ 2) |
| Ends | when the receiver accepts | when the artifact is stable; later hand-overs of that kind go back to hand-over |

There is no third, "facilitating" mode: an agent that needs another's standards loads that agent's skill. No agent teaches another or works on its behalf.

## 2. Choosing joint review

Use joint review when at least one is true, and write which in the record:
- **Core subdomain** (`subdomain-distillation`): the differentiating model is worth the receiver's early eye.
- **Personal or regulated data** in the artifact: a misread hand-over is a compliance risk (security-architect reviews the Aggregate's rules before approval).
- **A disputed or unclear Bounded Context boundary** touches the concern.
- **First hand-over of that kind on this product** between these two agents.

Generic subdomains bought or adopted rather than modelled need no hand-over beyond the integration contract.

**Escalate** a hand-over to joint review when the receiver raises a second flag of the same kind on the same artifact. **Step down** to hand-over when the last joint reviews of that kind closed with no flags. Record each change with its trigger, so a resumed session sees why.

## 3. Flags back

A flag is how an agent reports a defect in an artifact it does not own:

| Part | Holds |
|---|---|
| Raised by | the agent that found it |
| Artifact | its path |
| What | what is wrong or missing, and the evidence (an NFR, a story, a measurement, a contradiction with another artifact) |
| Owner | the agent that owns the artifact (the matrix) |
| Status | open → fixed (by the owner) or declined (by the owner, with the reason) |

The raiser never edits the artifact. The owner fixes it, and if the product owner had approved it, it returns to draft for re-approval (#1288). A declined flag the raiser still disputes becomes a dispute (§ 4).

## 4. Disputes

1. Both agents state the matrix row or Definition of Done they rely on.
2. Bounded Context scope: the domain-modeler decides (it owns the Context Map).
3. A product term: the context's Ubiquitous Language; the plugin's vocabulary: `glossary-management`.
4. An event: meaning to the domain-modeler, envelope and registry to the data-architect (D047-2).
5. Otherwise: record the record's status as *blocked*, with both positions, and ask the product owner. Neither agent proceeds on the disputed part.

## 5. Adding an agent mid-stage

When a concern from another matrix row appears (personal data found in a source, a regulated field), look up its owner, add a flag or a concern row naming them, and let them choose their own mode for their piece. Joining does not change the mode of the rest of the hand-over.

## 6. Resumption

| Kind | Signal | Resume by |
|---|---|---|
| **Operational pause** | the session ended for a reason unrelated to the model: a limit, a time box, an unrelated interruption | reading the open records, the artifacts produced and the open questions; continue; nothing is redone |
| **Model found wrong** | the work stopped *because* a model decision was wrong: an invariant can't hold at that boundary, two contexts are one, a classification was wrong | **not** resuming forward. Route back to the model's owner for a deliberate revision (Evans: a breakthrough reshapes the model; building on to the old one compounds the error). List every downstream artifact built on the old model for review |

Set the record's status to *paused* or *model-revision* accordingly, with the next step naming who acts. A new hand-over record is opened once the revised model is approved, citing the old record as its reason.

## 7. Scaling

- **Lean:** one record per pair per phase with the concerns table and any flags; joint review is rare (no Core-subdomain complexity usually warrants it).
- **Standard:** full records; joint review on the named reasons.
- **Enterprise:** full records; joint review is usual for regulated data and for contexts shared across regions or tenants.
