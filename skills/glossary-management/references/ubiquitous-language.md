# Canonical Ubiquitous Language

**Last updated:** 2026-07-23
**Maintained by:** glossary-management skill
**Rule:** Use every term exactly as defined here. Synonyms are not acceptable substitutes.

---

## Domain and DDD

| Term | Definition |
|---|---|
| **Active Record** | A Business Logic Design Pattern where an object per persisted row/table carries both data and simple CRUD-shaped behaviour, with no separation between the object's shape and the persistence schema and no enforced invariant spanning multiple objects. A middle rung between Transaction Script and Domain Model, appropriate for Supporting subdomains with moderate, mostly single-record logic. |
| **Aggregate** | A cluster of domain objects treated as a single unit for data changes. Has a root entity (Aggregate Root) that controls all access to internal objects. Invariants are enforced within aggregate boundaries. |
| **Aggregate Root** | The single entry point into an Aggregate. External objects hold references only to the Aggregate Root, never to internal entities. |
| **Anti-Corruption Layer (ACL)** | A translation layer that prevents concepts from one Bounded Context from polluting another. Used at integration boundaries between contexts with different models. |
| **Bounded Context** | An explicit boundary within which a Ubiquitous Language and a single domain model apply consistently. The boundary is enforced in code, team ownership, and deployment. |
| **Business Logic Design Pattern** | One of four implementation strategies for a subdomain's business logic — Transaction Script, Active Record, Domain Model, or Event-Sourced Domain Model — selected per Aggregate or use case based on the subdomain's classification and actual logic complexity, never applied uniformly across a whole Bounded Context by default. |
| **Canonical Data Model (CDM)** | A shared data model used to normalise information exchanged between Bounded Contexts at integration points. Prevents tight coupling between context-specific models. |
| **Client-Generated Identity** | An Aggregate Root's identity assigned by application code (typically a UUID) at construction time, before any persistence I/O, so a fully valid instance — ID included — exists prior to the first database write. The preferred default over Persistence-Generated Identity. |
| **Command** | An instruction to the system to perform an action that changes state. Commands are named in the imperative mood (e.g. `RegisterUser`, `ProcessPayment`). Commands may be rejected. |
| **Consistency Boundary** | The precise scope within which a True Invariant is atomically enforced. Distinct from Bounded Context (a linguistic/model scope) and narrower than "Aggregate" as a bare structural term — the boundary is defined by the invariant it protects, not the other way around. |
| **Context Map** | A document that shows all Bounded Contexts in a system and the relationships between them (e.g. Partnership, Customer/Supplier, Conformist, Anti-Corruption Layer, Open Host Service). |
| **Data Ownership** | The assignment of authoritative responsibility for a data entity to a specific Bounded Context. Only the owning context may write to that entity's master record. The same discipline applies recursively one layer down at the Aggregate level (see Aggregate Root). |
| **Domain** | A sphere of knowledge and activity that defines the problem space a software system addresses. |
| **Domain Event** | An immutable record of something significant that happened within a Bounded Context. Named in the past tense (e.g. `UserRegistered`, `PaymentProcessed`). Domain Events are facts — they cannot be changed. |
| **Domain Model** *(Business Logic Design Pattern sense — distinct from the general "domain model" usage elsewhere in this glossary and this repo)* | The full DDD tactical pattern set: Aggregates, Entities, Value Objects, invariants enforced by the Aggregate Root, isolated from the persistence schema. Reserved for Core Domain and complex Supporting subdomains where the modeling investment pays for itself. |
| **Entity** | A domain object defined by a thread of continuity and identity, tracked through change over time, rather than by its attribute values. Two Entities are equal only if their identities match, regardless of attribute differences. Whether a concept is modeled as an Entity or a Value Object is a per-Bounded-Context decision, not an intrinsic property of the concept. *Distinct from Clean Architecture's unrelated "Entities" ring (enterprise-wide business rules) — the two senses share a name but not a scope; disambiguate explicitly whenever both could plausibly apply.* |
| **Event Sourcing** | A persistence strategy in which an Aggregate's authoritative state is its append-only stream of past events, not a mutable current-state row. Current state is always a derived, rebuildable projection of that stream. Underlies the Event-Sourced Domain Model pattern. |
| **Event Store** | The append-only storage mechanism for an event-sourced Aggregate's event stream. Supports append-if-expected-version (the event-sourced equivalent of optimistic-concurrency compare-and-swap) and full-history read for replay. |
| **Event Upcasting** | A versioned, load-time transformation applied to an event read from an Event Store, converting an old-shape stored event into the shape current code expects, without ever rewriting the stored event itself. The schema-evolution discipline for permanently-stored internal events, distinct from Domain Event's additive/breaking-version-with-parallel-emission strategy for transient integration events. |
| **Event-Sourced Domain Model** | The Domain Model pattern with the Aggregate's state derived by replaying its own persisted event history rather than read from a current-state row. An additional, optional escalation above Domain Model, justified only by a specific temporal-query, retroactive-projection, or audit-as-record need — never a default even within the Core Domain. |
| **Factory** | An object or method responsible for encapsulating the logic of creating complex Aggregates or Value Objects, especially when construction must enforce invariants across multiple objects created together, or must choose among several concrete implementations. Distinguished from reconstitution (rebuilding an existing instance from storage), which uses a separate code path that does not re-run creation-time invariant checks or emit creation events. |
| **Persistence-Generated Identity** *(Surrogate Identity)* | An Aggregate Root's identity assigned by the database itself (an auto-increment/serial/identity column) only after the first successful insert, meaning no fully valid instance — ID included — exists until after that round trip. The disfavoured alternative to Client-Generated Identity, kept only where a specific reason requires it. |
| **Read Model** | In CQRS, the data structure optimised for query operations. May be denormalised or pre-computed. Separate from the Write Model. |
| **Repository** | An object that gives client code the illusion of an in-memory collection of Aggregates, hiding the underlying persistence mechanism. Exactly one Repository exists per Aggregate type, keyed by the Aggregate Root's identity; there is never a Repository for an internal Entity or Value Object. |
| **Shared Kernel** | A relationship between two Bounded Contexts that share a common subset of the domain model. Changes to the shared kernel require coordination between both context teams. |
| **Snapshot** *(event-sourcing sense — distinct from any infrastructure/backup sense)* | A periodically-persisted copy of an event-sourced Aggregate's derived current state, used purely to bound replay cost at load time. Never authoritative on its own; always regeneratable from the event stream. |
| **Specification** | An explicit, named, testable predicate object encapsulating a business rule, usable to test a candidate object against the rule, to select matching objects from a collection, and to express the rule as a first-class, reusable model element rather than scattered conditional logic. *Distinct from Specification by Example, an unrelated testing-methodology term already in this glossary's Testing and Quality section.* |
| **Subdomain** | A part of the overall Domain. May be a Core Domain (primary differentiator), Supporting Subdomain (necessary but not differentiating), or Generic Subdomain (commodity, often bought rather than built). |
| **Transaction Script** | A Business Logic Design Pattern where each use case is implemented as a single procedure operating directly against persistence, with no domain object model and no cross-object invariant enforcement. Appropriate for Generic subdomains and the simplest Supporting subdomains. |
| **True Invariant** | A business rule that must hold at every instant, has no acceptable compensating fix-up if briefly violated, and is not already enforced by an external system. The specific, narrower sense of "invariant" that alone justifies drawing a Consistency Boundary around it. |
| **Ubiquitous Language** | The shared, precise vocabulary used consistently by developers, domain experts, and all project artefacts within a Bounded Context. Must not drift between code, documents, and conversations. |
| **Value Object** | A domain object defined entirely by its attribute values, with no identity of its own. Two Value Objects with identical attributes are interchangeable and considered equal. Value Objects are immutable — a change is modeled as replacement, not mutation. Preferred over Entity wherever identity does not need to be tracked, due to the lower lifecycle-management overhead. |
| **Write Model** | In CQRS, the model responsible for processing commands, enforcing business rules, and producing Domain Events. Separate from the Read Model. |

