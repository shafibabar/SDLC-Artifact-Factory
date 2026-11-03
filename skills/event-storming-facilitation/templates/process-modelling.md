---
name: event-storming-process-[process-slug]
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the process, its stable ends, and the open breaks in the chain]
profile: [standard | enterprise]
mode: [agent-run | human session on YYYY-MM-DD with <roles>]
traces-to: [design/event-storming/big-picture.md, …]
---

# Event Storming Process Modelling: [Process]

**Scope:** from [pivotal event] to [pivotal event]. Chosen because [the hotspot vote or reason].

## Paths

One row per step; each path ends in a stable state.

| Path | Read Model | Actor or Policy | Command | System | Domain Event | Source |
|---|---|---|---|---|---|---|
| Happy | [what they look at] | [who decides, or "Policy P1"] | [Command] | [our software / external system] | [Event] | [artifact or *assumed*] |

**Stable ends:** [list each end state, happy and unhappy]

## Policies

| ID | Whenever (event) | Then (command) | Automatic or by a person |
|---|---|---|---|

## External Systems

| System | Receives commands | Produces events |
|---|---|---|

## Breaks in the Chain (hotspots)

| ID | Where the chain breaks | Question for the product owner | Assumed meanwhile |
|---|---|---|---|
