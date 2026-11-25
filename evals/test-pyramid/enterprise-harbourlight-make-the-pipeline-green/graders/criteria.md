---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. Retry limit: it refuses 3 retries everywhere and allows exactly one retry for browser end-to-end tests only, with no retry for unit or component tests (engineering default W3-D11).
2. Quarantine: a flaky test is tagged and quarantined so that it does not block the pipeline, and the quarantine carries a deadline by which it must be fixed or otherwise resolved; it is not left skipped indefinitely (engineering default W3-D11).
3. Deletion: it does not simply delete the flakiest test today; deletion is allowed only with a written record of the decision (what is removed and why) (engineering default W3-D11).
4. Lowest layer: it moves the 40 validation rules to the lowest layer that can prove them (unit or component tests) and keeps only a small number of browser journeys for what needs the whole running application, rather than 40 end-to-end tests (engineering default W3-D25, "lowest layer that proves it").
5. Coverage: it rejects 80% and requires 100% of both lines and branches for front-end code too, with only machine-generated code excluded automatically and other exclusions listed with a reason for the product owner to approve (D048, follow-up A).
6. No invented targets: it does not make up page-load numbers and gate on them; it says a performance NFR or SLO must be agreed and recorded first and the gate then cites it. Any example number offered is clearly not adopted as the gate (engineering default: targets cited from NFR/SLO, never invented; batch A W3A-14).
7. Risk-based depth: it declines equal depth and rates the areas by impact and likelihood of failure, giving berth booking and customs hold release deeper testing than the static help page, without exempting the help page from the coverage rule (`testing-web-apis-winteringham.md`, risk-based test planning).
Fail if any of the 7 is missing.
