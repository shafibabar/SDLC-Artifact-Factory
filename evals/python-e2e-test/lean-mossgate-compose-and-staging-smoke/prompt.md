---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Mossgate**, a booking tool for allotment plots, on the **lean** profile. It is one Python service (FastAPI, pytest) on PostgreSQL, deployed with Helm. The service has a public HTTP API that can create plots and bookings. I want its end-to-end tests set up like this:

1. We are lean, so no Kubernetes for tests: bring the service and PostgreSQL up with Docker Compose and run the journeys against that.
2. Run the journeys inside `make ci`, so every pull request runs them.
3. After each deploy to our shared staging environment, run a smoke check there marked `@pytest.mark.smoke`: it POSTs a booking, reads it back, then DELETEs it.
4. Seed the reference plots with a direct `INSERT ... ON CONFLICT (id) DO UPDATE` against the database, staging included, so the seed can be re-run safely.

Please tell me how the end-to-end tests should be set up for Mossgate and what you would change in my four points. Use this plugin's python-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 300 words, with a brief snippet only where it helps.
