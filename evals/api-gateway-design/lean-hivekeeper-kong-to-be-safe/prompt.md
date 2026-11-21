---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Hivekeeper**, a beekeeping hive-inspection log on the **lean** profile. It is one web application (React front end served by a single backend application) deployed as one container on Kubernetes, with one PostgreSQL database and about 300 hobbyist users. My requests:

1. Install Kong in front of the app "to be safe", since every serious product has an API gateway.
2. Add a Kong plugin that checks the user's role (admin, inspector, viewer) before it lets a request through, so we do not have to build that into the app.
3. Give us the Kong admin UI so we can add and edit routes live whenever we need to.
4. Since Kong will check the token, the app itself can skip token validation.

Please do the API gateway design for Hivekeeper. Use this plugin's api-gateway-design skill, and give me the answer in your reply, not in a file.
