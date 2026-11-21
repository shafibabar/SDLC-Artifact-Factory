---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Haulmark**, a freight-tendering platform. Around 300 shipper companies each have their own private account on it: they tender loads, carriers accept them, and the shipper's dispatchers assign a truck. We're on the **enterprise** profile, run active-active in two regions, and this plugin's agents build and run it.

The design agent's draft command catalog covers `TenderShipment`, `AcceptTender`, `AssignTruck` and `CancelShipment`. Three things in it worry me:

1. Our shippers' systems retry `TenderShipment` whenever a call times out, which happens a lot during a regional failover. The draft handles duplicates by "ignoring a new tender if one with the same origin, destination and weight was created in the last five minutes".
2. Two dispatchers at the same shipper sometimes assign different trucks to the same shipment at the same moment. The draft fixes this by "locking the shipment row from the moment a dispatcher opens the assignment screen until they press save".
3. The commands carry no shipper account identifier, "because shipment IDs are globally unique anyway".

Please review these three points and tell me what the catalog should say instead for each command: how duplicates are recognised and what a duplicate gets back, how simultaneous changes are handled and how that rejection differs from a business-rule rejection, and what each command must carry. Use this plugin's command-catalog skill, and give me the answer in your reply, not in a file.
