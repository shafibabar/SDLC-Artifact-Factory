**PROJECT**

Product

*Data Estate Mapping ** & ** Compliance Intelligence*

Product Ideation Document

Status: Ideation — Pre-MVP

# **1. Problem Statement**

Organizations handling sensitive data operate with a fundamental blind spot: they have no active, real-time map of where their data entities exist, how they are related, and who has access to them. People, companies, contracts, invoices, emails, and records are replicated across cloud storage, on-premises servers, and individual user machines, without any unified view of where they live or how they connect.

- Compliance exposure: Sensitive entities in unprotected locations or accessible by unintended users create audit risk. Organizations only discover these gaps during audits, not before.

- Operational blindness: Without a complete entity map, internal analysis for marketing, customer success, and operations is fragmented and unreliable.

- Storage waste: Duplicate, outdated, and dormant file copies accumulate undetected, inflating storage costs and expanding the compliance surface area.

| **Core Insight** | The problem is not that organizations lack data — it is that they lack a map of their own data estate. The product draws that map. |
| --- | --- |

# **2. Solution Overview**

The product is a private-deployment data estate mapping and compliance intelligence platform. Organizations register their storage locations, be it cloud, on-premises, or user machines, and The product deploys specialized lightweight worker nodes that crawl files, extract and index entities, and build a continuously updated graph of relationships and locations.

The graph and analytics layer enables compliance teams, IT leadership, and finance to query, visualize, and act on their data estate in natural language — without data leaving infrastructure controlled by the organization.

| **Differentiator** | **Description** |
| --- | --- |
| **Data residency by design** | All worker nodes, graph data, and models run within the customer's own infrastructure. No data transits to The product servers. |
| **Private LLM inference** | Natural language querying uses a locally hosted model grounded in the entity graph, not a shared cloud model. The model performs inference over the indexed graph; it is not trained on company data. |
| **Graph view + dashboards as USP** | Both the interactive entity graph and structured compliance dashboards are available from the initial release. The combination is the core product differentiator. |
| **SOC 2-first compliance** | SOC 2 is the priority framework for the initial release. GDPR, HIPAA, ISO 27001, and PCI DSS follow in subsequent phases. |
| **Actionable remediation (post-MVP)** | Beyond detection, users can trigger human-in-the-loop remediation workflows, access revocation, archival, notifications, and documented exceptions. |

# **3. Target Market**

## **3.1 Primary Customer Profile**

Small and medium organizations (50–500 employees) that handle sensitive information and operate under compliance obligations but lack the IT budget or personnel of large enterprises. These organizations currently experience compliance as a reactive, audit-triggered event rather than a continuous practice.

- Professional services (legal, accounting, consulting)

- Healthcare and health-adjacent services

- Financial services and fintech

- SaaS companies handling customer PII

- Government contractors and regulated suppliers

## **3.2 Decision Makers & Buyer Personas**

| **Persona** | **Primary Concern** | **Representative Quote** |
| --- | --- | --- |
| **IT Head / CISO / CIO** | Compliance planning, audit readiness, access control monitoring, continuous adherence tracking | "I need to prove to auditors that we have controls in place — and I need to know before they arrive, not during." |
| **CFO / Finance Head** | Storage cost forecasting, sustainability planning, cost reduction through dormant file management | "I have no visibility into what we're storing, why we're storing it, or what it would cost to clean it up." |
| **Operations / Legal** | Contract and entity tracking, data subject request fulfillment, traceability of sensitive records | "When a client asks what data we hold on them, I currently have no reliable way to answer that quickly." |

# **4. Product Architecture**

## **4.1 Deployment Model**

The product is deployed within infrastructure controlled by the customer organization. Two deployment paths are supported:

- One-click cloud tenant deployment: Automated provisioning to the customer's AWS, Azure, or GCP account via a guided wizard. The wizard handles all infrastructure setup — compute, graph database, worker node orchestration, and local model hosting — in a single authenticated flow requiring no engineering knowledge. Target completion time is under 20 minutes, validated with non-technical users before any public launch.

- Managed private cloud: For customers who prefer not to manage infrastructure, The product operates as a managed environment with dedicated tenants on their behalf within a dedicated cloud environment. No data commingling with other customers. Customer retains full data ownership and deletion rights at all times.

