---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects skipping Pact: the direct `invoicing` to `payments` call gets a Pact contract now, at the lean profile, with no trigger (such as a second team) and no decision record needed. Saying that lean means fewer boundaries to cover, not a skipped check, is consistent with this.
2. It puts the pacts on a self-hosted open-source broker and says a paid hosted service such as PactFlow needs the product owner's approval first (or is not the default).
3. It moves Pact verification off the pull request: Pact runs as a daily scheduled run that produces an impact report for the product owner, and a pull request is not blocked by Pact.
4. It says the deployment of a service checks the latest recorded Pact result with `can-i-deploy` and is refused when that result shows a broken caller, so a green pipeline plus the description check is not enough to deploy.
5. It keeps the provider's real token-checking middleware in place during verification and rejects saving a working token in the pact: the recorded example token is replaced at verification time by one signed with a key made for the test run. How the swap is done (a state handler, a header override, a swapped verifier key) does not matter.
Fail if any of the 5 is missing.
