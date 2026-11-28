---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the nightly run in the throwaway kind cluster does not prove capacity: it is an indicative check that can only catch a regression between runs. A verdict against the 120 requests per second target needs a designated performance environment that the product owner approves for this product.
2. It refuses the plan to load shared staging as asked, and says the test by default refuses staging or any other target that is neither the throwaway cluster nor a designated performance environment. It says such a run is possible only when the product owner signs a statement of exactly where the load runs and what its impact will be.
3. It rejects skipping load testing because the product is lean: the indicative tier still runs (for example nightly in the kind cluster), and a lean product may have only that tier until a performance environment is approved.
4. It uses k6 instead of vegeta as the load tool.
5. It rejects the stored long-lived token. The indicative tier needs no stored credential, and a designated environment uses a short-lived token the product owner approves, never a standing secret.
Fail if any of the 5 is missing.
