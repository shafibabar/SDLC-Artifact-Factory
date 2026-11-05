---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Transecta**, a booking-and-reporting app for small ecological survey consultancies (the firms that check a building site for bats, newts and nesting birds before planning permission is granted). We're on the **standard** profile. This plugin's agents are building it; after launch, two freelance developers will look after it, one on the mobile app the ecologists use in the field and one on the office web portal.

Event Storming Big Picture and the subdomain classification are both done. Here is what came out of them.

**Subdomain classification (dated last week):** Survey Fieldwork and Ecological Reporting are Core; Quoting and Client Management is Supporting; Invoicing and Payments is Generic.

**What people said during Event Storming:**
- The sales coordinator: "A *survey* is a job we've quoted for a client: the scope, the price, the visit dates we've promised."
- The field ecologist: "A *survey* is me on the site at dusk, walking the transect with a bat detector. One job can need five surveys across the season. I log each sighting as a *record*: species, count, time, GPS point."
- The report writer: "A *survey* is the report we send to the planning authority. And a *record* for me is the batch we submit to the county biological records centre, not one sighting."
- Only the field app creates sightings; only the report writer can sign off a report; only sales can change the price.

**Aggregates the domain modeller has sketched so far:** Quote, Client, Survey Visit, Sighting, Survey Report, Records Submission, Invoice.

What I'd like:
1. Make each of those seven Aggregates its own Bounded Context. That keeps everything small and clean.
2. On top of that, group them into two big areas, **Mobile** and **Web**, one per developer, since we'll have two teams.

Using this plugin's bounded-context-mapping skill, give me the Bounded Contexts and a Context Map, with your reasoning, in your reply, not in a file.
