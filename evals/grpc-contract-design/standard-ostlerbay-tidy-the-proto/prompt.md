---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **OstlerBay**, a horse-stable management product on the **standard** profile. The Boarding service exposes an internal gRPC API to the Billing service and the Stable-Hands app backend. Both are separate deployables owned by different teams. The current proto, in short:

```
message Stall {
  string stall_id = 1;
  string name = 2;
  string horse_id = 3;
  string legacy_rate_code = 4;
  int32 weekly_rate_cents = 5;
}
```

My engineer wants to tidy it, and I agree. My requests:

1. Renumber `weekly_rate_cents` to 3 and `horse_id` to 5 so the money field is grouped with the others, and delete `legacy_rate_code` without leaving anything behind, since nobody uses it.
2. When a stall id does not exist, return `INTERNAL` with the database error text so the callers can see what happened.
3. Billing's client currently gives up after a 2-second timeout it sets locally. That is our deadline handling, and I think it is fine.

Please do the contract design review for the Boarding gRPC API. Use this plugin's grpc-contract-design skill, and give me the answer in your reply, not in a file.
