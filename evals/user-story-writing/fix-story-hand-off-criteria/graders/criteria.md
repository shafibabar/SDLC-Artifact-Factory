---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. The rewritten story names a specific persona or role (the finance officer, P-2) instead of "a user", states something the user does rather than the system, and has a benefit naming a real change for the finance officer (for example not re-keying claims, or closing the month on time) rather than restating the export.
2. It traces the story by ID to EPIC-3, to UR-4 (or FR-4.2) and to the job story JS-2.1.
3. It does not keep "Must": it gives a provisional priority (for example high) and says the final Must / Should / Could / Won't is set later by MoSCoW prioritisation.
4. It does not write the story's Given/When/Then acceptance criteria now: it explains they are drafted later (from the example map, by the acceptance-criteria step) and offers instead at most a concrete example and/or the rules and questions (such as BR-7 or claims missing a receipt) to take into that step.
Fail if any of the four is missing.
