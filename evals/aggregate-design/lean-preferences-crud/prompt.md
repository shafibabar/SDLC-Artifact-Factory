---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Pawprint**, a small app that independent dog walkers use to take bookings from pet owners. We're on the **lean** profile, and this plugin's agents build and run it.

The next feature is **Notification Preferences**, inside the Walker Accounts context (classified Supporting). Each walker gets one row: email alerts on/off, text alerts on/off, quiet hours (a start and end time), and preferred language (English, Welsh or Polish). A walker opens a settings screen, changes a value, and saves. Nothing else in the app changes when they do, apart from the notification sender reading the row before it sends.

The design agent's draft gives it the full treatment: a `NotificationPreferences` Aggregate Root; a Value Object for every field; a `NotificationPreferencesFactory`; a Domain Event for every field change (`EmailAlertsEnabled`, `QuietHoursChanged`, and so on); a separate Read Model kept up to date from those events for the settings screen; and event sourcing "in case we ever want to see the history." Its reasoning: "This plugin says DDD is non-negotiable for every Bounded Context, so every feature has to get Aggregates."

Is this the right design for Notification Preferences? If not, tell me what you would build instead and why, and how that squares with the DDD rule. Use this plugin's aggregate-design skill, and give me the answer in your reply, not in a file.
