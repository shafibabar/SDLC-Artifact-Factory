# Hand-over Record Checklist

Run after `./scripts/validate-handoff-record.sh` exits clean. The script checks structure; these items need judgement.

## Ownership and order
- [ ] Every concern belongs to the producing agent under the matrix in `SKILL.md`; nothing was decided by an agent that doesn't own it.
- [ ] Every decision the concerns depend on was made earlier by its owner (the read side before Read Models; the event catalog before the envelope; tenancy before the deployment view).
- [ ] Missing upstream decisions are open questions naming their owner, with any assumption labelled, not decided here.

## The hand-over
- [ ] Each concern is named precisely and points to an artifact that exists.
- [ ] The Definition of Done for the producer's stage (`./references/ownership-and-order.md` § 3) is met for every concern marked *yes*.
- [ ] The mode is the default, or joint review with one of the named reasons; any change of mode records its trigger.

## Flags back
- [ ] Every defect the receiver found is a flag with evidence, routed to the artifact's owner; no artifact was edited by an agent that doesn't own it.
- [ ] Fixed flags on approved artifacts sent them back for re-approval.
- [ ] Declined flags carry the owner's reason; a still-disputed one is a dispute, with status *blocked*.

## Status
- [ ] *Accepted* only with every Definition of Done met and no flag open.
- [ ] *Blocked* records name both positions and who decides.
- [ ] *Paused* and *model-revision* records say what kind of interruption it was and who acts next; a model found wrong routes to the model's owner and lists the downstream artifacts to review.
