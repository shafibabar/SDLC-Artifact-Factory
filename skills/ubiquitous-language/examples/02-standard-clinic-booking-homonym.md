# Example 2 — Standard: a homonym at a boundary, not a synonym to ban

Self-contained. **Bookwell** is a booking and billing SaaS for physiotherapy clinics, at the **standard** profile. The Big Picture Event Storming (agent-run, then reviewed with the product owner) gave two Bounded Contexts: **Scheduling** and **Billing**. Both say "Appointment".

## Input

> **User:** "Scheduling and Billing both say Appointment and the devs keep arguing. Pick the right definition for the whole product, ban the other one, and add it to the glossary."

## Working it

- **Same word, same meaning?** In Scheduling, an Appointment is a time slot with a clinician, held for a patient, and it can be moved or cancelled until it starts. In Billing, an Appointment is the treatment that actually happened, with its duration, the treatments given and the insurer to charge. It never moves, because it records the past. The rules and lifecycles differ. That is a **homonym**, not a synonym.
- **One global definition fails.** "A patient's session with a clinician" fits both and says nothing. It loses "can be moved" in Scheduling and "is fixed once recorded" in Billing.
- **No ban, on either side.** Banning "Appointment" in Billing would treat a homonym as a synonym. The clinic's billing staff say "appointment" too, so they would be banned from their own word. Each context keeps "Appointment" with its own meaning, and each document records the other meaning as a homonym. The argument ends when both teams see that the word means two things, which is why there are two contexts.
- **Name the translation.** Scheduling publishes `AppointmentAttended`. Billing's Anti-Corruption Layer turns it into a *Billing* Appointment. It carries over the patient, the clinician and the actual start and end, and it drops the slot and room, which Billing has no word for. That relationship goes on the Context Map (`context-map-patterns`).
- **The real synonym** is inside Billing: invoices and code say "visit" for the same thing. That one *is* banned, in Billing only.
- **Where it's recorded:** each context's own `ubiquitous-language.md`. The plugin glossary (`glossary-management`) is the plugin's vocabulary and isn't edited for one product.

## Output — the reply

> I wouldn't pick one. In Scheduling an Appointment is a slot that can still move. In Billing it's a treatment that happened and never changes. Those are two concepts, and the word meaning different things on each side is exactly why Scheduling and Billing are two contexts. So both keep "Appointment", each with its own definition in its own language document, and each notes the other meaning as a homonym. Nothing goes into the plugin glossary. The link between them is now explicit: when Scheduling records `AppointmentAttended`, Billing's Anti-Corruption Layer creates a Billing Appointment from it, and I've listed what carries over. The one real duplicate is "visit" inside Billing, which means the same as Billing's Appointment, so that word is banned there.

**`artifacts/bookwell/design/scheduling/ubiquitous-language.md`** (extract):

```markdown
## Terms

| Term | Type | Meaning in this context | Rules that always hold | Behaviour | Source |
|---|---|---|---|---|---|
| Appointment | Aggregate Root | A time slot with one Clinician, held for one Patient | Can be moved or cancelled only before it starts; never overlaps another of the Clinician's Appointments | `AppointmentBooked`, `AppointmentMoved`, `AppointmentAttended` | design/event-storming-big-picture.md |

### Appointment: example and counter-example

- **Is:** Tues 10:00–10:45, Clinician Okafor, Patient R. Hale, Room 2.
- **Is not:** the 40-minute treatment Ms Hale actually received; that is Billing's Appointment.

## Key Scenarios

    Scenario: An Appointment can't be moved once it has started
      Given an Appointment for Patient R. Hale that started at 10:00
      When the receptionist moves it to 11:00
      Then the move is refused

## Homonyms at the Boundary

| Term | Meaning here | Other context | Meaning there | Translation (Context Map relationship) |
|---|---|---|---|---|
| Appointment | A held slot that can move | Billing | The treatment that happened, to be charged | Billing's ACL creates a Billing Appointment from `AppointmentAttended` |
```

**`artifacts/bookwell/design/billing/ubiquitous-language.md`** (extract):

```markdown
| Term | Type | Meaning in this context | Rules that always hold | Behaviour | Source |
|---|---|---|---|---|---|
| Appointment | Aggregate Root | A treatment a Patient actually received, to be charged to them or their Insurer | Fixed once recorded; corrected only by a Credit Note | `AppointmentRecorded`, `AppointmentInvoiced` | design/event-storming-big-picture.md |

## Banned Synonyms

| Banned | Use instead | Renamed in (code · API · events · tests · docs) |
|---|---|---|
| visit | Appointment | ✔ code · ✔ API · ✔ events · ✔ tests · ✔ docs (renamed before the first build) |

## Homonyms at the Boundary

| Term | Meaning here | Other context | Meaning there | Translation (Context Map relationship) |
|---|---|---|---|---|
| Appointment | The treatment that happened | Scheduling | A held slot that can move | This context's ACL, from `AppointmentAttended` |
```

## Why this is right

- The global definition was refused, and the reason is given in rules and lifecycle, not taste.
- Neither context was told to stop using its word. The homonym is recorded in both documents with the translation named, including what carries over and what is dropped.
- The only ban is a true synonym inside one context ("visit" in Billing). The drift hook flags "visit" anywhere in Bookwell, because "visit" is canonical in no context. It never flags "Appointment".
