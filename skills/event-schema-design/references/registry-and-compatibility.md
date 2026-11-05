# Registry, Compatibility Modes and the CI Gate

The detail behind `SKILL.md` § 3: whether a product needs a schema registry, which compatibility mode each event gets, and how compatibility is enforced mechanically. Grounded in Kleppmann (*Designing Data-Intensive Applications*, Ch. 4) and Young (*Versioning in an Event Sourced System*), as summarised in `research/software-architecture/designing-data-intensive-applications-kleppmann.md` and `research/domain-driven-design/versioning-event-sourced-system-young.md`. Deploying a registry is platform work (`platform-engineer`); wiring the check into a pipeline is `ci-pipeline-design`.

## 1. Choose the format and the registry before the first event is stored

Serialisation decides which evolution approach stays cheap (Young):

| Format | Evolution | Fits |
|---|---|---|
| JSON with tolerant, name-based reading | weak schema almost for free; nothing stops a careless rename except tests | most products; humans can read the topic |
| Avro | reader/writer schemas; additions safe with defaults; needs the writer's schema at read time, so a registry | high volume, many consumers |
| Protobuf | field numbers make additions safe; never reuse a number; renames are wire-safe but break JSON mappings and generated code | high volume, typed contracts across languages |

**Is a registry needed?** The plugin's tech-stack defaults name none, so it is a per-product choice recorded in the artifact:

- **Lean, or a handful of consumers in one codebase:** no registry. Schema files live in the repository beside the producer. Compatibility is checked by **consumer contract tests** (`go-contract-test`) and a schema-diff check in CI. `dataschema` points at the file's versioned path.
- **Several independently deployed consumers, Avro or Protobuf, or several teams:** a registry. It is the wire contract's single source of truth, rejects incompatible versions at registration time, and gives each version a URI for `dataschema`. Prefer an open-source one (frugality): Apicurio Registry (Apache 2.0; JSON Schema, Avro and Protobuf; a Confluent-compatible API). Confluent Schema Registry is under the Confluent Community Licence, which restricts offering it as a service; check that before choosing it.

## 2. Compatibility modes

| Mode | New readers read old events | Old readers read new events | Choose when |
|---|---|---|---|
| **BACKWARD** (default) | yes | not guaranteed | consumers upgrade before or with producers; the usual case |
| **FORWARD** | not guaranteed | yes | producers deploy first, while consumers still run the old schema |
| **FULL** | yes | yes | many independent consumers with no controlled deploy order |
| `*_TRANSITIVE` | checked against **every** earlier version, not just the last | | retained or replayable topics, where old records stay readable |
| **NONE** | — | — | never on a published event |

Two traps:
- **JSON Schema is not Avro.** With `additionalProperties: false`, removing or even adding a field can fail validation of old or new events. Under JSON Schema, keep `additionalProperties` open for tolerant readers, or know exactly what the mode then permits.
- **A mode only checks shape.** A change of unit or meaning with the same field name and type (cents to pounds) passes every mode and is still breaking. That is why Young's classification comes first (`./evolution.md` § 1).

## 3. The gate

- **Register before the first publish.** The schema is registered (or committed) in the pipeline before any producer that emits the type deploys. A producer serialising from whatever its code currently holds, with registration "later", has no contract.
- **CI rejects an incompatible version** by attempting the registration or running the schema diff. Compatibility never rests on reviewers noticing.
- **Producers may validate the payload against the registered schema** before writing the outbox row, so an invalid event rolls back with the state change.
- **Never delete a registered schema,** even after the type is retired: retained and replayed records still reference it. Any automation syncing schema files to the registry must not prune.
- **Turning a subject's mode to NONE "to get a change through"** disables protection for every later change. A breaking change takes the protocol instead.
