---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the lead architect for **Gridwell**, a platform for an operator running public EV charging stations in several countries. We're on the **enterprise** profile. We've done the Big Picture, and we've done Process Modelling for the **charging session** flow (driver starts a session at a connector, energy is metered, the session stops, the tariff is applied, an invoice is issued). We haven't modelled the **roaming** flow yet (drivers from partner networks charging on our stations and being settled with their home network).

We're now in the Software Design session and the team has agreed a simple rule: **one Aggregate per Bounded Context**, so everything inside a context stays consistent. For the Charging context that gives a single `ChargingSession` aggregate that holds the station, all its connectors, the live session, the meter readings, the applied tariff and the invoice. Every change goes through that one aggregate in one transaction.

Please:
1. confirm this design and write out the aggregate's fields and rules;
2. do the same for roaming while you're at it: one `RoamingSettlement` aggregate for the Roaming context;
3. give us the Go structs for both so the backend team can start.

Using this plugin's event-storming-facilitation skill, give me your answer in your reply, not in a file.