| **Non-Negotiable Principle** | No customer data, files, entities, graph data, or query results ever transit to or are stored on The product-operated shared infrastructure. |
| --- | --- |

## **4.2 Crawl Architecture: Initial Scan & Incremental Detection**

### **Phase 1 — Initial Full Scan**

When a new storage location is registered, a full crawl is initiated across all in-scope files. This scan is intentionally intensive: it processes every file, extracts all entities, and builds the complete graph map. It runs as a scheduled background job with configurable resource caps to minimize production impact. Users are notified when the initial scan completes and the full graph becomes available.

### **Phase 2 — Event-Driven Incremental Scanning**

Once the initial map is established, The product shifts to a continuous event-triggered model. The worker node monitors for storage events, new files created, file content modified, files moved or copied, access permissions changed, and files shared externally and immediately initiates an incremental scan on the affected file or location only. The graph is updated, and any new findings are surfaced in real time.

| **Design Goal** | The time between a compliance-relevant event occurring (e.g. a file containing PII moved to an unprotected folder) and that event appearing as a finding in The product should be measured in seconds, not hours. |
| --- | --- |

## **4.3 Entity Extraction Quality**

Entity extraction quality is the technical foundation on which all compliance value rests. The product addresses quality through a layered approach:

- High-precision NER models are validated against representative samples from each supported file format before deployment. Accuracy thresholds are defined per entity type and enforced as release criteria.

- Confidence scoring is applied to every extracted entity. Entities below a configurable threshold are flagged for review rather than surfaced as findings.

- Human-in-the-loop review mode during onboarding: the system presents a sample of extracted entities to an administrator for confirmation before the full graph is activated. This builds trust in the extraction layer and provides calibration data.

- Custom entity types include example-based calibration: the user provides positive and negative examples, and extraction behaviour is tuned against these before that entity type goes live.

## **4.4 Data Architecture Principles** (this is in addition tot he previous provided principles)

The product's data layer is designed around a set of foundational principles that govern how data is captured, stored, reconciled, and trusted across the system. These principles are not implementation details — they are architectural commitments that shape every component and integration.

### **System of Record & Source of Truth**

The product functions as the System of Record for the organization's data estate map — the authoritative, single source of truth for entity locations, relationships, access states, and compliance findings. While the files themselves remain in their source storage systems, the entity graph, extraction results, access metadata, and compliance findings are owned and governed exclusively by The product.

The distinction is important: source storage systems (Google Drive, S3, SharePoint) are the system of record for file content. The product is the system of record for the meaning, relationships, and compliance posture derived from that content. These two systems of record are complementary, not competing.

| **Single Source of Truth** | For any compliance question — where does an entity appear, who has access, what is the current finding state — The product is the single source of truth. No other system in the customer's environment holds this view. |
| --- | --- |

### **Golden Record & Master Data Management**

When the same real-world entity (a person, company, or contract reference) is extracted from multiple files across multiple storage locations, The product creates a Golden Record: a single, authoritative master representation of that entity, deduplicated and enriched across all its occurrences.

Master Data Management governs how this Golden Record is maintained:

- Deduplication rules define when two extracted entity instances are treated as the same real-world entity (e.g. 'J. Smith', 'John Smith', and 'John A. Smith' may resolve to the same person given contextual signals).

- The Golden Record holds the canonical form of the entity, with all source occurrences linked as references back to their originating files.

- When an entity is updated — for example, a person's role or an organization's name changes — the Golden Record is updated and all linked occurrences are re-evaluated against compliance rules.

- Conflicting extractions (e.g. two files with different email addresses for the same person) are flagged for human review rather than silently resolved.


### **Data Lineage**

Every entity, finding, and compliance event in The product carries a complete data lineage trace: the chain of provenance from source file through extraction, deduplication, graph insertion, rule evaluation, and finding creation. Data lineage serves two purposes:

- Auditability: an auditor or administrator can trace any finding back to its exact source — which file, which extraction event, which rule triggered, when each step occurred.

- Debugging: when an extraction produces unexpected results or a finding seems incorrect, the lineage trace allows the engineering team or administrator to identify exactly where in the pipeline the issue originated.

