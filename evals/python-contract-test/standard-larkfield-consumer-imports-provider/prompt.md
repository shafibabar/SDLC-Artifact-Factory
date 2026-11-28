---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Larkfield**, a clinic appointment-booking product on the **standard** profile. Python (FastAPI) services in separate repositories: `bookings` owns `GET /appointments/{id}`, and `reminders` calls it with an httpx client. The API description for `bookings` is a hand-written `openapi.yaml`. Here is how the contract tests are set up today; please tell me what to change:

1. The consumer test in the `reminders` repository installs the `bookings` package, imports its FastAPI `app` and calls it in-process, so we test against the real thing.
2. The CI job runs `pytest -m contract || [ $? -eq 5 ]`. It is green in two seconds with "0 selected, 41 deselected"; exit code 5 is allowed because nothing carries the marker yet.
3. Response bodies are checked with `jsonschema.validate(body, schema)`. The schema says `id` has `format: uuid` and `starts_at` has `format: date-time`, so that already proves both.
4. The provider test in `bookings` validates responses against the description FastAPI generates at `/openapi.json`, since that one is always up to date.
5. Each pull request runs `oasdiff breaking --fail-on ERR` against the deployed description. The next pull request removes the optional response field `notes`; being optional, it should go straight through.

Use this plugin's python-contract-test skill, and answer in your reply, not in a file. Keep it short: at most 350 words, a line or two per point, with a brief snippet only where it helps.
