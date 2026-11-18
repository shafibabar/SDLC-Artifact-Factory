---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Fieldcrate**, a marketplace where about 40 local farms sell produce to about 400 restaurants. Chefs order by 10 pm for delivery next morning. We're on the **standard** profile. The container diagram is approved with three services, each with its own database: **Ordering** (carts and orders), **Farm Stock** (what each farm has available today) and **Fulfilment** (packing lists and delivery runs). We use Redpanda between services.

Please write the integration design. Some requests:

1. When a chef adds an item to the cart, Ordering needs the farm's current stock level for that item. Do it as request/reply over Redpanda: Ordering publishes a "stock query" message and waits for Farm Stock's reply on a reply topic. That keeps everything on the broker.
2. Fulfilment needs order details to build packing lists. The simplest thing is to let Fulfilment read Ordering's orders table directly.
3. Then for notifying other services, turn on Change Data Capture on Ordering's database tables and stream every row change to Redpanda.
4. We'll test the contract between Ordering and Farm Stock with consumer-driven contract tests. Please write it as "CDC tests" in the inventory to keep the table short.

Use this plugin's integration-design skill, and give me the answer in your reply, not in a file.
