# Program Shapes

How the three shapes in `SKILL.md` § 1 differ in recruiting, cohort size, rollout and evidence. The stages, the four graduation dimensions and the one-sign-off rule are the same for all three.

## B2B Design Partners

- **Recruiting:** from `stakeholder-mapping`'s design-partner cohort, each a named organisation already in a "Manage Closely" relationship, screened per participant (`SKILL.md` § 3).
- **Cohort size:** one for the closed alpha, 3–5 for the closed beta. Enough to see a pattern; few enough for a bi-weekly conversation with each.
- **Rollout:** each partner is a tenant. The canary widens tenant by tenant; the release flag is scoped to their tenant ids.
- **Evidence:** leans on behaviour and commitment (named contacts, check-ins, a paid pilot), plus the repeatability of onboarding each partner.

## Internal Rollout

- **Recruiting:** the customer's own staff. Start with the team that feels the pain most (and will forgive rough edges), then everyone.
- **Stages:** usually a closed alpha (one team) then GA (all staff); there is no outside audience for an open beta. Record that choice.
- **Agreement:** a short note to the alpha team instead of a signed agreement; data handling follows the organisation's own policy.
- **Evidence:** traction is easy to measure (everyone is reachable); repeatability means staff can start from the intranet page or onboarding email without someone walking them through it; operations means the team that runs the backstage process can handle it at full staff volume.

## Consumer or High-Volume Open Beta

- **Waitlist with a screening question.** Ask one or two questions that test for the earlyvangelist conditions at scale: "How do you do this today?" (a named workaround) and "When did it last cause you a problem?" (recent pain). Invite the closed-beta cohort from the people with a named workaround and recent pain, not first-come first-served.
- **Cohort size:** large enough that activation and retention rates mean something. Hundreds for a closed beta, then waves that grow by roughly an order of magnitude (for example 500 → 5,000 → open). Each wave is a cohort for traction.
- **Opt-in telemetry.** Collect only what the graduation measures need, with consent recorded and a switch to turn it off; anything beyond what GA collects is listed in the data-handling statement and the agreement.
- **Regional rollout.** Where users span regions (data residency, language, payment rails, support hours), each region is its own wave with its own row and decision in the graduation record. SLOs are measured **per region**: one region's latency or error budget must not hide behind the global average (`slo-definition`). A region that misses its bar holds while others advance.
- **Feedback:** short in-app surveys per wave instead of bi-weekly calls; a few recorded interviews per wave with users who stopped, asking what they did instead.
- **Evidence:** leans on traction per cohort and per region; behaviour and commitment come from the interviews and from paid conversion where pricing is live (`pricing-and-packaging`).
