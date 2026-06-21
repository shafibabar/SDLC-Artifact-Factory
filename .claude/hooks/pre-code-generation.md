# Hook: pre-code-generation

## Trigger
Fires immediately before any skill or command generates actual Go source code (as distinct from specs, guides, and documentation). Specifically fires before `implement/service-skeleton` writes file content that includes Go code blocks intended for direct use.

## Purpose
A secondary gate after `pre-implement`. By this point, TDD specs and BDD feature files should exist. This hook does a final check that the code about to be generated is grounded in the current design — catching cases where the design has changed since the TDD spec was written.

---

## Checks

### 1. Design freshness check

Compare the last-modified timestamps of:
- `artifacts/design/domain/aggregates/{relevant-aggregate}.md`
- `artifacts/implement/specs/{story-id}-tdd-spec.md`

If the aggregate definition is NEWER than the TDD spec:

```
Warning: The aggregate definition for {AggregateName} has been updated since
the TDD spec for {story-id} was written.

  Aggregate last modified: {date}
  TDD spec created:        {date}

The TDD spec may be stale. Review:
  artifacts/design/domain/aggregates/{name}.md (current)
  artifacts/implement/specs/{story-id}-tdd-spec.md (may be outdated)

Proceed anyway? (yes / review first)
```

### 2. Ubiquitous language consistency check

Scan the TDD spec for type names, method names, and error names. Verify each against:
- `artifacts/design/language/{bc-name}.md` (bounded context language)
- `artifacts/design/domain/aggregates/{name}.md` (canonical type names)

Flag any terms in the TDD spec that do not appear in the ubiquitous language:

```
Warning: The following terms in the TDD spec are not in the ubiquitous language:
  - "FileJob" (used in test names) — canonical term is "FileProcessingJob"
  - "ScanStatus" (used in assertions) — canonical term is "StorageLocationStatus"

Update the TDD spec to use canonical terms before generating code.
```

### 3. Secrets pattern scan

If the generated code content includes any of the following patterns, FAIL immediately:
- Hardcoded strings resembling API keys, tokens, passwords
- `os.Getenv("*_SECRET")` or `os.Getenv("*_PASSWORD")` (use Kubernetes secrets instead)
- Connection strings with credentials inline

```
FAIL: Generated code contains a potential secret:
  Line 47: os.Getenv("DB_PASSWORD")

Credentials must be loaded from Kubernetes secrets (mounted as env vars via ExternalSecret),
not from plain environment variables set directly.
See: artifacts/design/security/secrets-management.md
```

### 4. Architecture layer check (pre-generation)

If the skill is generating a file in `internal/domain/`:
- Warn if the template imports from `internal/infrastructure/`
- This is a known generation error — catch it before writing

---

## Output Format

```
=== Pre-Code Generation Check ===

  ✓ Design freshness: TDD spec is current with aggregate definition
  ✓ Ubiquitous language: all terms consistent with design/language/file-domain.md
  ✓ Secrets: no hardcoded credentials detected
  ✓ Architecture: domain package imports are clean

  Proceeding with code generation.

{On failure:}
  ✗ Ubiquitous language: 2 non-canonical terms detected (see above)
  Code generation blocked. Fix the TDD spec and retry.
```