---

## Architecture Decisions

| Term | Definition |
|---|---|
| **Architecture Characteristic** | An "-ility" (availability, scalability, consistency, etc.) that has structural design impact and is critical or important to a system's success — distinct from a merely domain-specific or cosmetic quality. Architecture Characteristics compete with each other; every Architecture Decision trades some off against others. |
| **Architecture Decision** | A specific, concrete, point-in-time choice made for a particular system in a particular context, recorded as an ADR. Superseded when circumstances change — never edited in place. Distinct from an Architecture Principle, which is durable and general. |
| **Architecture Decision Record (ADR)** | A short document (Michael Nygard) capturing one significant Architecture Decision: the Context that made it necessary, the Options Considered, the Decision, and the Consequences (positive and negative). Immutable once Accepted except for status-line changes; changes require a superseding ADR. |
| **Architecture Principle** | Durable, general guidance that many future Architecture Decisions cite (e.g., "prefer asynchronous communication across Bounded Contexts") — as distinct from a single Architecture Decision, which is specific and point-in-time. Revised directly as understanding improves, not superseded. |

---

## Design Principles

| Term | Definition |
|---|---|
| **API-First Design** | The practice of defining an API contract before implementing either the provider or the consumer. The contract is the single source of truth for both sides. |
| **API Gateway** | A single entry point that routes, authenticates, rate-limits, and governs access to backend services. Consumers interact with the Gateway, not individual services. |
| **Backward Compatibility** | A guarantee that newer versions of an API or contract do not break existing consumers. Breaking changes require a major version increment and a migration path. |
| **Chain of Responsibility** | A design pattern where a request passes through a chain of handlers, each deciding to process it or pass it to the next handler. |
| **Consumer-Driven Contract** | A contract testing approach where the consumer of an API defines the expectations (the contract) it holds of the provider. The provider must satisfy all consumer contracts. |
| **Contract-First Design** | The practice of defining integration contracts (API schemas, event schemas, message schemas) before writing any implementation code. |
| **CQRS (Command Query Responsibility Segregation)** | An architectural pattern that separates the Write Model (commands that change state) from the Read Model (queries that return state). The two models may use different data stores. |
| **Don't Repeat Yourself (DRY)** | Every piece of knowledge must have a single, unambiguous, authoritative representation in the system. |
| **Model-View-Controller (MVC)** | A pattern that separates an application into Model (data and business logic), View (presentation), and Controller (input handling). |
| **Separation of Concerns** | The principle of dividing a program into distinct sections, each addressing a separate concern. Changes to one concern should not require changes to others. |
| **Single Responsibility Principle (SRP)** | Every module, class, or function should have exactly one reason to change. |
| **SOLID** | Five object-oriented design principles: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion. |

