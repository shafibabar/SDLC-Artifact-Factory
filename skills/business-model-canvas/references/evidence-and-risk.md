# Evidence Status, Risk Ranking and Tests

Self-contained. Read this when marking a block's evidence status, ranking which guesses to test, writing the test for a top risk, or deciding whether a Lean Canvas has earned the move to a full canvas. Sources: Blank, *The Four Steps to the Epiphany* (every block a hypothesis Customer Development tests); Osterwalder et al., *Value Proposition Design* (evidence strength, test and learning records); Maurya, *Running Lean* (product / customer / market risk, falsifiable experiments, fit milestones).

The plugin cannot talk to customers. The agent drafts the tests; the user (or a design-partner programme, `beta-program-design`) runs them; the canvas records what happened.

---

## Evidence status: one per block

| Status | Means | Example evidence |
|---|---|---|
| `hypothesis` | A guess, however reasonable | Team belief, desk research, an analogy, the vision |
| `tested` | An experiment ran and its result is recorded (it may have supported or refuted the guess) | Problem interviews ranked the problem; a landing page was shown; a price was quoted and reactions recorded |
| `validated` | Customers **acted**, repeatedly | Payment, a signed letter of intent or pilot, retained weekly use, referrals |

What people *say* is weaker than what they *do*. Stated willingness to pay, "I'd use that", and interview enthusiasm are `tested` at best, never `validated`. The block's status is set by its least-proven entry. Write it on its own line in each block: `Evidence: hypothesis`.

### Unknown versus TBD

| Entry | Lean Canvas | Full canvas |
|---|---|---|
| `unknown: tested by <experiment>` | **Passes.** A blank that names its test is information (Maurya) | Fails: the full canvas is chosen only once there is evidence to fill it; go back to the Lean Canvas or fill it |
| `TBD`, `?`, empty, "to be decided" | **Fails** | **Fails** |
| Filler to avoid a blank ("first-mover advantage", "great team") | **Fails**: it hides the risk | **Fails** |

## Risk ranking

1. Tag each block that is not `validated` with its risk type: **product** (Problem, Solution, UVP, Key Metrics), **customer** (Segments, Channels, Relationships) or **market** (Revenue, Cost, Unfair Advantage, Partnerships, Resources).
2. Score each on two questions: how likely is this guess wrong (weaker evidence = more likely), and how much of the model breaks if it is? Test first the guesses that would kill the idea.
3. Rank. Early on, product risk usually comes first: a problem nobody has makes every other block moot. When there are several segments (several Lean Canvases), rank the canvases too: a segment with a severe, recognised problem, reachable through a channel you control and willing to pay, usually ranks ahead of a larger, vaguer one.
4. Keep the top two at lean, the top three at standard and enterprise.

## The test for each top risk

Write each as a falsifiable hypothesis, decided in advance:

```
Risk:        <block> — <product | customer | market>
We believe:  <the guess, specific>
Test:        <the cheapest experiment that could show it wrong>
Measure:     <the behaviour observed, as a rate or count>
Pass if:     <success criterion, set before the test runs>
Time box:    <by when>
```

Prefer tests that observe behaviour (sign-up, deposit, pilot signature, repeat use) over opinion. When the result lands, record it (we believed / we observed / we learned / therefore we will) and update the block's status and the canvas, re-checking every block the change touches.

## Fit milestones and the move to a full canvas

| Milestone | Exit criteria (write them into the Lean Canvas as checkboxes) |
|---|---|
| **Problem/Solution Fit** | The Early Adopter profile is named; a must-have problem is ranked high consistently in problem interviews; existing alternatives are known; a solution demo and a price are accepted by early adopters (solution interviews) |
| **Product/Market Fit** | Retention and demand measured in cohorts (Key Metrics), not stated |
| **Scale** | The current bottleneck in the AARRR funnel is known and is the focus |

Use the Lean Canvas until Problem/Solution Fit's criteria are met. Then write the full canvas: partners, activities, resources and relationships can now be named from operating evidence. The Lean Canvas is marked superseded and names the criteria that triggered the move.