### **Data Integrity & Data Immutability**

Data integrity is enforced at every layer of the pipeline. Checksums are computed and stored for raw file content at extraction time. Any re-processing of a file is validated against the stored checksum to ensure the source has not changed between extraction cycles.

Compliance findings, audit events, and the Central Audit Log are immutable: once written, they cannot be modified or deleted, only superseded by subsequent events. This immutability is a compliance requirement — audit trails must be tamper-evident. Immutability is enforced at the storage layer via append-only write policies, and at the application layer by prohibiting update or delete operations on audit records.

### **ACID Transactions**

All writes to The product's core data stores — entity records, finding state, audit events — are ACID-compliant. Atomicity ensures that a compound operation (e.g. create a finding AND write its audit event) either fully succeeds or fully rolls back. Consistency ensures the data model invariants are never violated. Isolation ensures concurrent extraction events do not produce race conditions in the graph. Durability ensures committed records survive system failures.

ACID compliance is non-negotiable for a compliance platform: partial writes, inconsistent states, or lost records in a compliance context are not acceptable failure modes.

### **Idempotency & Eventual Consistency**

All worker node operations and event handlers are idempotent: processing the same event twice produces the same result as processing it once. This is critical in a distributed system where network failures can cause retries. Idempotency is enforced via event deduplication keys stored in the message bus and at each processing stage.

The graph view and analytics layer operate under eventual consistency: after a burst of file events (e.g. a large batch upload), the graph converges to the correct state as events are processed in order, but there is a brief window where the graph reflects a partially-updated state. This is acceptable and communicated clearly in the UX — real-time alerts fire immediately from the incremental scan, while the graph view shows the converged state with a visible freshness timestamp.

## **4.5 Event-Driven Architecture**

The product is built on an event-driven architecture. Storage events — file creation, modification, access change — are the primary signals that drive all downstream processing. This architecture decouples the worker node layer from the processing layer, enables horizontal scaling of individual components, and ensures that no single component failure causes data loss.

### **Event Flow**

The high-level event flow through the system (this is proposed, and it may be discarded completely or enhanced based on further conversation):

- Storage Connector worker node detects a file system event at the monitored storage location.

- worker node publishes a structured event to the Message Queue with event type, file reference, timestamp, and idempotency key.

- File Processing Service consumes the event, extracts text and metadata from the file, and publishes a FileProcessed event.

- Entity Extraction Service consumes the FileProcessed event, runs NER, resolves against existing Golden Records, and publishes an EntitiesExtracted event.

- Graph Update Service consumes the EntitiesExtracted event, updates nodes and edges in the graph database, and publishes a GraphUpdated event.

- Compliance Rule Engine consumes the GraphUpdated event, evaluates the updated graph region against active rules, and — where violations are found — publishes a FindingCreated event.

- Alert Service consumes FindingCreated events and dispatches notifications. Audit Service consumes all events and writes immutable records to the Central Audit Log.

| **Architecture Principle** | Every step in this pipeline produces an event and consumes an event. No component reaches directly into another component's data store. The message bus is the integration layer. |
| --- | --- |

### **Message Queue**

The message bus is the backbone of the event-driven architecture. It provides durable, ordered, at-least-once delivery of events between producers and consumers. Key properties:

- Durability: events are persisted to disk before acknowledgement. An worker node crash after publishing does not lose the event.

- Ordered delivery within partition: events for the same file are always processed in the order they were published, preventing race conditions between a FileCreated and a subsequent FileModified event on the same file.

- Consumer group isolation: each downstream service (extraction, graph update, compliance engine, audit) maintains an independent consumer offset, so a slow compliance engine does not block the extraction pipeline.

- Backpressure handling: during the initial full scan — when event volume is highest — the queue absorbs the burst and allows downstream consumers to process at their own rate without dropping events.

### **Dead Letter Queue (DLQ)**

Events that repeatedly fail processing — due to malformed file content, extraction errors, or transient infrastructure failures — are routed to a Dead Letter Queue after a configurable number of retries. The DLQ is monitored and surfaced in the Usage Dashboard. Administrators can inspect failed events, investigate root causes, and replay them once the issue is resolved. Events in the DLQ are never silently discarded — every failed event is accounted for.

