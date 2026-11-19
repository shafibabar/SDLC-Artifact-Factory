# Versioning and the Contract Lifecycle

Reference for `api-contract-design` step 8. Grounded in Newman (*Building Microservices*: the Tolerant Reader, running versions side by side), Geewax (prefer additive change; version as a last resort) and Lane (*The API-First Transformation*: lifecycle stages and treating the contract as a product).

## Additive or breaking

| Change | Kind | Action |
|---|---|---|
| A new optional response field | additive | no new version |
| A new endpoint | additive | no new version |
| A new optional request parameter | additive | no new version |
| Removing a response field | breaking | a new major version |
| Renaming a field, or changing its type | breaking | a new major version |
| Removing an endpoint | breaking | a new major version |
| Making an optional request field required | breaking | a new major version |

Prefer additive evolution; a new version is a last resort, because every version is a contract to run and support.

## The Tolerant Reader

Additive change is only safe if consumers cope with it. A consumer reads only the fields it needs and ignores unknown ones, so a new optional field breaks nothing (Newman). Write this as an expectation in the contract's description, and in a consumer's contract test.

## Version in the path

The path carries the major version (`/v1/`, `/v2/`). A breaking change is introduced as `/v2/`, and `/v1/` keeps running beside it until it is retired. Do not change `/v1/` in place.

## Deprecation and sunset, sized to the consumers

An old version is deprecated with notice, not removed by surprise.

- **Announce** with a `Deprecation` response header on the old version (and a sunset date), and a note in the summary's breaking change log.
- **Size the sunset to who consumes it.** A single internal front end released with the service can retire a version in step with it; a partner or public API gives consumers time for their own release cycles, commonly several months. State the period; do not copy one number everywhere.
- **Retire** only after the sunset and after the consumer registry shows no remaining caller.

## Audience and the consumer registry

Record who consumes the API: this product's own front end, other services, partners, or the public. A partner-facing or public API is **flagged** in the summary, because the lifecycle discipline matters most when consumers are outside the team's control (Lane). The consumer registry lists every known consumer; a consumer with no contract test is a change this log cannot protect.

## The lifecycle

A contract moves through design, definition (the OpenAPI file), development, deployment, documentation, testing and eventually deprecation and retirement; each stage leaves something checkable (a spec, a changelog, a notice). Because one agent designs every contract for a product, consistency across them (the same errors, pagination, auth, naming) comes from this skill's conventions applied by the checklist, not from a standing review board.
