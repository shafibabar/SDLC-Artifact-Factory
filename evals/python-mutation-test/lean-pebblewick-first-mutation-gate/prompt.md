---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pebblewick**, a seed-library loan tracker for community libraries, on the **lean** profile. The backend is Python with pytest. A developer proposes this mutation-testing setup. Please confirm or correct each point:

1. "We're lean, so mutation testing is optional. If we add it, we only mutate `pebblewick/domain/`; the services, adapters and API code are left out."
2. CI installs mutmut with `pip install mutmut`, so we always get the newest release.
3. The configuration in `pyproject.toml`:

   ```toml
   [tool.mutmut]
   paths_to_mutate = "pebblewick/domain/"
   tests_dir = "tests/"
   runner = "python -m pytest -x"
   ```

4. The CI step runs `mutmut run`; if it exits 0, the job passes.
5. We set the gate at a 60% mutation score, which is the usual industry figure, and raise it later.

Use this plugin's python-mutation-test skill. Answer in your reply, not in a file, and keep it under 300 words: one direct answer per point, with only the few lines of configuration needed.
