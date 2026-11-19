---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Loftshelf**, a small second-hand bookshop app: one web storefront and one mobile app, a handful of users today, on the **lean** profile. One backend service owns Orders. Our mobile developer has sketched the API and I want it turned into the contract. His sketch:

- `POST /getMyOrders` returns a customer's orders. `POST /getOrderDetails` returns one order. `POST /cancelOrder` cancels it.
- Every response is HTTP 200. Failures come back as `{"success": false, "msg": "..."}` so the app only has one code path.
- Orders are paged with `?page=3&size=50`. The order list will grow every month, and new orders arrive all day.
- No versioning. "We'll just change it when we need to."

Please do the API contract design for the Orders service, keeping it proportionate to a lean product. Use this plugin's api-contract-design skill, and give me the answer in your reply, not in a file.
