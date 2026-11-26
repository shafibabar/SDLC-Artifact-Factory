---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Larkspool**, an appointment-reminder product for small clinics, on the **lean** profile. The backend is Python with pytest and pytest-asyncio, all asyncio, with a current pytest. Our engineering notes propose this test setup. Please confirm it or correct it:

1. "An async test that never gets awaited is silently reported as passed. So we add a canary: an async test that always fails, kept in CI. If CI ever goes green, we know async tests are not running."
2. We install whatever pytest and pytest-asyncio versions are newest on each build, and leave the asyncio plugin on its defaults.
3. We have a session-scoped async fixture (an in-memory broker shared by tests) and get event-loop errors. Fix: override the `event_loop` fixture with a session-scoped one.
4. We keep `--strict-markers` in `pyproject.toml`, and a developer wants to add a `pytest.ini` that only registers a new `slow` marker.
5. A job that runs `pytest -m slow` currently selects nothing, so we will append `|| [ $? -eq 5 ]` to keep it green.

Use this plugin's python-unit-test skill. Answer in your reply, not in a file, and keep it short: one direct answer per point, with only the few lines of configuration or code needed.
