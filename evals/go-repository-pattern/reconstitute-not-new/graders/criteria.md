---
type: llm
weight: 1
---

The response says NO: a repository read path must map rows through domain.Reconstitute(...), never a New… constructor. It explains both consequences of using New on a read: (1) it re-runs invariant checks against data the database already accepted, and (2) it re-emits the creation Domain Event (e.g. DataAssetRegistered), so a stale event would be republished into the outbox on reads. New… is only for creating a genuinely new Aggregate on the command side. Fail if it allows New on the read path or omits the re-emitted-event consequence.
