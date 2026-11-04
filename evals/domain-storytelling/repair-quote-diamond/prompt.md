---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Spokeshop**, an app for independent bike-repair workshops, on the **standard** profile. On Tuesday our head mechanic walked us through how a repair goes today, and I took these notes while she talked:

1. The customer brings the bike to the counter and tells the counter assistant what's wrong.
2. The counter assistant writes a paper job card and clips it to the bike.
3. The mechanic inspects the bike and writes a quote on the job card.
4. The counter assistant phones the customer and reads out the quote.
5. The customer approves the quote. (If they say no, the bike goes back unrepaired and we charge a £10 inspection fee. Sometimes the customer doesn't answer and the bike sits on the rack for days.)
6. The mechanic repairs the bike and ticks the job card.
7. The counter assistant phones the customer to say the bike is ready.
8. The customer collects the bike and pays at the till.

What I want, as a domain story:
- One picture of the whole thing. Put a decision diamond at step 5 ("Customer approves quote?") with a yes branch and a no branch, and number the no-branch steps 5a, 5b so it all fits.
- We're building the Spokeshop app to replace the paper job card and the phone calls, so please use **annotated mode**: draw today's flow and add the app's steps on the same picture, so the developers see old and new together.
- Keep every sentence strictly three-part, subject–verb–object. Drop the "to whom" bits (like "to the counter assistant"); they clutter the picture.

Using this plugin's domain-storytelling skill, give me the story (or stories) and your reasoning in your reply, not in a file.
