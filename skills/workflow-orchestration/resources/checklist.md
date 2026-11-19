# Checklist: Workflow Orchestration Design

Resource for `workflow-orchestration`. Run after `./scripts/validate-workflow-orchestration.sh` is clean; the script checks structure, this list checks judgement.

## Need and size
- [ ] Each orchestrated flow names the Richardson trigger that fired; no orchestration by habit.
- [ ] A flow of 2 or 3 independent steps, or all steps in one deployable and one database, was handed back (choreography or one local transaction).
- [ ] Lean is short or absent; a lighter choice at standard is risk-accepted with a reason.
- [ ] No workflow engine unless orchestrated flows have multiplied; the choice is stated.

## Steps and the pivot
- [ ] Every step has a command, an owning context and a class.
- [ ] Exactly one pivot, at the last step where abandoning the flow is acceptable; irreversible effects sit at or after it.
- [ ] A flow with two points of no return is split into two sagas.
- [ ] Retriable steps all come after the pivot and are never compensated; those that can fail for good have a named repair owner.

## Compensation
- [ ] Every compensatable step has a written compensation, semantic and not a rollback.
- [ ] Each compensation uses data captured on the way forward, named in the table.
- [ ] Each compensation is idempotent, retried until it succeeds, and escalated if it cannot.
- [ ] Compensations run in reverse order.

## The orchestrator
- [ ] State and the next command commit in one transaction through the Transactional Outbox; nothing is held only in memory.
- [ ] One writer per flow; replies carry the correlation id and the step they answer.
- [ ] Participants are Idempotent Consumers on the command id.
- [ ] The coordinator sends commands and records replies; every rule is applied by the owning context.
- [ ] Every wait has a timeout and an expiry path; locks are released on it.
- [ ] A progress view answers "where is this flow?" from the coordinator's own record, and it serves nothing else.
- [ ] The coordinator runs inside the tenancy boundary; no saga spans tenants.

## Isolation
- [ ] Every exposed record names its anomaly and its countermeasure (usually a semantic lock and its state).
- [ ] Every semantic lock has a clearing step on each path and a release for a stale one.
- [ ] No database lock is proposed to span steps.

## Scope and vocabulary
- [ ] No code, and no stack named where the design does not need it.
- [ ] No distributed transaction.
- [ ] Cross-service queries are left to `cqrs-pattern`.
- [ ] The three axes are written plainly; no saga archetype names as vocabulary.
