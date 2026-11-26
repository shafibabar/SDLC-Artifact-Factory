---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Quillfern**, a grant-tracking product for charities, on the **standard** profile, written in Python. Today the full test run shows **line coverage 94%** and **branch coverage 88%**. We release Friday. A developer proposes:

1. Put `--cov=quillfern --cov-fail-under=80` in pytest `addopts` so every run, including running one test file, enforces the floor.
2. I waive both remaining gaps in one go, since the combined figure is above 90%.
3. Add `# pragma: no cover` to the PostgreSQL repository classes without further discussion, because unit tests don't reach them. coverage.py already skips `...` bodies and `if TYPE_CHECKING:` blocks by default, so exclusions are normal.
4. Once we reach 100%, the release report can say every path through the code has been tested. Our pricing code has several one-line `a if x else b` expressions and loops that may run zero times.

What is the correct answer on each?

Use this plugin's python-unit-test skill. Answer in your reply, not in a file, and keep it short: one direct answer per point, with only the few lines of configuration or code needed.
