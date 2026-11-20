---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **PocketVet**, a small appointment and reminders app for independent veterinary practices. It is on the **lean** profile: one deployable with two modules inside it, Scheduling and Reminders, built by a team of three. We have 25 practices on it, all using the browser app. My requests:

1. I want Scheduling and Reminders to talk to each other over gRPC, with a `.proto` between them, because it is more professional.
2. I also want the browser app to call the backend over gRPC "because it is faster".
3. Please give me a proto design for both.

Please do the gRPC contract design for PocketVet. Use this plugin's grpc-contract-design skill, and give me the answer in your reply, not in a file.
