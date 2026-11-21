---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Stayhound**, an app that independent dog-boarding kennels use to take bookings, on the **standard** profile. Our Big Picture Event Storming is done, and the arrow vote picked **"stay request to check-in"** as the process to model next. The kennel staff are booked solid this month, so there's nobody to run another workshop with. Please work from this extract of the Big Picture wall.

**Scope:** from the moment a dog owner asks for a stay until the dog is checked in at the kennel. Deposits are taken through **PayRail**, an external payment provider we don't control.

**Events on the wall, in timeline order:**
1. Stay Requested (dog owner, in the app)
2. Vaccination Certificate Uploaded (dog owner)
3. Stay Request Accepted (kennel manager)
4. Deposit Charged (PayRail)
5. Stay Confirmed
6. Check-in Reminder Sent (the day before)
7. Dog Checked In (front desk)

**Also on the wall:**
- A sticky saying **"Deposit Declined (PayRail)"**, placed under step 4 with nothing after it.
- A hotspot: "kennels say owners often upload certificates that expire before the stay ends".
- A note from the walkthrough: "today, when a certificate will expire before the stay ends, the front desk phones the owner and asks for a new one". We'll automate that some day, so leave the phone calls out; they aren't software.

**What I want:**
- The Process Level model of this flow. Our developers want to start coding straight after, so in the middle of each step put the aggregates (Booking, Pet, Kennel) instead of "systems". That saves us a round.
- Just the happy path for now. We'll get to the edge cases later.
- Wherever the wall has a gap, fill it in with something sensible so the diagram is complete. We don't have time for another round of questions.

Using this plugin's event-storming-facilitation skill, give me the model and your reasoning in your reply, not in a file.