---

## Event-Driven and Distributed

| Term | Definition |
|---|---|
| **Change Data Capture (CDC)** | A technique for detecting and capturing row-level changes in a database and publishing them as an ordered event stream to downstream consumers. |
| **Circuit Breaker** | A resilience pattern that detects repeated failures when calling a downstream service and temporarily stops calling it (opens the circuit) to prevent cascading failures. Has three states: Closed (normal), Open (failing), Half-Open (testing recovery). |
| **Dead Letter Queue (DLQ)** | A queue that receives messages that have failed processing after exhausting all retry attempts. Used for manual inspection, alerting, and eventual remediation. |
| **Event Choreography** | An integration style where services communicate by publishing and subscribing to Domain Events. No central orchestrator. Each service decides how to react to events it receives. |
| **Event Modeling** | A structured approach for designing event-driven systems by mapping out events, commands, read models, and the temporal sequence of a business process. |
| **Event-Oriented Architecture** | An architectural style where the primary integration mechanism between services is the publication and consumption of Domain Events. |
| **Event Storming** | A collaborative, workshop-based technique for rapidly exploring complex business domains by mapping Domain Events on a timeline, then discovering commands, aggregates, and bounded contexts. |
| **Eventual Consistency** | A consistency model in distributed systems where, given no new updates, all nodes will eventually converge to the same state. Immediate consistency is not guaranteed. |
| **Idempotency** | The property of an operation that produces the same result regardless of how many times it is executed with the same input. All event consumers and API endpoints that change state must be idempotent. |
| **Immutable Events** | Domain Events cannot be modified after they have been published. They are an append-only, permanent record of what happened. |
| **Rate Limiting** | A control mechanism that restricts how many requests a client can make to a service within a defined time window. |
| **Retry and Backoff** | A resilience pattern that retries a failed operation after a delay. The delay increases between retries (exponential backoff) to avoid overwhelming a recovering system. |
| **Throttling** | A mechanism that reduces the rate at which a service processes requests, typically to protect downstream dependencies or manage resource consumption. |
| **Transactional Outbox** | A pattern for reliably publishing Domain Events alongside a database write in a single atomic transaction. An outbox table in the same database stores pending events; a separate process publishes them to the message broker, guaranteeing at-least-once delivery. |

---

## Data Lifecycle

