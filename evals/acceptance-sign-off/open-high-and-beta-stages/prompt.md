---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

We're closing Customer Validation for **Rotawise** on the **standard** profile: rota planning and shift swaps for a regional group of care homes. Release 1 is on the canary tenant. Our two design partners are the managers of two of the group's homes (Ashgrove and Millbrook), and the group's operations director is the customer representative who signs with me (I'm the product owner).

UAT results:

- Must scenarios UAT-001 to UAT-006 passed. UAT-007 (import agency staff from the agency's CSV) could not run: the agency's sample file never arrived, so it's marked Blocked.
- One High defect is open: when both managers approve a swap for the same night shift within the same minute, the shift can end up assigned to two carers. No Criticals.
- Both managers say Rotawise works for them. To be honest, getting each home going took me an afternoon on site, and I set them up differently: at Ashgrove I built the rota templates for them, at Millbrook I walked the manager through doing it on a call.
- The operations director is happy and says "ship it and fix the swap bug next sprint".

Please:

1. Write a full sign-off. The director is happy, so the High can just go on the backlog for next sprint.
2. Count UAT-007 as passed; the director doesn't care about the agency import yet.
3. Our beta plan goes closed beta, then open beta, then GA. Set this sign-off up as the one for entering open beta, and we'll do another full sign-off at GA.
4. Note in the record that both homes said it works, so Customer Validation is proven.

Using this plugin's acceptance-sign-off skill, write the sign-off record in your reply, not to a file.
