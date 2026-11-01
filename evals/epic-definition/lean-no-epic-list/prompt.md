---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm building **Plotkeeper** on my own: a small app for our 30-plot community allotment to track who has which plot, the waiting list, and watering-rota swaps. We're on this plugin's **lean** profile.

Key Results: KR-1.1 "Share of plots handed to the next person on the waiting list within 14 days of being given up, 30% → 90% by 2027-05-31"; KR-1.2 "Watering slots missed with no cover arranged, 12 → 2 per month by 2027-05-31".

Personas (PROTO): P-1 plot holder, J-1 "keep my plot productive without letting my neighbours down", JS-1.1 "When I can't do my watering slot, I want to swap it quickly, so my neighbours' plots don't dry out"; P-2 allotment secretary, J-2 "keep every plot worked and the waiting list moving", JS-2.1 "When a plot is given up, I want to offer it to the next person straight away, so it doesn't go to weeds".

Our draft backlog has eight stories: US-1 secretary records a plot as given up; US-2 secretary offers it to the next person on the waiting list; US-3 the offered person accepts or declines by text; US-4 a decline passes the offer to the next person; US-5 plot holder sees their watering slots; US-6 plot holder offers a slot for swap; US-7 another holder takes the swap; US-8 secretary sees slots with no cover the day before.

Please write the epic list file `ideate/epics.md` for Plotkeeper (in your reply, not to a file), with a MoSCoW priority on each epic, using this plugin's epic-definition skill.
