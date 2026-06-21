# Skill: design/ubiquitous-language-bc

## Purpose
Produce the Ubiquitous Language glossary for one bounded context. This is a DDD non-negotiable: the language in the code must exactly match the language in this document, which must exactly match the language the domain expert uses. The same word in two different bounded contexts may have different definitions — this is correct.

## Inputs
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/aggregates/` (for the target bounded context)
- `artifacts/design/domain/events.md` (filtered to target context)
- `artifacts/design/domain/commands.md` (filtered to target context)
- `sdlc-config.json`
- **Argument required:** bounded context name (e.g. `file-domain`, `compliance-domain`)

## Output
**File:** `artifacts/design/language/{bc-name}.md`
**Registers in manifest:** yes

## Language Rules (enforced)
- Terms are defined as they are understood in THIS bounded context only. Cross-context divergence is documented explicitly.
- Every aggregate, command, event, value object, and domain service in this context must have a term entry.
- Definitions are plain language — no technical implementation details. A domain expert should recognise their language.
- Synonyms and aliases are listed and either unified or documented as intentionally separate concepts.
- Negative definitions ("this term does NOT mean X") are included where confusion risk is high.
- The glossary skill (`core/glossary`) consumes this file for validation. Every term in generated artifacts must appear here.

## Artifact Template

```markdown
# Ubiquitous Language: {Bounded Context Name}

**Product:** {product_name}
**Bounded Context:** {bc-name}
**Phase:** Design
**Artifact:** Ubiquitous Language Glossary
**Version:** 1.0
**Date:** {date}
**Status:** Living document — update as the domain model evolves

---

## How to Use This Glossary

All code, tests, documentation, and conversations about this bounded context MUST use these exact terms. When a domain expert uses a different word, either:
1. Update this glossary if they are correcting us, or
2. Note the synonym and redirect to the canonical term

---

## Core Terms

### StorageLocation
**Definition:** A registered connection point to an external storage system (cloud file service, S3 bucket, SharePoint library) that the product has been granted read-only access to for scanning purposes.

**Not to be confused with:**
- A file or folder within the storage system (that is a `DiscoveredFile`)
- A customer's physical data centre or server

**Context divergence:** In the Entity Domain, this concept is referenced as `SourceReference` — the two are representations of the same real-world thing from different domain perspectives.

**Used in:** `StorageLocation` aggregate, `RegisterStorageLocation` command, `StorageLocationRegistered` event

---

### Credential
**Definition:** A read-only authorisation token or service account reference that grants the product permission to access a StorageLocation. The product stores only a reference to the credential, never the credential value itself.

**Invariant:** Credentials MUST have read-only scope. The product will reject any credential that has write access.

**Not to be confused with:**
- User credentials (login passwords) — those belong to the Identity Domain
- API keys for the product itself — those are product configuration, not domain credentials

---

### DiscoveredFile
**Definition:** A file or document detected at a registered StorageLocation during a scan. Represents the existence and metadata of the file at a point in time. Does NOT contain the file's content.

---

### FileProcessingJob
**Definition:** The unit of work representing the extraction of text and metadata from one DiscoveredFile. A FileProcessingJob has a lifecycle: pending → in_progress → completed | failed.

---

### Scan
**Definition:** The process of traversing a StorageLocation to detect new, modified, or deleted DiscoveredFiles. May be a full scan (all files) or incremental scan (changes since last scan). A scan is orchestrated by the product and executed by a WorkerNode.

---

### WorkerNode
**Definition:** A compute resource deployed within the customer's infrastructure that performs the actual file traversal and text extraction. WorkerNodes never send file content outside the customer's environment.

**Key distinction:** WorkerNodes are the execution environment for scanning. The product's control plane only tells WorkerNodes what to scan, not where to send results — results stay on-premise.

---

### ScanConfiguration
**Definition:** The parameters controlling how a scan is executed: which file types to include or exclude, the maximum compute resource percentage the scan may consume, and the scan schedule.

---

## Process Terms

### Scan Lifecycle States

| State | Definition |
|-------|-----------|
| **Pending** | StorageLocation registered; credentials not yet validated |
| **Active** | Credentials validated; location is ready and eligible for scanning |
| **Scanning** | A scan is currently in progress on this location |
| **ScanError** | The most recent scan failed; location requires intervention |
| **Deregistered** | Location has been removed from the scan scope |

---

## Event Terms

| Event name | Meaning in plain language |
|-----------|--------------------------|
| `StorageLocationRegistered` | A new location has been added to the scan registry |
| `CredentialsValidated` | The system confirmed the stored credential has valid, read-only access to the location |
| `CredentialValidationFailed` | The credential check failed — access denied or credential expired |
| `ScanInitiated` | A scan has begun on a location |
| `FileDiscovered` | A file was found (new or previously unseen) during a scan |
| `FileModified` | A file previously catalogued has changed since last scan |
| `FileDeleted` | A file previously catalogued no longer exists at the location |
| `FileProcessed` | A DiscoveredFile's content has been extracted and is ready for entity extraction |
| `ScanCompleted` | A scan has finished traversing the location |

---

## Terms That Do NOT Belong in This Context
The following concepts exist in the product but belong to other bounded contexts. Do not use these terms in File Domain code, tests, or APIs:

| Term | Belongs to | Why excluded |
|------|-----------|--------------|
| `Entity` / `GoldenRecord` | Entity Domain | Entities are what get extracted from files — that is Entity Domain's concern |
| `Finding` | Compliance Domain | Compliance evaluation is not a File Domain responsibility |
| `DataSubject` | Compliance Domain | A legal concept; File Domain does not apply legal classification |
| `User` | Identity Domain | File Domain knows only that a command was authorised; it does not manage users |

---

## Synonyms Resolved

| Synonym used elsewhere | Canonical term in this context | Resolution |
|-----------------------|-------------------------------|-----------|
| "data source" | `StorageLocation` | "Data source" is too generic; use `StorageLocation` |
| "connector" | `StorageLocation` | The connector is the mechanism; `StorageLocation` is the domain concept |
| "crawler" | `WorkerNode` | "Crawler" is an implementation term; use `WorkerNode` in domain conversations |
| "job" | `FileProcessingJob` | "Job" alone is too vague; always qualify |
```

## Quality Checks
- [ ] Every aggregate, command, event, and value object in this bounded context has a term entry
- [ ] Cross-context divergences are explicitly documented (same real-world thing, different concept name)
- [ ] "Terms that do NOT belong" list prevents concept leakage
- [ ] Synonyms are resolved to canonical terms
- [ ] Definitions are written in plain language a domain expert would recognise
- [ ] State names (lifecycle states) are defined unambiguously
