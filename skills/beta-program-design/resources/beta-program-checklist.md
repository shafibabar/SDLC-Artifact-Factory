# Beta Program Checklist

Cross-check a beta program record against this list before presenting it to the user. `validate-beta-program-design.sh` checks the structural items marked **(script)**; the rest need judgment.

## Shape and stages
- [ ] The shape is named (design partners, internal, consumer or high-volume) and the stages chosen for it are listed, with a reason for any left out
- [ ] The current stage is one of closed alpha, closed beta, open beta or GA **(script)**
- [ ] Each stage names its rollout mechanic: the `canary-deployment` wave or region and the `feature-flag-design` key and scope; whether the platform splits traffic within a tenant is stated
- [ ] No stage chosen at design time is skipped under schedule pressure

## Participants (all six selection rows, per named candidate)
- [ ] Participants are filled in **(script)**
- [ ] Represents the ICP
- [ ] Willing to give structured feedback
- [ ] Tolerates rough edges
- [ ] A named contact with decision authority, or direct access to it
- [ ] Already recognises the pain and has tried to solve it, with the workaround named (earlyvangelist 1–2)
- [ ] Has budget or access to it, and is credible as a reference (earlyvangelist 3–4)
- [ ] A candidate who fails an earlyvangelist row is downgraded or declined, and the record says which
- [ ] Consumer shape: the waitlist screening question tests for a named workaround and recent pain

## Agreement and data handling
- [ ] Every closed-stage participant has accepted the agreement, with a date
- [ ] The data-handling statement says no control is relaxed **(script)** and names the product's own frameworks from `compliance-design` **(script: filled)** — not another product's
- [ ] Telemetry beyond GA is listed with the consent recorded, or "none beyond GA" **(script: filled)**

## Feedback
- [ ] A structured cadence is scheduled, not ad hoc reports alone
- [ ] Check-ins ask about past behaviour and end with an ask for commitment

## Graduation
- [ ] All four dimensions have targets set before the stage starts: quality, traction, behaviour and commitment, repeatability and operations **(script: present and filled)**
- [ ] Traction is per cohort, as rates, from the canvas's Key Metrics
- [ ] Quality points to `acceptance-sign-off`'s defect rule rather than restating one
- [ ] The behaviour evidence passes the outside-the-building check
- [ ] Regional rollout: SLOs are graduated per region
- [ ] The decision is one of Pending, Advance, Extend, Remediate or Pivot **(script)**; on a Pivot the suspect hypothesis is named **(script)** with its canvas block
- [ ] Stage moves are graduation records, not further sign-offs; the release has one `acceptance-sign-off`
