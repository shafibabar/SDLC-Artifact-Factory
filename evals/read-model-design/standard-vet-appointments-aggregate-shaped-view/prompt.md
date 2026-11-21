---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Vetpoint**, the booking and clinic-day app for a group of 14 veterinary clinics. Pet owners book appointments in our mobile app; reception and vets work from a daily screen in each clinic. We're on the **standard** profile, and this plugin's agents build and run it.

The architecture agent has already written `design/architecture/cqrs-decisions.md`. It puts the **Appointments** Bounded Context on projections (Read Models built from Domain Events), with the trigger recorded as "three screens need very different shapes of the same data, and owner-app reads outnumber bookings by more than twenty to one". The context's Aggregates are `Appointment`, `VetSchedule` (each vet's bookable slots), `Pet` and `Client` (the pet's owner).

The three screens are:
- the **clinic day sheet**: per vet, per day, each appointment with the time, pet name, species, the reason for the visit, the client's phone number and whether they have checked in;
- the owner app's **upcoming appointments**: every future appointment for all of a client's pets;
- reception's **vaccination reminders**: pets whose vaccination falls due in the next 30 days, with the client's phone number.

The team's draft read-side design says:

1. "To keep it reusable", there is one `AppointmentReadModel` that mirrors the `Appointment` Aggregate field for field (id, petId, clientId, vetId, slot, reason, status). All three screens use it and look up pet and client details separately.
2. When a client books, the `BookAppointment` command first checks the day sheet Read Model to confirm the vet's slot is still free, so we never double-book.

Please design the Read Models for the Appointments context and tell me what you'd change in the draft. Use this plugin's read-model-design skill, and give me the answer in your reply, not in a file.