| Term | Definition |
|---|---|
| **Audit Trail** | An immutable, chronological record of all actions and state changes related to a data entity. Used for accountability, compliance, and non-repudiation. Must be append-only. |
| **Data Classification** | The process of categorising data assets by sensitivity level, regulatory scope, and handling requirements (e.g. Public, Internal, Confidential, Restricted). |
| **Data Lifecycle Management** | The governance of data from creation through archival and deletion, in accordance with retention policies, regulatory requirements, and business rules. |
| **Data Lineage** | The documented path of a data element from its origin, through all transformations, to its current state. Enables impact analysis and compliance verification. |
| **Data Provenance** | The documented origin of a piece of data — who created it, when, and how — along with the history of its custody and modifications. |
| **Data Retention Policy** | The rules governing how long data must be kept and when it must be deleted or archived, based on regulatory requirements and business need. |
| **Data Sovereignty** | The principle that data is subject to the laws and governance structures of the country or jurisdiction in which it is collected or stored. |
| **Soft Delete** | A deletion pattern where records are marked as deleted (e.g. `deleted_at` timestamp) rather than physically removed from the database. Supports audit trails and recovery. |

---

## Reliability and Operations

| Term | Definition |
|---|---|
| **Business Continuity** | The capability of an organisation to maintain essential functions during and after a disaster or disruption. |
| **Capacity Planning** | The process of determining the computing resources required to meet current and future demand at acceptable performance levels. |
| **Disaster Recovery** | The documented process for restoring systems and data after a catastrophic failure. Includes Recovery Time Objective (RTO) and Recovery Point Objective (RPO). |
| **Distributed Tracing** | A technique for tracking a request as it propagates through multiple services in a distributed system, correlating logs and metrics across service boundaries using a Trace ID. |
| **Fault Tolerance** | The ability of a system to continue operating correctly in the presence of component failures. |
| **Graceful Degradation** | A resilience approach where a system continues to operate at reduced capacity or functionality when components fail, rather than failing completely. |
| **Health Check** | An endpoint or probe that reports the operational status of a service, used by orchestration platforms and load balancers to route traffic only to healthy instances. |
| **High Availability** | A design characteristic of a system that ensures an agreed level of operational performance (uptime) for a higher-than-normal period. |
| **Load Balancing** | The distribution of incoming requests across multiple service instances to avoid overloading any single instance and to improve availability. |
| **Logging** | The structured recording of discrete events that occur within a system. Logs must be structured (e.g. JSON), correlated with Trace IDs, and never contain secrets. |
| **Metrics** | Numeric measurements of system behaviour over time (e.g. request rate, error rate, latency). Used for alerting, dashboards, and SLO tracking. |
| **Monitoring** | The continuous collection and analysis of Metrics, Logs, and Traces to detect and respond to problems in a system. |
| **Observability** | The degree to which the internal state of a system can be inferred from its external outputs (Metrics, Logs, Traces). A system is observable if it can be diagnosed without deploying new code. |
| **Resilience Engineering** | The practice of designing systems to anticipate, withstand, recover from, and adapt to adverse conditions. |
| **Service Level Agreement (SLA)** | A formal contract between a service provider and a customer specifying the expected service level, including uptime guarantees, penalties for breach, and support commitments. |
| **Service Level Indicator (SLI)** | A quantitative measure of the level of service being provided (e.g. request success rate, latency at the 99th percentile). |
| **Service Level Objective (SLO)** | A target value or range for an SLI (e.g. 99.9% of requests succeed within 200ms). SLOs are the internal target; SLAs are the external commitment. |
| **Vertical Scalability** | Increasing the capacity of a single node (more CPU, RAM) rather than adding more nodes. |

---

## Security and Compliance

| Term | Definition |
|---|---|
| **Attribute-Based Access Control (ABAC)** | An authorisation model where access decisions are made by evaluating policies against attributes of the user, the resource, and the environment. More expressive than role-based access control. |
| **Auditability** | The property of a system that allows all significant actions and decisions to be reconstructed after the fact from immutable records. |
| **Authentication** | The process of verifying the identity of a user or system. |
| **Authorisation** | The process of determining whether an authenticated user or system has permission to perform a specific action on a specific resource. |
| **Compliance as Code** | The practice of encoding compliance requirements (e.g. SOC 2 controls) as automated, executable tests and policies rather than manual checklists. |
| **Encryption at Rest** | The encryption of stored data so that it cannot be read if the storage medium is accessed without authorisation. |
| **Encryption in Transit** | The encryption of data as it moves between systems, typically using TLS, to prevent interception and tampering. |
| **Key Management** | The governance and operational procedures for generating, storing, distributing, rotating, and revoking cryptographic keys. |
| **Non-Repudiation** | The guarantee that a party cannot deny having performed an action. Achieved through audit trails, digital signatures, and authenticated event records. |
| **Privacy by Design** | An approach that embeds privacy protections into the design of systems and processes from the outset, rather than adding them as an afterthought. |
| **Principle of Least Privilege** | Every user, process, and service should have only the minimum permissions necessary to perform its intended function. |
| **Secrets Management** | The secure storage, distribution, rotation, and revocation of credentials, API keys, certificates, and other sensitive configuration values. Secrets must never be stored in source control. |
| **Security by Design** | The practice of incorporating security requirements and threat modelling into the design phase of a system, before any implementation begins. |
| **Zero Trust Architecture** | A security model that assumes no user, device, or network segment is inherently trustworthy. Every request must be authenticated and authorised regardless of its origin. |

