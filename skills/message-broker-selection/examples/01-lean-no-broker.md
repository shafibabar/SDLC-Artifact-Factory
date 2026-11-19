# Example 1 — Lean: A Small Tracker That Asks for Two Brokers and Needs None

Self-contained. **Plotline** is a booking app for a community garden association's allotment plots. **Lean** profile, one deployable (a modular monolith) with one database and three modules: **Plots** (availability, bookings), **Members** (accounts, dues) and **Reminders** (emails). The association has one board and about 300 members.

## Input

> **User:** "Install Kafka and RabbitMQ so we're ready if we ever add services. And tell me which one is the better message queue."

## Working it

- **Is a broker needed at all?** Every flow stays inside one deployable: Plots tells Reminders about a new booking, Members tells Plots a member lapsed. An in-process publisher keeps the same Domain Events with no topics, relay or operations (Vernon). No flow crosses a process boundary, no consumer needs history, and fan-out is two modules. **No broker.**
- **"Both, to be ready"** is declined: each broker is a system to run, secure and watch, and a second one doubles that, with no workload to justify either. The decision is made when a trigger appears, with the replay question answered then.
- **"Which is the better message queue"** has no answer, because they are not the same kind of thing. A log (Kafka API, Redpanda) keeps messages and lets a consumer re-read them; a queue (RabbitMQ) removes a message once it is acknowledged. The choice follows the replay question, not a ranking.
- **Cheap to change later:** the modules talk only through published events behind one publisher, so a broker can replace the in-process publisher without touching the modules.
- **What would change the answer:** a module is split into its own deployable, a consumer must re-read past events (a report built from history), or fan-out grows past a few modules.

## Output: the reply (no document at lean)

> **No broker for Plotline.** Every flow stays inside one deployable, so events are published in-process; nothing crosses a process boundary, nothing needs history, and fan-out is two modules.
>
> - **Neither Kafka nor RabbitMQ now.** Each is a system to run and secure, and there is no workload to justify one, let alone two.
> - **No "better message queue".** A log keeps messages and lets a consumer re-read them; a queue removes a message once handled. The model follows the replay question, and Redpanda is only the plugin's default, not a reason by itself.
> - **Cheap to add later:** keep the modules talking only through published events behind one publisher, so a broker can replace it.
> - **I would revisit** if a module becomes its own deployable, a consumer needs to re-read past events, or fan-out grows.
>
> No Broker Selection Rationale document is produced at lean. If a trigger arrives, it becomes a short document with the workload, the replay answer, one broker and an ADR.
