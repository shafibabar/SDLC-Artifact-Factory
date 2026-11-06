---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Parcelpath**, the parcel tracking platform for a national courier: about 2 million parcels a day, and the public "Where's my parcel?" page is opened roughly 30 million times a day. We're on the **enterprise** profile, and this plugin's agents build and run it.

The CQRS decisions record (`design/architecture/cqrs-decisions.md`) puts the **Tracking** Bounded Context on projections because of read load, and says the `ParcelTracking` view may be at most 30 seconds behind. The view is built from Domain Events published by the Tracking context; the events are kept, all the way back to launch four years ago.

We have a problem. A projector bug shipped three weeks ago recorded the wrong depot for rerouted parcels, and about 40,000 rows in the `ParcelTracking` view are now wrong. The bug is fixed in code. The team has three proposals:

1. Fix the data with a one-off SQL `UPDATE` on the view table, using a spreadsheet of the correct depots that operations has put together. It's fastest.
2. If we must rebuild instead, truncate the view and replay every event from the start overnight. The tracking page would show "temporarily unavailable" for the six hours it takes.
3. The fixed projector only has handlers for the event types we publish today. Last year `DeliveryAddressChanged` was replaced by a new event type, `ParcelRerouted`. The projector ignores event types it doesn't know, "so the old `DeliveryAddressChanged` events will just be skipped during the replay, which is fine".

Separately, to take load off the view during peaks, a developer wants to put a cache in front of the tracking page that keeps each parcel's result for 24 hours.

How should we put the view right, and what do you think of the cache? Use this plugin's read-model-design skill, and give me the answer in your reply, not in a file.
