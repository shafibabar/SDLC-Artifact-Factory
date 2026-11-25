# oasdiff Official Documentation
**Authors:** The oasdiff project (oasdiff/oasdiff)
**Domain:** Testing (contract compatibility, OpenAPI)

Accessed 2026-11-25. Latest v1.39.0, 2026-11-17 (https://api.github.com/repos/oasdiff/oasdiff/releases/latest). Apache-2.0 (https://github.com/oasdiff/oasdiff). Docs base: D = https://raw.githubusercontent.com/oasdiff/oasdiff/v1.39.0/docs.

## Core Concepts

- Commands: `breaking`, `changelog`, `diff`, `summary`, `upgrade` (repository page).
- Levels ERR (breaking), WARN (possibly breaking), INFO; `breaking` shows ERR and WARN (D/BREAKING-CHANGES.md).
- `--fail-on ERR|WARN` exits 1 (`INFO` only for `changelog`); `MISSING-VERSION-BUMP` fails only without a major `info.version` increase (same).
- `--err-ignore`, `--warn-ignore`: text files; each line an endpoint or `components` plus the change description; extra text allowed (same).
- `--severity-levels` can raise, lower or disable checks (`none`) (same).
- Formats: text, json, yaml, markdown, html, githubactions, junit, singleline (same).
- Error exit codes: 101 invalid flags, 102 spec failed to load, 103 glob matches nothing (D/ERRORS.md).
- OpenAPI 3.1 generally available from v1.15.0; `$dynamicRef` not resolved, `components.pathItems` silently dropped (D/OPENAPI-31.md).

## Actionable Techniques (design is this note's)

- Pin v1.39.0; compare the deployed spec with the new one using `breaking --fail-on ERR`; decide WARN policy explicitly.
- Review ignore and severity files as an exclusion register with reasons.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-contract-test, python-openapi-codegen | W3C-23, C-6 | Gate flags and exit codes |

## Candidate New Skills/Agents

None.

## Key Terminology

Breaking Change, Severity Level, Ignore File.

## Caveats

- Nothing was run. [unverified] Exit status without `--fail-on` when changes exist.
- Scope is OpenAPI documents; it is not shown to check event schemas.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-23 / C-6: `oasdiff` provides an HTTP breaking-change gate | Yes | Confirmed |
