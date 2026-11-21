# Example 2 — Standard: Process Modelling of one flow, with an external payment system and breaks in the chain

Self-contained. **Toolshare** is a peer-to-peer marketplace for renting power tools, at the **standard** profile. The Big Picture (agent-run, reviewed with the product owner) voted the top hotspot "deposits and damage disputes", between the pivotal events `RentalConfirmed` and `PayoutReleased`. That process goes to Process Modelling.

## Input

> **User:** "Model the booking-to-payout flow. Fill in any gaps with whatever's sensible; I'd rather have a complete diagram."

## Working it

- **Scope:** from `RentalConfirmed` to `PayoutReleased`, plus the unhappy ends.
- **The chain, path by path.** Happy path: the owner sees the Handover Checklist (read model), records the handover (command), the rental system produces `ToolHandedOver`. Later the renter returns it, the owner inspects it: `ReturnInspected`. Policy P1: whenever `ReturnInspected` with no damage, then `ReleaseDeposit`, and the Payment Provider produces `DepositReleased`. Policy P2: whenever `DepositReleased`, then `ReleasePayout`, giving `PayoutReleased`. Stable end.
- **Unhappy paths:** damage found; the renter doesn't return the tool; the deposit hold expires at the Payment Provider before the return (holds last 7 days, per the provider's docs in `traces-to`).
- **Breaks, not guesses.** On the damage path, nothing says who decides the deduction or what the renter can do. "Sensible" filling would invent a dispute rule that then hardens into the model. Each break becomes a hotspot.

## Output — the reply, and `artifacts/toolshare/design/event-storming/process-booking-to-payout.md` (extract)

> The happy path and the late-return path are complete. Two places I've left as open questions rather than filling in, because a guess there becomes the product's dispute policy: who decides how much is deducted for damage, and what the renter can do if they disagree. There's also a timing problem: the provider releases a deposit hold after 7 days, so a 10-day rental loses its deposit before the tool comes back. That one goes to the architecture evaluation as a risk as well as to you.

```markdown
## Paths

| Path | Read Model | Actor or Policy | Command | System | Domain Event | Source |
|---|---|---|---|---|---|---|
| Happy | Handover Checklist | Owner | RecordHandover | Rental system | ToolHandedOver | ideate/job-stories.md J6 |
| Happy | Return Checklist | Owner | InspectReturn | Rental system | ReturnInspected | J7 |
| Happy | — | Policy P1 | ReleaseDeposit | Payment Provider | DepositReleased | vision |
| Happy | — | Policy P2 | ReleasePayout | Payment Provider | PayoutReleased | vision |
| Damage | Return Checklist | Owner | ReportDamage | Rental system | DamageReported | J7 |
| Damage | ? | ? | ? | ? | ? | **break: H1, H2** |
| Late | Overdue Rentals | Policy P3 | ChargeLateFee | Payment Provider | LateFeeCharged | *assumed* |

**Stable ends:** PayoutReleased (happy); LateFeeCharged then PayoutReleased (late); damage path open (H1, H2).

## Policies

| ID | Whenever (event) | Then (command) | Automatic or by a person |
|---|---|---|---|
| P1 | ReturnInspected with no damage | ReleaseDeposit | Automatic |
| P2 | DepositReleased | ReleasePayout | Automatic |
| P3 | Return overdue by 24 hours | ChargeLateFee | Automatic (*assumed*) |

## External Systems

| System | Receives commands | Produces events |
|---|---|---|
| Payment Provider | ReleaseDeposit, ReleasePayout, ChargeLateFee | DepositReleased, PayoutReleased, LateFeeCharged, DepositHoldExpired |

## Breaks in the Chain (hotspots)

| ID | Where the chain breaks | Question for the product owner | Assumed meanwhile |
|---|---|---|---|
| H1 | After DamageReported | Who decides the deduction: the owner, Toolshare, or a fixed table? | None: path left open |
| H2 | After DamageReported | Can the renter dispute it, and who settles a dispute? | None: path left open |
| H3 | DepositHoldExpired before return | Rentals over 7 days lose the deposit hold. Re-authorise, or cap rentals at 7 days? | Also sent to architecture-evaluation as a risk |
```

## Why this is right

- The request to "fill in gaps with whatever's sensible" was declined where a guess would decide a business rule. Each break is a hotspot.
- Every path that is complete reaches a stable end, and policies read "whenever …, then …".
- The external system's own behaviour (hold expiry) surfaced a risk that goes to the architecture evaluation as well as to the product owner.
