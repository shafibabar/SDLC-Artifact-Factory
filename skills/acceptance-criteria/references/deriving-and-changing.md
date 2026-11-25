# From the Map to the Criteria, and Changing Them Later

Self-contained. Used when turning a story's ready example map (`ideate/example-maps/US-n.md`: rules `R1`, examples `R1.E1`, questions `Q-1`) into its criteria (`ideate/acceptance-criteria/US-n.md`, IDs `AC-US-n.m`), and when agreed criteria are questioned.

## Why examples come first

Criteria are derived from concrete worked examples, and the rule is drawn out of them, not decided and then illustrated (Ken Pugh's Acceptance Test-Driven Development; Gojko Adzic, *Specification by Example*). The other way round gives rules nobody has tried against a hard case. A story with no worked example is not understood well enough to specify. In Cohn's Three Cs (after Ron Jeffries) the map records the Conversation and the criteria are the Confirmation.

## Card to criterion

| On the map | In the criteria file |
|---|---|
| Rule `R1` | At least one criterion cites it; none is dropped |
| Happy example | Usually a criterion under Happy Path |
| Negative example | Usually a criterion under Error / Negative Scenarios |
| Edge example | A criterion under Boundary / Edge Cases |
| Several examples proving the same behaviour | One criterion citing them all |
| An example that proves nothing the others do not | Left uncited; the script warns so you confirm |
| Question answered | Already folded into the rules; cite the rule |
| Question open | Nothing: the map is not ready |
| Question moved to another story | An out-of-scope line naming that story |

Keep the map's names, values and outcomes. Rewording into business-language Given/When/Then is your job; changing what happens is not.

## Fit criteria, business rules, targets

Read the story's `Traces to` and `Rules` lines. Each fit criterion of a functional requirement the story carries, and each cited BR-n, is reflected in at least one criterion and listed under Derived From. At lean there is no requirements document: the rules in the backlog's header apply, and these criteria act as the story's fit criteria. If a fit criterion or rule has no example on the map, or the map contradicts it, put a question on the map (`example-mapping`) and wait; do not write the criterion from the requirement alone.

## Agent-run honesty

When one agent drafts them, the file says so and claims no workshop, session or agreement. The Three Amigos perspectives (business, development, testing) belong to the map, and one agent playing them is not three people agreeing. If people did hold a session, record `run: workshop` and who took part.

## Changing agreed criteria

An agreed criterion is a contract, changed only the way it was made (Pugh). This covers "the code does something else", "soften it so the test passes" and "just add one more".

1. State the criterion by ID and what would change.
2. Record it as a question on the story's example map; only the product owner answers it.
3. Update the map, then the criteria. A reworded criterion keeps its ID; a removed ID is not reused; a new one takes the next number.
4. Bump `version`. Editing an approved artifact returns it to draft until the product owner re-approves it.
5. Name what depends on the changed IDs: feature files, UAT scenarios, the test strategy.

Criteria written after the code, describing what it does, turn every defect into a requirement. For a feature already built, map it first and ask whether each observed behaviour is intended.

## Handing off

| Reader | Takes |
|---|---|
| `bdd-feature-file` (test-strategist) | Every criterion ID, both formats, the out-of-scope list (it stops tests growing without limit) and the map path |
| `test-pyramid` | The IDs, mapped to a test layer |
| `uat-plan`, `uat-scenario` | The IDs of Must Have stories; UAT scenarios trace to `AC-US-n.m` and run after deployment |

Acceptance criteria and feature files are agreed before coding; UAT is a later, human check of the deployed release. They are not the same activity.
