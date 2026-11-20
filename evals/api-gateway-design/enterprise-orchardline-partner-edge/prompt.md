---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Orchardline**, a produce-wholesale platform on the **enterprise** profile. It exposes a partner-facing API used by about 400 grocery-chain systems, served from three regions with a gateway per region, and about 20 services behind them on Kubernetes. My requests:

1. Just add a rate limiter to the gateways so partners cannot overload us.
2. Put the rule "which partner may see which price list and order" into gateway plugins, so the services stay simple.
3. Have the gateway add an `X-User-Id` header after it validates the token, and let every service trust that header.
4. During incidents our on-call engineers must be able to edit routes live through the gateway's admin API.

Please do the API gateway design for Orchardline. Use this plugin's api-gateway-design skill, and give me the answer in your reply, not in a file.
