---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Brindlemoor**, a volunteer shift scheduler for food banks, on the **standard** profile, in Python with mutmut. The release run planted 500 mutants: 440 killed, 12 timed out, 6 were caught by the type checker, and 42 survived. The developer says 12 of the survivors are equivalent. Proposals:

1. Mark those 12 equivalent mutants in the code with `# pragma: no mutate  # equivalent: rounding already applied upstream`, so they drop out and the reason sits next to the code.
2. Count the 12 timeouts and the 6 type-checker catches as killed straight away; the tool treats timeouts as killed too.
3. Report the mutmut badge figure as our mutation result, since it is the tool's own score.
4. After the clean-up, if the result is 93%, can I waive the rest and release? And if it had come out at 89%?
5. Our `pyproject.toml` has `addopts = "--cov=brindlemoor --cov-fail-under=100"` for the unit tests, and the mutmut runs now fail oddly. The developer wants to lower the coverage floor to fix it.

Use this plugin's python-mutation-test skill. Answer in your reply, not in a file, and keep it under 300 words: one direct answer per point, with only the few lines of configuration needed.
