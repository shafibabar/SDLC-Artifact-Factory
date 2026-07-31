# Reversibility in Full — the Down Standard and Its One Real Exception

Full worked material referenced from `SKILL.md`'s "Up/Down Reversibility Standard"
section. Self-contained. Covers: why every migration carries a working `Down` even
though production never runs it, what "working" means precisely, and the exact
two-phase pattern for the one class of change that cannot be truly inverted —
a data-destructive drop.

---

## 1. Why `Down` Exists Even Though Production Never Runs It

`SKILL.md`'s forward-only-in-production rule (production rolls forward; a bad change is
corrected by a new forward migration, never by running `Down` against live data) can
read as making `Down` decorative. It is not: `Down` is exercised constantly, just never
in production — every local reset (`goose down` while iterating on a migration before
it merges), every ephemeral test database torn down and rebuilt between CI runs, and
every `go-integration-test` Testcontainers instance that applies the full migration
history from zero all depend on `Down` actually working. A `Down` block that only
*looks* like a valid inverse — one nobody has actually run — is worse than a missing
one, because it fails silently until the one time a developer resets local state mid
schema change and gets a corrupt database with no error message pointing at why.

**The standard: every migration's `Down` must be exercised in CI**, not merely present.
The concrete check: a CI step runs `goose up` to the latest version, then `goose down`
back to zero, then `goose up` again, against a fresh database — a `Down` block that is
syntactically invalid or semantically wrong (drops the wrong object, leaves an
orphaned constraint) fails this round-trip immediately, on the pull request that
introduced it, not months later when someone happens to need it.

---

## 2. The One Real Exception — Data-Destructive Drops

A `Down` that re-creates a dropped table's *structure* is trivial. A `Down` that
restores the *rows* that were in it before the `Up` ran is impossible in the general
case — the data is gone, and no SQL statement can reconstruct values that were never
recorded anywhere else. This is the one place "every migration has a working Down" and
"a Down never silently loses data" are in tension, and the standard resolves it by
**never actually attempting the impossible inverse**: a genuinely destructive change is
never a single migration.

**The two-phase pattern.** Split the destructive change into an archive step (fully
reversible) and a physical-drop step (irreversible, isolated, and small):

```sql
-- Phase 1 — 00008_data_assets_archive_legacy_notes.sql
-- Reversible: renaming a column changes nothing about its data or the table's shape
-- beyond the identifier. This migration's Down is a true, working inverse.
-- +goose Up
ALTER TABLE data_assets RENAME COLUMN legacy_notes TO legacy_notes_deprecated;

-- +goose Down
ALTER TABLE data_assets RENAME COLUMN legacy_notes_deprecated TO legacy_notes;
```

The column sits renamed — unused by any code path, but its data fully intact and
trivially recoverable by re-running `Down` — for a defined retention window (an
operational decision, not a migration-file property: long enough that a discovered
problem in the deploy that stopped using the column can still be traced back to real
data, typically one full release cycle).

```sql
-- Phase 2 — 00014_data_assets_drop_legacy_notes.sql
-- IRREVERSIBLE. Filed as its own migration, reviewed on its own PR, only after the
-- retention window in 00008's PR description has passed with no incident.
-- +goose Up
ALTER TABLE data_assets DROP COLUMN legacy_notes_deprecated;

-- +goose Down
-- Intentionally not a true inverse — the dropped column's data cannot be
-- reconstructed. Recreating the column here would silently claim success while
-- returning an empty, misleading column. Fail loudly instead: a developer who runs
-- `goose down` through this migration needs to know their local database can no
-- longer be rolled back past this point, not receive a column that looks fine and
-- silently isn't.
DO $$
BEGIN
    RAISE EXCEPTION
        'migration 00014 is irreversible: legacy_notes_deprecated data was physically dropped. '
        'Rebuild the local database from a snapshot taken before this migration, or from zero.';
END $$;
```

This confines true irreversibility to one small, explicitly labeled migration whose
`Down` deliberately fails instead of lying — the CI round-trip check in §1 is expected
to stop *before* this migration when validating a database that must remain resettable
past it (a documented, intentional exception in the CI step's version range, not a
disabled check).

---

## 3. The Manual-Rollback Runbook (Production)

Because production never runs `Down` at all (`SKILL.md`'s forward-only rule), "rollback"
in production for a Phase-2-style migration is never a `goose down` invocation — it is
always a **new forward migration** restoring from whatever archive the Phase 1 step
left behind, while that data was still retained. This is why the retention window in §2
is load-bearing: past it, there is no runbook that recovers the data, in production or
anywhere else — only the two-phase pattern's Phase 1 window gives an operator a real
undo path. A migration's PR description for a Phase-1 archive step should state the
retention window explicitly (e.g. "safe to drop after 2026-08-15") so the Phase-2 PR's
reviewer can verify the window has actually elapsed before approving it.

---

## 4. When the Two-Phase Pattern Is Overkill

Not every drop needs this ceremony — the standard applies to a drop of a column, table,
or constraint that **currently holds production data a person could plausibly need
back**. Dropping an object that was never populated (a column added and immediately
found unnecessary before any deploy wrote to it), or an object that is provably
reconstructible from another source of truth already in the schema, may be a single
ordinary migration with a working structural `Down` — apply judgment, but default to
the two-phase pattern whenever in doubt, since the cost of an unnecessary archive
column is small and temporary, and the cost of an unrecoverable, unplanned data loss is
not.
