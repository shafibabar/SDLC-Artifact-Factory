---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **SunShare**, a platform that runs community solar subscriptions across three US states. Households subscribe to a share of a local solar farm; SunShare works out each subscriber's monthly share of the farm's output and the bill credit it earns. We're on the **enterprise** profile. SunShare depends on systems run by other organisations: each **partner utility's billing system** receives a monthly file of subscriber credits from us; each **solar farm operator's metering system** sends us hourly production readings; and the state **Public Utility Commission's reporting portal** receives a quarterly enrollment report from us. Subscribers pay through **Stripe**, and our operations staff resolve billing disputes.

Our architect has already drafted the container diagram. On it, the outside systems are named **"Utility Billing System"**, **"Farm Metering System"**, **"PUC Reporting Portal"** and **"Stripe"**.

Please draw the system context diagram. Some requests:

1. Our one platform team builds three microservices, Subscriptions, Allocations and Billing. Please show each as its own system box on the context diagram, so the executives can see how the product is split up.
2. The architect keeps talking about "containers", so please list our Docker images and the Kubernetes cluster on the context diagram as well.
3. For the executives, use friendlier names than the container diagram does: "Partner Utility", "Solar Farm" and "The Regulator".

Use this plugin's system-context-diagram skill, and give me the answer in your reply, not in a file.
