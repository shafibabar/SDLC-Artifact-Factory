---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pennywhistle**, a music-lesson scheduling product on the **standard** profile: two Python services (FastAPI, pytest) and a Redpanda broker. Our nightly end-to-end run has been green for three weeks and I want to keep it that way. This is how it works today; please review it:

1. The nightly job runs `pytest -m e2e_journey`. The journey tests themselves are decorated `@pytest.mark.e2e`. The job's wrapper treats pytest exit code 5 as success, on the reasoning that "no tests ran" is not a failure.
2. To stop flaky reds we run with `--reruns 3`, and a test that passes on any attempt counts as green. We only look at the job's exit status.
3. Tests we do not trust carry `@pytest.mark.quarantine`, which skips them. They stay that way until someone has time, and the report counts them with the passes.
4. After a lesson is booked, the test calls `time.sleep(10)` and then checks that the reminder the second service creates from the booking event exists.

Tell me what is wrong, if anything, and what each point should be instead. Use this plugin's python-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 300 words, with a brief snippet only where it helps.
