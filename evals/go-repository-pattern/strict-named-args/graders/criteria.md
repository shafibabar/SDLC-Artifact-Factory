---
type: llm
weight: 1
---

The response recommends `pgx.StrictNamedArgs` with `@name` placeholders for this six-parameter statement on pgx >= 5.6. It explains that StrictNamedArgs fails the query when a placeholder has no argument or an argument is unused, and it advises against plain `pgx.NamedArgs` because a misspelled name silently binds NULL (or otherwise explains why the strict form is preferred over plain NamedArgs). It also makes clear the values are still sent separately from the SQL, so this is as injection-safe as positional $N, and never string-built SQL. Fail if it says pgx has no named parameters, recommends plain NamedArgs, or recommends only positional $N without mentioning StrictNamedArgs.