### **Transactional Outbox Pattern**

Storage connector worker nodes face a classic distributed systems problem: they must write to the local database AND publish to the message queue atomically. A failure between these two operations would either create a database record with no corresponding event, or publish an event with no corresponding record — both are data integrity violations.

The product solves this with the Transactional Outbox pattern: the worker node writes the event to an outbox table in the same local database transaction as the file state record. A separate relay process reads from the outbox table and publishes to the message queue, marking records as published on success. This guarantees that a published event always has a corresponding database record, and that no event is ever published without being durably persisted first.

### **Circuit Breaker Pattern**

Storage connector worker nodes communicate with external storage APIs (Google Drive API, AWS S3 API, etc.) that may experience rate limits, outages, or degraded performance. A naive retry loop can amplify these failures by hammering an already-struggling API.

The product implements the Circuit Breaker pattern for all external storage API calls:

- Closed state (normal operation): requests pass through to the storage API. Failures are counted.

- Open state (triggered after failure threshold): requests fail immediately without calling the API. The worker node pauses polling for a configurable backoff period. An alert is raised in the Usage Dashboard.

- Half-open state (recovery probe): after the backoff period, a single probe request is sent. If it succeeds, the circuit resets to closed. If it fails, the circuit returns to open.

This pattern protects both The product's worker nodes and the customer's storage APIs from cascading failures, and ensures graceful degradation when external dependencies are unavailable.

## **4.6 Central Audit System**

The Central Audit System is a first-class architectural component of The product — not an afterthought or a logging layer. It captures every event that occurs on files, entities, findings, access changes, and remediation actions throughout the entire system workflow, with precise timestamps and actor attribution. It is the immutable record of everything that has happened in the system.

### **What the Audit System Captures**

| **Event Category** | **Detail Captured** |
| --- | --- |
| **File events** | File discovered, file processed, file content updated, file moved, file deleted, file shared, access permission changed — with timestamp, storage location, file identifier, actor (user or worker node), and event source. |
| **Entity events** | Entity extracted, Golden Record created, Golden Record updated, entity deduplicated, entity confidence scored, entity flagged for review — with timestamp, entity ID, source file, extraction model version. |
| **Compliance events** | Rule evaluated, finding created, finding acknowledged, finding resolved, finding marked as exception — with timestamp, rule ID, framework clause, actor, and justification. |
| **Remediation events** | Action proposed, action reviewed, action confirmed or rejected, action executed, exception created, exception expired — with timestamp, actor, action type, and before/after state. |
| **Query events** | Natural language query submitted, query result returned — with timestamp, actor, query text, and result summary. Supports accountability for who asked what about which entities. |
| **System events** | worker node deployed, storage location registered, crawl initiated, crawl completed, DLQ event routed, circuit breaker state changed — for operational traceability. |

### **Immutability & Integrity of the Audit Log**

Audit log records are append-only: no update or delete operation is permitted on any audit record after it is written. This is enforced at both the application layer (no delete endpoints exist for audit records) and the storage layer (append-only write policies on the audit log store). Each record includes a cryptographic hash of its content and a reference to the previous record's hash, forming a tamper-evident chain. Any modification to historical records would break the chain and be detectable.

### **Data Lineage via the Audit Log**

The Audit System is the primary mechanism for data lineage in The product. Given any entity, finding, or compliance event, an administrator can traverse the audit log to reconstruct the complete chain of custody: when the source file was first discovered, when the entity was first extracted from it, when it was added to the graph, when the rule that created this finding was first evaluated, and every subsequent action taken. This chain is exportable as part of the audit evidence package.

## **4.7 Security Architecture**

Security is not a feature layer applied on top of The product — it is embedded in the architecture from the ground up. The security model is built on Zero Trust principles, API-first design, and industry-standard authentication and authorization protocols.

### **Zero Trust Architecture**

The product assumes no implicit trust based on network location. Every request — whether from an worker node to the message queue, from the compliance engine to the graph database, or from a user's browser to the API — must be explicitly authenticated and authorized, regardless of whether it originates inside or outside the deployment boundary.

