# Cold start: Fresh-Eyes Wave 3 (testing), paused 2026-11-27

Work moved to another machine and another Claude account. Everything needed is in this repository and on GitHub. `main` holds only this pointer; **no Wave 3 work is on `main`**.

## Where the work is

| What | Where |
|---|---|
| Parent issue (decisions, check-ins, follow-ups in its comments) | #1450 |
| All finished Wave 3 work | branch `fresh-eyes/wave-3-testing` |
| Decisions (authoritative, with every follow-up) | `.sdlc-memory/tree/self/decisions/D048.md` on that branch |
| Audit findings | `discovery/fresh-eyes/wave-3-findings.md` and `wave-3/` on that branch |
| Finished rebuild: `go-contract-test` | #1489, PR #1506, merged into the wave branch. The research notes from its interrupted first attempt are kept in `discovery/fresh-eyes/handoff/go-contract-test-notes.md`; its sections 11 and 12 are superseded by the decisions of 2026-11-28 in D048. |
| Per-skill record (eval runs, diagnoses, grader changes) | comments on each sub-issue |
| Original campaign plan (was only on the old machine) | `discovery/fresh-eyes/handoff/fresh-eyes-plan.md` |
| Project-board tooling state (normally gitignored) | `discovery/fresh-eyes/handoff/github-project-state.json` |

## Status

