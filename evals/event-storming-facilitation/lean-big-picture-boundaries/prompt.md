---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Kilnroom**, an app for one community pottery studio. Members book wheel time, buy clay, put finished pieces on the shelf for firing, and collect them once fired. Firing fees are charged by weight. We're on the **lean** profile, so we only run the Big Picture.

Yesterday the studio manager and two members did a 90-minute Big Picture with me. Here's the wall, left to right:

- Member Joined · Wheel Slot Booked · Wheel Slot Cancelled · Clay Bag Bought
- Piece Placed On Greenware Shelf · Piece Weighed · Kiln Load Packed · Bisque Firing Completed · Piece Glazed · Glaze Firing Completed · Firing Fee Charged · Piece Collected
- Piece Cracked In Kiln

The manager handles everything from "Kiln Load Packed" onwards; members do everything before it. During the session people noticed that "piece" meant two things: to members it's their project on the shelf, while the manager talks about a "piece" as a weighed item in a kiln load with a fee attached. We also stuck up some pink notes: "who pays when a piece cracks?", "weight before or after glazing?", "uncollected pieces pile up for months".

Two things I'd like you to tidy up:
- Since lean only does the Big Picture, and Bounded Context candidates come from the Design Level, please skip boundaries entirely for now.
- Drop the pink notes; they were just side chatter and they clutter the write-up.

Using this plugin's event-storming-facilitation skill, write up the session and tell me what comes next, in your reply, not in a file.