- No component trusts another by virtue of being on the same network or in the same VPC. All inter-service communication is authenticated.

- Least privilege access is enforced at every layer: worker nodes have read-only access to storage connectors, write access only to the outbox table, and no access to the compliance domain's data stores.

- All network traffic between components is encrypted in transit. There is no plaintext internal communication.

- Human user access is authenticated via OAuth 2.0 and verified on every request via JWT validation. Session tokens are short-lived with refresh rotation.

- Service-to-service communication within the service mesh is authenticated via mutual TLS (mTLS). A service cannot impersonate another service.

### **OAuth 2.0 & JWT**

All human user authentication uses OAuth 2.0, supporting integration with the customer's existing Identity Provider (Active Directory, Okta, Google Workspace) via OIDC. Upon successful authentication, users receive a short-lived JSON Web Token (JWT) containing their identity, roles, and permissions. Every API request is validated against this JWT.

Storage connector worker nodes authenticate to source storage systems (Google Drive API, AWS S3) using OAuth 2.0 service account credentials scoped to read-only access on registered storage locations. Credential rotation is automated and audited.

JWT claims govern access within The product: what storage locations a user can view, what entity types they can query, what compliance frameworks are in scope for their role. This claim-based authorization model means access control is enforced at the API layer, not in the UI — the API never returns data the caller is not authorized to see.

### **Service Mesh**

Inter-service communication within the The product deployment is managed via a service mesh. The service mesh provides:

- Mutual TLS (mTLS) for all inter-service traffic: every service proves its identity to every other service on every request. A compromised service cannot impersonate another.

- Traffic policy enforcement: the service mesh defines which services are permitted to communicate with which other services. The File Processing Service cannot directly call the Compliance Domain's API — the mesh enforces this boundary.

- Observability: distributed tracing, metrics, and access logs for all inter-service calls are collected by the mesh and surfaced in the Usage Dashboard. This provides operational visibility and is a supporting artifact for SOC 2 audit evidence.

- Circuit breaker integration: the service mesh enforces circuit breaker policies for inter-service calls, complementing the storage API circuit breakers in the worker node layer.

### **API-First Architecture**

Every capability in The product is exposed via a versioned, documented API before any UI is built on top of it. This API-first discipline has several consequences:

- All product features are accessible programmatically, enabling enterprise customers to integrate The product findings and events into their existing GRC tooling, SIEM systems, or ticketing workflows.

- The UI is a first-party API consumer, not a privileged layer with direct database access. If the API does not support an operation, the UI cannot perform it. This eliminates a class of security vulnerabilities where UI-only controls are bypassed.

- API versioning is enforced from day one. Breaking changes require a new API version. This protects integrations built by early customers as the product evolves.

- API documentation is generated from code and is always current. There is no manual documentation that can drift from the implementation.

## **4.8 Engineering Standards**

### **Test-Driven Development**

The product is built using Test-Driven Development as the default engineering practice. Tests are written before implementation code. This discipline is particularly important for a compliance platform, where the cost of a defect — an undetected entity, a misfired alert, a corrupted audit record — is measured in regulatory exposure, not user experience.

| **Test Layer** | **Scope & Purpose** |
| --- | --- |
| **Unit tests** | Every domain service, extraction model wrapper, rule engine clause, and utility function has comprehensive unit test coverage. Tests run on every commit in the CI pipeline and must pass before merge. |
| **Integration tests** | Each domain boundary — File Domain to Entity Domain, Entity Domain to Compliance Domain — has integration tests that verify event contracts and data flow across the boundary. These tests use real message queue and database infrastructure, not mocks. |
| **Contract tests** | The event schemas published between services are validated via contract tests. A producer cannot change an event schema in a way that breaks a consumer without the contract test failing first. This prevents silent breaking changes in the event-driven pipeline. |
| **End-to-end tests** | A suite of end-to-end tests simulate the full workflow: worker node detects file event → extraction → graph update → compliance rule evaluation → finding creation → audit log write. These tests run against a full deployment in a staging environment before any production release. |
| **Extraction quality tests** | NER model accuracy is measured automatically against labelled test datasets on every model update. A regression in precision or recall below defined thresholds blocks the release. |
| **Security tests** | Automated SAST, dependency vulnerability scanning, and OWASP-aligned API security tests run in the CI pipeline. JWT validation, OAuth flow correctness, and mTLS configuration are verified in the integration test suite. |

