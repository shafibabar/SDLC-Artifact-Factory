---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects both proposed commands and uses `oasdiff breaking` with `--fail-on WARN`. It says that without `--fail-on` the command exits successfully even when it finds a breaking change, so the check would never fail (product-owner decision 1 of 2026-11-28; `research/testing/oasdiff-official-docs.md`, Core Concepts). It does not need to explain what `--fail-on ERR` lets through, but it must not settle on `ERR`.
2. It says the new description is compared with the one that is currently deployed, not with the previous commit on the branch (decision 1; batch B finding W3B-39, "breaking-change diff against the deployed spec"). How the deployed copy is fetched does not matter.
3. It says removing the optional `giftNote` response field is not let through: removing or renaming an optional response field is raised to an error and fails the check (decision 1).
4. It says removing the documented 404 is a breaking change and fails the check, whether or not a caller is known to handle it (decision 2).
5. It says the new `ON_HOLD` response enum value fails the check by default and passes only after the product owner approves it and the approval is recorded in an exceptions file that is printed on every run; and it refuses the wildcard, because one approval covers one change and any later addition fails again until it is approved (decision 3). The file's name and format do not matter.
Fail if any of the 5 is missing.
