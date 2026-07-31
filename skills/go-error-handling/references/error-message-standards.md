# Error Message Standards

Full worked material for `SKILL.md`'s "Error Message Standards" section.
Self-contained — reads without the parent body already in context. An error's
*message text* is a separate concern from its *type* (§1 of `references/error-
taxonomy-and-wrapping.md`): a sentinel or a typed error can each be written well
or badly, and this file governs the writing, not the taxonomy choice.

---

## The Four Rules

Every error message this plugin's generated Go code produces follows all four,
without exception:

1. **Actionable.** A reader — a human scanning logs, or the next layer's wrap —
   can tell what was being attempted from the message alone, without opening the
   source file. "failed" or "error occurred" tells a reader nothing they didn't
   already know from the fact that an error exists at all.
2. **Includes relevant IDs and context.** The specific resource, key, or
   parameter involved is in the message, not just the operation name. "data
   asset not found" is weaker than "data asset 7f3e...: not found" — the second
   is greppable against a specific incident; the first is not.
3. **Never leaks secrets.** No connection strings, no tokens, no full PII, no raw
   request/response bodies that might carry any of those. An error is going to be
   logged (see `references/panic-recover-and-logging.md`) and errors get logged
   at whatever verbosity the boundary chooses — treat every error string as
   eventually public within the org, and write it accordingly.
4. **Consistent casing and punctuation.** Lower-case start (unless the first word
   is a proper noun or an exported identifier), no trailing punctuation, no
   capitalization of the first letter. This is the Go community convention (Go
   `vet`'s own `errorf` check enforces the no-trailing-punctuation half) and it
   exists for a mechanical reason: wrapped messages compose by concatenation
   (§4 of the taxonomy file), so a capitalized or punctuated fragment reads wrong
   mid-sentence once wrapped — `"Loading data asset 7f3e: Not found."` wrapped one
   level further becomes `"classifying: Loading data asset 7f3e: Not found."`, an
   ungrammatical, inconsistently-punctuated mess. Lower-case, unpunctuated
   fragments compose cleanly at any depth.

---

## Worked Table: Good vs. Bad

| Bad | Why it fails | Good |
|---|---|---|
| `"Error loading data asset"` | Capitalized start; no ID; doesn't say why | `"loading data asset %s: %w"` — lower-case, includes the ID, wraps the cause |
| `"failed"` | Zero information beyond "something went wrong" | `"validating classify command: %w"` — names the exact operation |
| `"could not connect to postgres://user:s3cr3t@host:5432/db"` | Leaks a full connection string, credentials included | `"connecting to database: %w"` — names the operation, lets the wrapped `%w` (from pgx) carry only what pgx itself reports, which does not include the DSN |
| `"invalid input."` | Trailing punctuation; no field named; not actionable | `"field %q: required"` (as a `ValidationError`'s `Error()`) — names the exact field |
| `"Error: nil pointer dereference at handler.go:42"` | A raw internal detail (file:line) reaching a message a client could see | For an internal/programming-error case, the boundary's opaque 5xx message stands in — see `references/panic-recover-and-logging.md`'s Recoverer discussion; the file:line detail goes to the log's stack trace, never the message text itself |
| `"user John Smith (john.smith@example.com) not authorized"` | Leaks PII (full name, email) into a string that gets logged and potentially returned | `"actor %s: forbidden"` (subject ID, not name/email) — see security's `privacy-design` for what counts as PII in this repo |
| `"Sensitivity cannot be downgraded!"` | Capitalized, exclamation mark, no identifying data | `"data asset %s: cannot downgrade sensitivity %s → %s without explicit reclassification"` — the exact message `go-domain-model`'s `ErrSensitivityDowngrade.Error()` produces |

---

## Where the ID Comes From

The identifier in an actionable message is whatever the current layer actually
has in scope — an aggregate ID, a tenant ID, a field name, an event type. It is
never re-derived or looked up specially for the error path; if the layer doesn't
already have the ID as a local variable, the message is written without one
rather than adding an extra lookup solely to enrich an error string.

## Relationship to Wrapping

A well-written message at each layer is what makes wrap-chain composition
(§4 of `references/error-taxonomy-and-wrapping.md`) actually useful: the whole
value of `"commit: write outbox DataAssetClassified: connection reset by peer"`
depends on every one of its three segments individually following these four
rules. One badly-written segment ("failed") degrades the entire chain's
diagnostic value, not just its own layer's contribution.