| **TDD Principle** | In a compliance platform, correctness is not a quality-of-life feature — it is the product. Test-Driven Development is the primary mechanism by which The product earns and maintains customer trust. |
| --- | --- |

# **5. User Experience**

The product operates across two architectural layers of interaction. The System of Record — the entity graph, compliance findings, audit log, and access metadata — is the authoritative data layer maintained by the backend. The System of Engagement is the set of interfaces through which users interact with that data: the graph view, dashboards, and natural language query interface. These two layers are deliberately separated: the System of Engagement reads from and writes to the System of Record exclusively via the versioned API, never directly.

## **5.1 Graph View**

The interactive graph view is one of The product's two core interface modes and is available from the initial release. It is the primary USP alongside the compliance dashboard. The graph renders the complete entity-location-relationship map of the organization's data estate using an Obsidian-style node visualization. As users apply filters, the graph progressively focuses on the relevant subgraph without losing context of the broader estate.

Node types: entities, files, storage locations, users, compliance flags. Edge types: entity occurs in file, file stored at location, user has access to file, entity related to entity, compliance status. The graph reflects the converged state of the entity graph with a visible freshness timestamp indicating when the last incremental scan was processed.

- Click any node to expand its relationships and see all connected entities, files, and access paths.

- Filter by entity type, storage location, compliance framework, access level, or date range.

- Highlight compliance violations — nodes and edges with open findings are visually flagged.

- Trace a specific entity across all files and locations it appears in.

- Export a subgraph view as a visual report for audit or review purposes.

## **5.2 Compliance & Analytics Dashboards**

- GRC Dashboard: Compliance posture by framework (SOC 2 first), open findings by severity, trend over time, audit-readiness score, and exportable evidence packages mapped to specific framework clauses.

- Access & Exposure Dashboard: Files with sensitive entities accessible outside intended groups, external sharing summary, and access-change events surfaced from incremental scans.

- Sustainability Dashboard: Storage consumption by location, duplicate and dormant file counts, projected cost of inaction, recommended cleanup actions.

- Usage Dashboard: Crawl coverage, worker node health, entity extraction confidence metrics, DLQ event counts, circuit breaker states, and query history.

## **5.3 Natural Language Querying**

Users interact with the entity graph in natural language. The locally hosted model is grounded in the graph and produces answers with traceable citations to specific files, nodes, and access records. All queries are logged in the Central Audit System.

- "How many files contain records for client Acme Corp, and which are accessible outside the account management team?"

- "What are my top five actions to reduce SOC 2 CC6 non-compliance by at least 30%?"

- "Which files containing personal health information have been accessed by users outside the clinical team in the last 90 days?"

- "Show me all files shared externally that contain financial account identifiers."

## **5.4 Remediation Workflows (Post-MVP)**

Remediation is not in scope for the initial MVP but is a defined part of the full product vision. When implemented, it will include a human-in-the-loop confirmation step for all consequential actions. No automated system can modify access, archive files, or take any action with external effects without explicit human approval. Every action, approval, rejection, and exception is written to the Central Audit Log.

- Finding detected → alert triggered to configured owner.

- Owner reviews finding in The product — full graph context, data lineage, framework clause, severity.

- Owner selects remediation action: revoke access, quarantine file, archive, notify team, or mark as exception.

- Human confirmation required before execution. No automated changes without approval.

- Exception handling: findings can be marked as documented exceptions with assigned owner, justification, and expiry date. Exceptions appear in audit exports.

- Full audit trail: every finding, review, action, approval, and exception written to the immutable Central Audit Log with timestamp and actor.

# **6. Compliance Framework Coverage**

Findings in The product are mapped to specific clauses in supported compliance frameworks, transforming a detection into an auditable compliance event with a framework citation. SOC 2 is the priority framework for the initial release.

