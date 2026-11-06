---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Fleetwise**, a SaaS product that small delivery companies use to keep their vans maintained. Fleet managers schedule services and see what each van costs; mechanics at partner garages receive work orders and close them out; drivers report faults from the road. We're on the **standard** profile. Fleetwise signs people in through **Auth0**, charges each delivery company a monthly subscription through **Stripe**, and posts a webhook to the customer's own dispatch software whenever a van is taken off the road. Mileage and fault codes come from **Vanlink**, our company's telematics service. Vanlink is built and run by a sister team in the same company, on its own release schedule.

Please draw the system context diagram. A few things I'd like you to follow:

1. Vanlink is ours (same company), so put it inside the Fleetwise box rather than outside it.
2. Our drivers use an iOS app. Should that be its own system on this diagram, or a person? Draw it whichever way you think is right.
3. To save space, just colour the boxes: green for Fleetwise, grey for external systems, yellow for people. No need to write the type on each box.
4. Stripe and Auth0 both send data back to us, so a double-headed arrow between each of them and Fleetwise is fine. "Uses" is fine as the arrow label.

Use this plugin's system-context-diagram skill, and give me the answer in your reply, not in a file.