Done and merged into the wave branch (20 sub-issues, board status Done): setup (#1451, #1453, #1455), research (#1456–#1459, #1473, #1474), Python build-skill repair (#1477), and **13 of 24 skills**:

| Skill | Eval runs | Eval cost | Final |
|---|---|---|---|
| test-pyramid | 6 | $16.37 | pass, delta +0.78 |
| example-mapping | 2 | $5.75 | pass, +0.89 |
| acceptance-criteria | 2 | $4.76 | pass, +1.00 |
| bdd-feature-file | 2 | $5.85 | pass, +1.00 |
| test-fixture-design | 4 | $10.23 | pass, +0.56 |
| mock-generation | 2 | $5.84 | pass, +0.89 |
| go-unit-test | 4 | $9.47 | pass, +0.78 |
| python-unit-test | 2 | $6.24 | pass, +0.22 |
| go-integration-test | 4 | $13.38 | pass, +0.56 |
| python-integration-test | 2 | $6.98 | pass, +0.67 |
| go-contract-test | 4 | $11.12 | pass, +0.89 (3.1.0, after the sign-in addition #1514) |
| python-contract-test | 2 | $5.82 | pass, +1.00 |
| go-e2e-test | 4 (1 invalid) | $10.52 | pass, +1.00 |
| **Total** | | **$112.33** | |

Earlier chat and issue totals of $73.99, $87.90 and $98.37 were addition errors; $84.87 is the sum of the saved run results (which are gitignored and stay on the old machine).

Also done (2026-11-28): **#1510**, every script and test runs on stock macOS as well as Linux; the portability check is a blocking gate step and CI runs on both systems. Eval re-runs for it: `adr-authoring` and `skill-authoring-standards`, both pass, $5.67 (wave eval spend with the table above: $98.91).

Remaining:

0. **Working procedure per skill (product owner, 2026-11-28):** discovery of the current state by one subagent, research by a second only if required, then rebuild, separately authored evals, eval runs, CI on both systems, merge into the wave branch. The product owner has authorised continuing through the remaining skills in sequence under it.
1. **#1492** `python-e2e-test` next: discovery and research are posted on the issue and its three research notes are written; the rebuild is the next step (it uses a drift-tested copy of `go-e2e-test`'s environment script and needs its own quarantine list file). Then #1493–#1502 in order. #1518 (`beta-program-design` 3.1.0) and #1512 are merged. Eval spend outside the per-skill table: #1510 $5.67, #1512 $20.30, #1518 $3.96.
2. **#1507** Python coverage gate lists test-support code (decided, option B); re-evaluate `python-unit-test`. Separate branch.
3. **#1490–#1502** the other 13 skills: python-contract, go/python e2e, load, chaos, mutation, performance, react-component, react-e2e.
4. **#1503** close-out: follow-ups recorded on #1450 and #1503 (including re-running evals for `test-pyramid`, `go-unit-test`, `mock-generation`, edited after they passed), then a PR from the wave branch to `main` for the product owner's review. Also for #1503: align `test-pyramid`, `ci-pipeline` and `cd-pipeline` with the daily Pact run and the `can-i-deploy` deployment check.

Estimate for the remaining eval spend: about $95–170, within the $450 wave ceiling (about $85 used).

## Set up the new machine

1. `git fetch origin`. If `main` has local changes, commit them to a branch or `git stash` them first; ask the product owner, never discard.
2. `git checkout fresh-eyes/wave-3-testing && git pull`. Start each sub-issue from this branch: `/exec-start <n>` targets the branch you are on.
3. Restore the board tooling state: `cp discovery/fresh-eyes/handoff/github-project-state.json scripts/github-project/.state.json` (get the file from `main` with `git show origin/main:discovery/fresh-eyes/handoff/github-project-state.json` if the branch lacks it). Without it, `exec_complete.py` does not know a sub-issue's base branch and will not merge it.
4. Needed locally: `gh` signed in as the repository owner with `repo` and `project` scopes (`gh auth status`; `gh auth refresh -s repo,project`), Python 3 with `jsonschema`, the `claude` CLI (evals make real model calls on the signed-in account), Docker Desktop with WSL integration, and Node for the React skills. Go and Python test tools are downloaded into temporary folders by each rebuild; nothing is installed system-wide.
5. Check the setup: `bash scripts/lint-all.sh` and `bash tests/run-smoke-tests.sh scripts schemas arch` (last green: 2290 passed on Linux and on stock macOS alike, #1510). The scripts need only the system's own tools: on a Mac, Homebrew's GNU tools (`gnu-sed`, `gawk`, `grep`, `coreutils`, `findutils`, a newer `bash`) and the `~/.zshrc` lines that put them first on the `PATH` are **not** needed and can be removed. Docker Desktop's WSL integration applies to Windows only.
6. For #1489: `git checkout issue-1489-wave-3-skill-go-contract-test-research-grounded-re` and read the notes.

## How the work is run (product owner's working preferences)

- The product owner is a product manager, not a programmer: plain language, decisions as short tables with a recommendation, and the agent runs all commands.
- Auto mode with approvals: proceed on approved plans; ask only for decisions that are theirs. Never claim an approval that was not given.
- Subagents do the heavy work, one at a time. Rebuild writer and eval author are separate subagents; a third, which never reads the skill, grades failing replies.
- CLAUDE.md § Work Record: detailed issue comment after each step (every eval run included), short commit messages, real PR body with "Eval changes after freeze".
- Check the eval verdict yourself before `exec_complete.py`; it merges with no review gate.
- Eval budget up to $7 per run; $450 ceiling for the wave. Stop and show the position if a skill keeps failing.
- A run hit by a usage limit is invalid, not a failure: check per-attempt errors before judging a result, then re-run after the reset.
- A frozen grader changes only when shown wrong (verify, original author makes the smallest edit, log it).

## Added on `main` the day of the move (#1508)

- `tests/run-skill-evals.sh` now posts each eval run to the issue named by the `issue-<number>-…` branch (`scripts/record-eval-run.py`). Check it appeared, then add the diagnosis comment; a subagent that runs evals passes `--run-by subagent`. See CLAUDE.md § Work Record for the exact bold lead-ins a tool reads.
- The `**Claude prompt**` and `**Interruption**` comments come from a **user-level** hook, which is not in this repository: set it up on the new machine if wanted.

## Lessons that cut eval re-runs

- Replies fail mostly because a rule is followed but not **said**. Each rebuilt skill has "What every answer states".
- Long replies hurt: tell the skill to answer as briefly as asked.
- Tell eval authors: at most 5 criteria per case, each raised by the prompt, no required mechanism where several work.
- Docker work: remove containers with `docker rm -v`, touch nothing the agent did not create.
