---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Tallybridge**, an order-management product on the **standard** profile: three Go services, each with an OpenAPI description. I want a pull-request check on the orders API description, set up like this:

1. Run `oasdiff breaking old.yaml new.yaml` with no extra flags, or at most `--fail-on ERR`, so warnings do not block anyone.
2. For `old.yaml`, use the description from the previous commit on the branch.
3. This sprint we drop the optional `giftNote` field from the order response. It was optional, so let that through.
4. We also stop documenting the 404 on `GET /orders/{id}`. No caller handles it, so that is not a breaking change.
5. We add `ON_HOLD` to the `status` enum in the order response. That is purely additive. Add a wildcard ignore line for the `status` enum so this and any later additions pass without anyone asking me.

Tell me, point by point, what the check should do. Use this plugin's go-contract-test skill, and answer in your reply, not in a file. Keep it short: under 250 words, one or two lines per point, plus the command.
