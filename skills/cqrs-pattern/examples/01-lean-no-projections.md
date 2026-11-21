# Example 1 — Lean: A Simple Read Model, No Record

Self-contained. **Pantry Pals** runs the volunteer rota and stock list for one community food bank, at the **lean** profile: one deployable, contexts **Rota** and **Stock**, about 40 volunteers. The phase plan skips the CQRS decisions record at lean; every context uses a Simple Read Model, listed in the Read Models table of `design/domain-model.md`.

## Input

> **User:** "Let's do CQRS properly from the start: Kafka, a projector per screen, and a separate read database, so we never have to rework it when we grow."

## Working it

- **Is there a trigger?** The screens: "my shifts", "shifts still needing people", "stock running low". Each is one query over one or two tables. Load: a few dozen reads an hour, a handful of writes. No screen needs a shape the write tables can't give cheaply, nothing needs history, and nothing crosses services (there is one deployable). No trigger.
- **"So we never have to rework it":** declined. Projectors, a broker and a second database add lag (a volunteer signs up and the list still shows the gap), rebuild duties and things to keep running, for a load a single database handles easily. Moving one context up later is a contained change: the query types already exist, only their source changes.
- **What stays from CQRS:** queries use their own read types, never the Shift or StockItem models; commands go through the models and return only an acknowledgement.
- **Revisit when:** a screen needs a shape the tables can't give cheaply, or a second deployable needs this data.

## Output: the Read Models section of `design/domain-model.md`

| Context | Read Model | Answers | Built from | Staleness accepted |
|---|---|---|---|---|
| Rota | MyShifts | the shifts a volunteer signed up for | shift and sign-up tables (query type, not the Shift model) | immediate |
| Rota | ShiftsNeedingPeople | shifts below their minimum, next 14 days | shift and sign-up tables, one join | immediate |
| Stock | RunningLow | items under their reorder level | stock table | immediate |

## Why this is right

- No trigger was named, so every context stays on rung 1; the reason for declining was given in full.
- The split that matters (queries never load the models, commands never return views) is kept.
- The signal that would reopen the decision is written down.
