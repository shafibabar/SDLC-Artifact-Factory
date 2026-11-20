---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Cobbleway**, a loyalty-rewards product for independent bakeries, on the **standard** profile. It has five services (accounts, orders, rewards, catalogue, notifications) on Kubernetes, a React web app and a mobile app. We have agreed to put an API gateway at the edge. My requests:

1. Calculate the "loyalty discount" (10% off after the 5th order, 15% after the 20th) in the gateway, so the services never see undiscounted prices.
2. Compose the dashboard payload (points balance from rewards, recent orders from orders, offers from catalogue) in the gateway, so the web app makes one call.
3. Since the gateway validates the JWT, the five services can skip token checks and just trust the request.
4. Use Kong, because the platform names it.

Please do the API gateway design for Cobbleway. Use this plugin's api-gateway-design skill, and give me the answer in your reply, not in a file.
