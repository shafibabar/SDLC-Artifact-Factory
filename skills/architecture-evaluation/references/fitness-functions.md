# Fitness Functions

Reference for `architecture-evaluation` step 8. Grounded in Richards and Ford (*Fundamentals of Software Architecture*, the chapter on governance and fitness functions, drawing on *Building Evolutionary Architectures*). The research gives a definition and three examples; it gives no taxonomy and no tool list, so none is added here.

## What a fitness function is

A **fitness function** is any mechanism that gives an objective, automated assessment of whether an architecture characteristic still holds. It is a governance test, not a one-time review: it runs continuously, so a decision stays true after the people who made it have moved on. A diagram and a paragraph of prose state an intention; a fitness function enforces it.

## The three examples in the research

- A test that fails the build if the domain layer imports a database driver (an import or dependency test).
- A load test that gates a deployment on a P95 latency.
- A dependency-freshness check.

## Where fitness functions come from in this evaluation

For every **hard rule** or characteristic that must stay true, ask: what objective, automated check would fail if it stopped being true? Typical sources:
- a **risk** found in the evaluation (a check that would catch the risk becoming real);
- a **sensitivity point** (a check on the value or limit that matters: pool size, queue depth, response time);
- a scenario's **response measure** (a load test or an alert threshold that measures it);
- a **dependency rule** from the diagrams (the dependency-direction rule of `component-diagram`).

## What each row records

| Field | Holds |
|---|---|
| Characteristic | the quality attribute or rule it protects |
| Rule that must stay true | the statement, in a measurable form |
| Check | the objective automated check (a test, a gate, a monitor with a threshold) |
| Where it runs | the build, a deployment gate, a scheduled job, production monitoring |
| Owner | who keeps it green and the skill that builds it (a `go-*` or `python-*` skill, `platform-engineer`) |

## This repository's own checks

The plugin already runs some checks of this kind on what it generates: a dependency or import test for the layering a component diagram states (`component-diagram`), the test-first gate on implementation files, the contract and compatibility checks for API contracts (`api-contract-design`, `grpc-contract-design`), and the SLO and burn-rate alerts the platform engineer defines. Point to the existing check when one fits; propose a new one only for a rule no check covers.

## What a fitness function is not

- Not a review meeting or a checklist run once at the Design gate.
- Not a wish ("the system should stay fast"): it names the measure and the threshold.
- Not a replacement for the evaluation: the evaluation finds the rule worth protecting; the fitness function keeps it protected.