| **Framework** | **Coverage Areas** | **Roadmap** |
| --- | --- | --- |
| **SOC 2 (MVP)** | Access control violations, sensitive data in unprotected storage, data availability and integrity, change management traceability, external sharing of confidential data | CC6, CC7, A1 — Initial release |
| **GDPR** | Data subject records in unprotected locations, cross-border data exposure, retention policy violations, right-to-erasure traceability | Art. 5, 17, 25, 32 — Phase 2 |
| **HIPAA** | PHI in non-covered storage, access by non-clinical staff, audit log requirements, minimum necessary standard | §164.308, §164.312, §164.514 — Phase 2 |
| **ISO 27001** | Asset inventory gaps, access control non-conformances, information classification violations | A.8, A.9, A.18 — Phase 2 |
| **PCI DSS** | Cardholder data in non-compliant storage, access outside defined cardholder data environment | Req. 3, 7, 10 — Phase 3 |

# **7. Market Analysis: MVP Scope Prioritization**

## **7.1 File Format Prioritization**

| **Format** | **Prevalence** | **Compliance Relevance** | **MVP Priority** |
| --- | --- | --- | --- |
| **PDF** | Very High | Contracts, policies, invoices, reports, audit evidence. Most common format for document sharing inside and outside organizations. | Priority 1 — MVP |
| **DOCX (Word)** | Very High | Contracts, HR documents, internal policies, correspondence. Primary authoring format for business prose containing narrative PII and legal content. | Priority 1 — MVP |
| **XLSX (Excel)** | Very High | Financial records, HR rosters, customer lists, billing data, CRM exports. De facto format for structured business data and bulk PII. | Priority 1 — MVP |
| **Plain Text / CSV** | High | Configuration files, data exports, logs. CSV widely used for CRM exports and system data transfers. | Priority 2 |
| **Email (.eml / .msg)** | High | Contain PII, attachments, and external sharing context. High compliance value but higher extraction complexity. | Priority 2 |
| **PPTX (PowerPoint)** | Medium | Executive presentations, sales decks, board materials. Lower data density than above formats. | Priority 3 |
| **Scanned docs (OCR)** | Medium | Signed contracts, legacy records, scanned invoices. High compliance value but requires OCR pipeline. | Priority 3 |

| **MVP Recommendation** | Launch with PDF, DOCX, and XLSX. These three formats cover the majority of compliance-sensitive content in SMB environments and are well-served by mature parsing libraries. Add plain text and CSV in the first post-MVP iteration. |
| --- | --- |

## **7.2 Cloud Storage Connector Prioritization**

| **Platform** | **Priority** | **Rationale** | **Roadmap** |
| --- | --- | --- | --- |
| **Google Drive** | Priority 1 — MVP | 31–47% file sharing market share. Dominant in SMB, professional services, and education. Well-documented API, straightforward permission model. | Launch connector |
| **AWS S3** | Priority 1 — MVP | Essential for SaaS companies and technical SMBs; covers self-hosted document stores and data exports. High compliance relevance for SOC 2 target buyers. | Launch connector |
| **SharePoint / OneDrive** | Priority 2 | Bundled with Microsoft 365, ~30–46% global office suite market. Highest-priority post-MVP connector given Microsoft 365 penetration. | First post-MVP |
| **Dropbox** | Priority 3 | 18–21% file sharing market share. Strong SMB penetration, simpler API. Natural expansion after Google Drive proves the pattern. | Phase 2 |
| **Box** | Priority 3 | ~13% market share. Strong in regulated industries (healthcare, finance, legal). Box's own compliance positioning means customers already understand the value proposition. | Phase 2 |
| **On-premises NAS** | Priority 4 | Important for manufacturing, legal, healthcare SMBs. Requires on-prem worker node deployment — distinct engineering effort from cloud connectors. | Phase 3 |
| **Endpoint machines** | Priority 4 | High compliance value but worker node deployment, update management, and endpoint performance constraints make this a distinct product motion. | Phase 3 |

| **MVP Recommendation** | Launch with Google Drive and AWS S3. SharePoint/OneDrive is the highest-priority post-MVP connector. Note: SMBs keep an average of 160 files containing sensitive data in cloud storage (ConnectBit 2024) — the compliance surface is already there. |
| --- | --- |



*The product  |  Product Ideation Document v1.3  |  Confidential*