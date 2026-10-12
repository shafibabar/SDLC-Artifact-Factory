---
type: llm
weight: 1
---

The response rejects BOTH proposals per this plugin's standard:
1. No shared internal/infrastructure/errors.go. Translation lives in a small private helper (translatePgError) beside the repository that uses it, because infrastructure doesn't own a failure vocabulary; it only translates into the domain's errors, and no pgx/pgconn type may leave the postgres package.
2. A server-side statement_timeout (SQLSTATE 57014) and a client-side context.DeadlineExceeded map to the SAME domain error (ErrTimeout), because the caller can't act on the difference.
Fail if it endorses either proposal.
