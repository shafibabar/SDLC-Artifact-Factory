# jsonschema and referencing Official Documentation
**Authors:** The python-jsonschema project
**Domain:** Testing (contract and schema validation, Python)

Accessed 2026-11-25. jsonschema 4.26.0, Python >=3.10, needs `referencing>=0.28.4` (https://pypi.org/pypi/jsonschema/json). Doc pages are `stable`.

## Core Concepts

- **`format` is not enforced by default.** Pass a format checker such as `Draft202012Validator.FORMAT_CHECKER`. Some formats need extras (`format` or `format-nongpl`); **a missing dependency makes the check succeed silently** (https://python-jsonschema.readthedocs.io/en/stable/validate/; .../faq/).
- `validate()` picks the draft from `$schema`, else the latest; it runs `check_schema` first. `iter_errors` lists all errors (validate page).
- References resolve through a `referencing.Registry` passed as `registry=`. `RefResolver` is deprecated; remote references are not fetched automatically; a `retrieve` callable adds loading, with a security warning for untrusted schemas (https://python-jsonschema.readthedocs.io/en/stable/referencing/).
- `Resource.from_contents` reads `$schema`; without it, `CannotDetermineSpecification`, so state the specification (for example `DRAFT202012.create_resource`) (https://referencing.readthedocs.io/en/stable/intro/).
- `PointerToNowhere` (subclass of `Unresolvable`): a JSON Pointer to a location absent from the resource (https://referencing.readthedocs.io/en/stable/api/).
- `default` values are not filled in (faq).
- OpenAPI 3.1 Schema Objects are a superset of JSON Schema 2020-12; `jsonSchemaDialect` sets the default dialect (https://spec.openapis.org/oas/v3.1.0.html).

## Actionable Techniques (design is this note's)

- Register the whole OpenAPI document under a URI and validate with a `$ref` into it, so `#/components/...` has a document to resolve against.
- Enable format checking, install the extra, and test that an invalid value is rejected.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-contract-test | W3C-17, 21 | Registry use, format silence |

## Candidate New Skills/Agents

None.

## Key Terminology

Registry, Resource, Specification, Format Checker.

## Caveats

- Nothing was run. [unverified] OpenAPI 3.0 schema differences and behaviour of any OpenAPI-specific validator.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-17: isolated sub-schema raises `PointerToNowhere` | Error meaning matches | Confirmed (meaning); the proposed fix is [unverified] until run |
| W3C-21: `format: uuid` not enforced | Off by default | Confirmed |
| W3C-21: `additionalProperties: false` forbids added fields | Not covered on pages read | [unverified] |