---

## Testing and Quality

| Term | Definition |
|---|---|
| **Acceptance Test-Driven Development (ATDD)** | A practice where acceptance criteria are derived collaboratively from concrete worked examples *before* implementation (see Three Amigos), becoming the team's agreed definition of "done" for a story. Distinct from Acceptance Testing (below) — ATDD is a pre-code derivation practice; Acceptance Testing is post-deployment execution. This repo's `acceptance-criteria` + `bdd-feature-file` pairing is an ATDD practice in substance. |
| **Acceptance Testing** | Tests that verify a system meets the business requirements agreed with stakeholders, executed against a deployed system. Distinct from Acceptance Test-Driven Development (ATDD) — this term describes running already-agreed tests post-deployment, not deriving them. |
| **Behavior-Driven Development (BDD)** | A methodology that defines system behavior using human-readable specifications (Given/When/Then scenarios) before implementation. Specifications become executable tests. |
| **Chaos Testing** | A testing discipline that deliberately introduces failures (network partitions, service crashes, resource exhaustion) into a system to verify it remains resilient. |
| **Component Testing** | Tests that verify a single service or component in isolation, using test doubles for its dependencies. |
| **Consumer-Driven Contract Testing** | See Consumer-Driven Contract in Design Principles. The test implementation of that practice. |
| **Contract Testing** | Tests that verify the interactions between a consumer and a provider conform to a shared contract. Prevents integration failures caused by API changes. |
| **Continuous Testing** | The practice of executing automated tests at every stage of the delivery pipeline to provide immediate feedback on code quality. |
| **End-to-End Testing (E2E)** | Tests that exercise a complete user journey through the full system stack, from the UI to the database and back. |
| **Integration Testing** | Tests that verify two or more components work correctly together. Typically use real (or containerised) dependencies rather than mocks. |
| **Load Testing** | Tests that verify a system can handle the expected peak volume of traffic without degradation. |
| **Mutation Testing** | A technique that introduces small deliberate defects (mutations) into source code and verifies that the test suite detects them. Measures the quality of tests, not just coverage. |
| **Performance Testing** | Tests that verify a system meets its response time, throughput, and resource consumption requirements under defined load conditions. |
| **Regression Testing** | The re-execution of existing test suites after a change to verify that previously working functionality has not been broken. |
| **Security Testing** | Tests that verify a system's resistance to known attack vectors, including injection, authentication bypass, authorisation flaws, and insecure data handling. |
| **Shift Left Testing** | The practice of performing testing activities as early as possible in the development lifecycle, starting at requirements definition rather than after implementation. |
| **Specification by Example** | A technique for defining system behaviour through concrete examples agreed with domain experts, which become the basis for automated acceptance tests. |
| **Stress Testing** | Tests that push a system beyond its normal operating limits to determine its breaking point and recovery behaviour. |
| **Test-Driven Development (TDD)** | A methodology where tests are written before implementation code. The cycle is: write a failing test, write the minimum code to pass it, refactor. |
| **Test Fixture** | A fixed set of data or state established before tests run, ensuring tests are reproducible and independent of each other. |
| **Test Pyramid** | A model that guides the proportion of test types: many unit tests at the base, fewer integration tests in the middle, fewest E2E tests at the top. |
| **Three Amigos** | A workshop practice bringing together business, development, and testing perspectives (played solo by a single agent when no live multi-role team exists) to collaboratively derive concrete examples and acceptance criteria before a story is estimated or built. See Acceptance Test-Driven Development (ATDD), Specification by Example. |
| **Unit Testing** | Tests that verify a single unit of code (function, method, class) in complete isolation from all dependencies. |

