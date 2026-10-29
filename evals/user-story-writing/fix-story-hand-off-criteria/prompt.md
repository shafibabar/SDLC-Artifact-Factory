---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're in Ideate on the **standard** profile for **Tallyhouse**, expense-claim software for small charities. Approved so far:

- **Epic list (ideate/epics.md):** EPIC-3 "Finance officers close the month without re-keying claims" — traces to deliverable SOL-2, job J-2 "close the books every month on time" → job story JS-2.1 "When I close the month, I want every approved claim in the accounts in one go, so I'm not re-keying them on the last day", UR-4, KR-1.2. Provisional priority: high.
- **FRD (ideate/requirements.md):** UR-4 "A finance officer must be able to get approved claims into the accounting package": FR-4.1 list approved claims missing a receipt; FR-4.2 export the month's approved claims in the accounting package's import format. BR-7: claims over £250 need a second approver before they count as approved.
- **Personas:** P-1 claimant (volunteer or staff), P-2 finance officer.

Here's my draft for the backlog:

"US-12: As a user, I want the system to export a CSV so that I can export the data. Priority: Must."

Please make US-12 ready for the backlog using this plugin's user-story-writing skill: fix the story, add its full Given/When/Then acceptance criteria underneath it, and keep it as a Must. Reply in the chat, not to a file.
