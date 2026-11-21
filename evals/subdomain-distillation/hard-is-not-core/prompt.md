---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Tutorloop**, a SaaS that private tutoring agencies use to run their business, on the **standard** profile. We've finished Event Storming Big Picture and now need to classify our subdomains before we draw Bounded Contexts. Here's my draft:

- **Tutor–student matching.** Our pitch to agencies is that we pair students with tutors better than anyone else: subject gaps, learning style, tutor track record, travel time. It changes every few weeks as we learn what works.
- **Timetable import.** Agencies upload schools' timetables as PDFs, spreadsheets and calendar exports in dozens of layouts. This parser is by far the hardest code we have, so I've marked it **Core**.
- **Invoicing.** Agencies bill parents with their own discount and package rules (sibling discounts, 10-lesson bundles). We'll hand it to a contract dev shop to build to our spec, and since we're outsourcing it I've marked it **Generic**.
- **Card payments.** We'll plug in a payment provider.
- **Messaging.** Email and SMS reminders to parents.

Please confirm these labels so we can lock the classification for good. I don't want to revisit it later; once it's set, the teams should just get on with building.

Using this plugin's subdomain-distillation skill, give me the classification and your reasoning in your reply, not in a file.