---

## Delivery and Platform

| Term | Definition |
|---|---|
| **Blue-Green Deployment** | A deployment strategy that maintains two identical environments (Blue = live, Green = new version). Traffic is switched to Green once it passes verification. Enables zero-downtime releases and instant rollback. |
| **Canary Deployment** | A deployment strategy that routes a small percentage of production traffic to a new version before full rollout. Allows monitoring for issues before they affect all users. |
| **Configuration as Code** | The practice of managing all application configuration (environment variables, feature flags, runtime parameters) in version-controlled files, not through manual system changes. |
| **Continuous Delivery** | A practice where every change that passes automated tests is in a deployable state. Deployment to production remains a manual decision. |
| **Continuous Deployment** | A practice where every change that passes automated tests is automatically deployed to production without manual intervention. |
| **Continuous Integration (CI)** | A practice where developers integrate code changes into a shared branch frequently, with each integration verified by an automated build and test run. |
| **Developer Experience (DX)** | The overall experience a developer has when using tools, APIs, and platforms. Includes setup time, documentation quality, feedback speed, and reliability. |
| **Environment Parity** | The principle that development, staging, and production environments are as similar as possible to prevent environment-specific bugs. |
| **Feature Flags** | Runtime toggles that enable or disable functionality without redeployment. Enable progressive delivery, A/B testing, and instant rollback. |
| **GitOps** | An operational model where Git is the single source of truth for both application code and infrastructure configuration. Changes are applied by automated systems reconciling actual state with declared state in Git. |
| **Helm Chart** | A package of pre-configured Kubernetes resource definitions that can be deployed and managed as a versioned unit. |
| **Immutable Infrastructure** | An approach where infrastructure components are never modified after deployment. Changes are made by replacing components with new versions. |
| **Infrastructure as Code (IaC)** | The practice of managing and provisioning infrastructure through machine-readable configuration files rather than manual processes. |
| **Internal Developer Platform (IDP)** | A self-service platform that provides developers with standardised tools, services, and workflows, reducing cognitive load and enabling team autonomy. |
| **OpenTofu Module** | A reusable, versioned Infrastructure as Code unit written in OpenTofu (open-source Terraform fork) that encapsulates a set of infrastructure resources. |
| **Pipeline of Pipelines** | A deployment orchestration pattern where a top-level pipeline triggers and coordinates child pipelines for individual services or components. |
| **Platform Engineering** | The practice of designing and building toolchains and workflows that enable self-service capabilities for software engineering organisations. |
| **Progressive Delivery** | A deployment strategy that gradually exposes new features or versions to users in controlled increments, using feature flags, canary deployments, or ring-based rollouts. |

---

## Product and Discovery

| Term | Definition |
|---|---|
| **Domain Storytelling** | A collaborative technique where domain experts narrate their work as stories using a pictographic language, helping teams understand workflows and discover domain concepts. |
| **Example Mapping** | A structured workshop technique for breaking down user stories into concrete examples, identifying rules, and surfacing questions before development begins. |
| **Impact Mapping** | A strategic planning technique that maps goals to actors, impacts, and deliverables, ensuring all work traces back to a measurable business goal. |
| **Jobs To Be Done (JTBD)** | A framework for understanding what outcome a customer is trying to achieve (the "job") when they use a product, independent of the solution. |
| **North Star Metric** | A single metric that best captures the core value a product delivers to customers. Used to align all product decisions toward a common outcome. |
| **OKRs (Objectives and Key Results)** | A goal-setting framework that pairs a qualitative Objective with measurable Key Results. Used to align and focus effort at organisational and team levels. |
| **Outcome-Driven Development** | A product development approach that prioritises measurable customer and business outcomes over feature delivery. |
| **Product Discovery** | The set of activities used to identify and validate what to build before committing to building it. Reduces the risk of building the wrong thing. |
| **Product Metrics** | Quantitative measurements of product performance against defined outcomes (e.g. activation rate, retention, NPS). |
| **Product Validation** | The process of testing assumptions about user needs, market fit, and solution viability before full investment in development. |
| **User Story Mapping** | A product planning technique that organises user stories as a two-dimensional map: a horizontal narrative of the user journey and vertical slices of increasing detail. Used to sequence delivery and identify MVP scope. |
| **Value Stream Mapping** | A lean technique for visualising the complete flow of steps required to deliver value to a customer, from concept to production. Used to identify and eliminate waste. |
