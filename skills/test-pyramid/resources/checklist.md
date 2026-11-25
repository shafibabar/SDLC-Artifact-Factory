# Checklist: Test Strategy

Run after `validate-test-strategy.sh` (the skill's script) is clean. The script checks structure; this list checks judgement.

## Scope
- [ ] All eight layers are planned whatever the profile; none is skipped, deferred or marked not applicable. A boundary that truly does not exist is stated as a fact in its row for approval.
- [ ] Each behaviour sits at the lowest layer that proves it; no layer ratio appears.
- [ ] Every service, event, remote screen and language in the design appears.
- [ ] Every Must Have criterion maps to a scenario; each criterion ID exists in the criteria files.

## Risk and targets
- [ ] Each risk row traces to a real requirement, event or decision, and high ratings add named checks.
- [ ] Every number traces to the cited NFR or SLO; missing ones are open questions.
- [ ] Each chaos experiment proves a pattern the design actually has.

## Gates
- [ ] Coverage rows match the languages; Go states its unmeasured cases and the trial outcome (not run, passed or failed), never assumed.
- [ ] Every non-generated exclusion, including tool defaults, ignore comments and packages left out of mutation, has a reason and is shown to the product owner.
- [ ] Mutation rows read per-mutant results and state what is never planted.
- [ ] No gate is described as met without a run.

## Operation
- [ ] Browser journeys with mocks run as their own pull-request job; full end-to-end nightly and before release.
- [ ] Smoke is read-only; destructive suites cannot reach a real environment.
- [ ] Quarantine has a deadline and an owner.
- [ ] Delegated checks have a named gate; any missing one is an open question.
- [ ] Open questions and layers without an owning skill are put to the product owner.
