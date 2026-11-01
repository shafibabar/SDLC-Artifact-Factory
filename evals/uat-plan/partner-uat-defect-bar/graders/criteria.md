---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. Scripted UAT scope is the Must stories (US-1 to US-4) only. It declines to put every Should story (US-5, US-6, US-7) into UAT scope, with a reason (for example: UAT confirms what the release promised, and the Musts are that promise; the window is three days). Mentioning that Shoulds can be looked at in an exploratory session or later is fine; scripting them all into UAT is not.
2. It refuses to leave the pass threshold and defect bar until after the results: the plan sets them now (for example 100% of Must scenarios passing) and says they are agreed by the people who will accept (the product owner and the head of engineering) before execution starts, and that changing them after results arrive must be recorded as a decision, not decided quietly on day 3.
3. It refuses a full sign-off with an open High defect. It states that an open Critical defect means no sign-off, and that an open High allows only a conditional sign-off, and only with a fix plan (an owner, a target date, a workaround and how the fix will be re-tested). It points to acceptance-sign-off as where this rule lives, or states it as the single shared rule, rather than inventing a different one.
4. It refuses to mark a scenario that could not run as passed: a scenario that cannot run because the data is missing is recorded as Blocked (or Not run) with a reason, and it does not count as a pass for the exit criteria until it has been run.
Fail if any of the 4 is missing.
