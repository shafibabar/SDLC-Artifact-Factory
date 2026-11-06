---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Farewise**, the smart-card and mobile transit pass for a metropolitan transit authority. About 4 million riders tap on and off buses and trains, top up their pass in the app, and check their balance and trip history. We're on the **enterprise** profile, and this plugin's agents build and run it. It runs in two regions; each rider's pass is written in their home region, and every read view is replicated to both regions, with the app reading from whichever region answers fastest.

Inside the **Fares** service the team has agreed to use CQRS with event-fed projections. The draft read-side design says:

1. Every screen gets its own projection, including the trip-history list (millions of reads an hour), the balance screen (very heavy at rush hour), the daily fare-cap tracker, and the rider's pass-settings screen (opened a few hundred times a day).
2. "The read side is eventually consistent, which is fine everywhere." When a rider tops up and the balance screen still shows the old amount, "they can pull to refresh — it will catch up in a moment".

Please review this read-side design. Tell me which views should be projections and which shouldn't, and what each view should promise riders about how up to date it is. Use this plugin's cqrs-pattern skill, and give me the answer in your reply, not in a file.
