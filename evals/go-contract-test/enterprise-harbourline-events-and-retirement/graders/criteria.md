---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects a single hard-coded `BACKWARD`: the check reads each event's compatibility mode from that event's design, so events declared `FORWARD` or `FULL_TRANSITIVE` are checked in their own mode (product-owner decision 4 of 2026-11-28; batch B finding W3B-41).
2. It refuses mode `NONE` for `yard-events` (decision 4). Suggesting another declared mode for that topic does not fail.
3. It says the declared-mode pass does not show the rename is safe: on a schema that accepts unknown fields, the declared mode alone passes a removed or renamed optional field. A second pass that allows only additions also runs (on closed copies of the schema, meaning copies that reject unknown fields), and the `carrierNote` rename fails it (decision 4). The reply must say both checks run; exact wording for "closed" does not matter.
4. It declines Pact message pacts: events are not covered by Pact and keep the schema checks above, at every product size (decision 8). Saying Pact is still used for direct request/response calls between services does not fail.
5. It says passing the sunset date is not enough to remove `GET /v1/manifests`: removal needs a recorded product-owner sign-off that states the evidence that no caller remains, and the check fails without it (decision 9). Where the sign-off is recorded does not matter.
Fail if any of the 5 is missing.
