---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not produce a separate MoSCoW file (`ideate/moscow.md`): it says that at the lean profile there is no MoSCoW artifact, and settles Release 1 instead in a short Must / Won't-this-time block that closes the user story backlog (`ideate/user-stories.md`).
2. It does not compute a Must share of capacity: it assigns no hours, person-weeks or points to the stories and does not report a percentage against a 60% ceiling. It says (briefly is fine) that the 60% rule is not used, for example because there are no effort estimates.
3. The Musts are the end-to-end journey (US-1, US-2 and US-3) and NOT every story of the two high epics: at least US-4 (the reminder) is not a Must, for a stated reason that is a workaround (for example volunteers can check their shifts, or the coordinator can phone them), and the response does not treat a story as a Must just because its epic is high.
4. At least one story (for example US-6 or US-7, or US-5) is recorded as Won't this time with a reason (often a workaround) and a point at which to look at it again (a release, a date or a trigger).
Fail if any of the four is missing.
