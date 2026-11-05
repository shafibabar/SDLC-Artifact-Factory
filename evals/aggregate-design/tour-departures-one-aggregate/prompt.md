---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Trailmark**, a booking platform for a small-group walking-tour operator. We're on the **standard** profile. The **Tour Booking** Bounded Context is Core, and the Design phase is where we are now.

How the business works: a **Tour** (for example "Dolomites Hut-to-Hut, 7 days") has an itinerary and a price. Each Tour runs as many dated **Departures** a season (about 30 per tour), and each Departure has 12 seats and one guide. A **Booking** is one party of travellers on one Departure, with named travellers and a payment status. Around 40 sales agents plus the public website take bookings, and when a new season opens, the popular tours get hundreds of booking attempts in the first hour.

The rules the business gave us:
1. A Departure must never sell more seats than it has. There is no 13th seat in the minibus or the mountain hut.
2. When a Tour's itinerary text is edited, all its future Departures should show the new text.
3. The Tour page shows the total seats sold across all its Departures this season.
4. If a Booking's balance isn't paid 30 days before departure, the Booking is released and its seats go back on sale (a nightly job checks this).
5. A Booking's traveller count always equals the number of named travellers on it.

The design agent's draft says: "**Tour** is the Aggregate Root. It contains all its Departures, and each Departure contains its Bookings. A Tour clearly has its Departures and Bookings, so one Aggregate keeps everything consistent and is the safest choice."

A colleague suggests the opposite: "Make Tour, Departure and Booking three separate Aggregates. When a Booking is created, count the existing Bookings for that Departure, and if there's room, save the new Booking."

Tell me which Aggregates you would draw, which of the five rules each one enforces (and how the others are handled), and what is wrong with each draft, if anything. Use this plugin's aggregate-design skill, and give me the answer in your reply, not in a file.
