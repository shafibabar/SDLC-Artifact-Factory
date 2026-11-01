# Quality-Attribute Scenarios: Format, Targets and the General-Scenario Library

Self-contained reference for the `nfr-specification` skill. Read it before drafting the first scenario of an NFR specification, and whenever a characteristic's typical stimuli, environments or response measures are unclear.

Sources: Bass, Clements and Kazman, *Software Architecture in Practice* (4th ed.) for the scenario and general scenarios; Wiegers and Beatty, *Software Requirements* (3rd ed.) for Planguage, which they adopt from Tom Gilb; Fournier and Nowland, *Platform Engineering* for the Platform DX scenarios.

---

## Why a fixed shape

Bass names two faults in how qualities are usually stated. An attribute name alone ("the system must be modifiable") cannot be tested, because every system is modifiable with respect to some changes and not others. And the communities use different words for the same thing (an "event" in performance is an "attack" in security and a "failure" in availability). The quality-attribute scenario fixes both: six parts, the same for every characteristic.

| Part | Question | Typical values |
|---|---|---|
| **Source of stimulus** | Who or what causes it? | End users (how many, which class), an attacker (which class), an internal component, the hardware or cloud zone, a developer, an operator |
| **Stimulus** | What arrives? | A request, a burst, a crash, an omission, an attack, a change request, a new release |
| **Environment** | Under what conditions? | Normal operation, peak (when, how big), degraded (one node or zone lost), startup, development time, during a deploy |
| **Artifact** (the affected part) | Which part of the system? | The whole system, one service, an API, a data store, the user interface, the deployment pipeline |
| **Response** | What does the system do? | Processes it, detects and masks the fault, degrades gracefully, blocks and logs, makes the change without side effects |
| **Response measure** | How is the response judged? | A latency percentile, throughput, time to detect, time to recover (RTO), data lost (RPO), share of attacks blocked, effort in person-days, task success rate |

"Artifact" here means **the part of the system affected**, not a document the plugin produces. Templates label the column "Affected part" to avoid the clash. Likewise, always say *quality-attribute scenario*: a bare "scenario" is a Gherkin `Scenario` in this plugin.

**General vs concrete.** A *general scenario* lists the possible values of each part for one characteristic (the library below). A *concrete scenario* is the instance written for one product. Pick values from the library, then make each part specific to the product's users, load and parts.

**Short form (lean, and M/L-rated scenarios at standard).** Stimulus + environment + response measure, written as one sentence: "When 30 members open the tool list on a Saturday morning (environment) on a phone over the workshop's 4G, the list shows within 3 s at P90 (Must)." The source and affected part are implied; the environment is never dropped.

---

## Targets: Planguage inside the response measure

The scenario says *what* is measured under *what* conditions; Planguage says *how good is good enough*.

| Keyword | Meaning | Profile |
|---|---|---|
| **Scale** | The unit (ms at P95; minutes of downtime per incident; % of tasks completed unaided) | All |
| **Meter** | How it is measured (load test on staging with production-sized data; failover drill; moderated usability test with 5 users) | All, as the Verification column |
| **Must** | The minimum acceptable. Below it, the release fails | lean, standard, enterprise |
| **Plan** | The target the design aims at | standard, enterprise |
| **Stretch** | The ambition if it is cheap to reach; never a release gate | enterprise |
| **Wish** | Stated by someone but not funded; record it, don't design for it | optional |

Write it as: `P95 ≤ 800 ms (Must), ≤ 400 ms (Plan), ≤ 250 ms (Stretch)`. Planguage *Must* is a threshold, **not** a MoSCoW *Must*: the two never share a column.

**Where a number comes from.** Every Plan value names its business driver: a KR the path serves, a contractual SLA, a buyer's table-stakes expectation (`competitive-analysis`), a regulator, or a measured baseline. A number the user gave ("99.9%") is a candidate: ask what it protects. If nobody can say, set the Must from the context and record the user's number as a Wish.

**Percentiles, not averages.** Latency is P50 / P95 / P99 with the load that produces it. An average is acceptable only for throughput.

**Each nine costs.** 99.9% allows about 8.8 hours of downtime a year; 99.99% about 53 minutes; 99.999% about 5 minutes. A target used only in office hours can be stated over those hours.

---

## Availability as failure scenarios

An uptime percentage alone says nothing about what fails or how the system recovers. Write availability (ISO/IEC 25010: reliability → availability, fault tolerance, recoverability) as failure scenarios:

| Part | Values |
|---|---|
| Source | Hardware, a cloud zone or region, a dependency (payment provider, SMS gateway, a council's GIS), a bad deploy |
| Stimulus | Crash, omission (no response), slow response, wrong response |
| Environment | Normal operation; peak; during a deploy; with one zone already lost |
| Response | Detect, notify, mask (fail over, retry, queue), degrade (read-only, cached), recover |
| Response measure | Time to detect; time to recover (**RTO**); data lost (**RPO**); requests failed during the event; uptime over a stated window as one measure among them |

Time to restore after an incident belongs here, as a recovery measure, not in a separate delivery category. `slo-definition` (Deploy) later formalises the uptime and latency measures as SLIs and SLOs with error budgets; do not write SLIs or burn-rate alerts in the NFR.

---

## General-scenario library

One table per characteristic of ISO/IEC 25010 (2023 names; 2011 names in brackets), plus deployability from Bass. Sub-characteristic names follow the research file and should be checked against the published standard before being quoted; use the names, not the standard's text (it is a paid document).

### Performance efficiency — time behaviour, resource utilisation, capacity

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| N users of a class; a batch job; an integration | Requests at a stated rate; a burst; a large upload | Normal; daily peak (when, how many); production-sized data | Processed; queued; shed with a clear message | Latency P50/P95/P99; throughput per second or minute; CPU or memory at peak; maximum users or records before the measure is missed |

### Compatibility — co-existence, interoperability

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| An external system (SMS provider, GIS, identity provider, portal) | Exchanges data; changes its version; is slow | Normal; the other system degraded | Exchange succeeds; old and new versions both work; our side keeps working | Share of exchanges succeeding; versions supported; behaviour when the other side is down |

### Interaction capability (usability) — learnability, operability, user error protection, accessibility (2023: inclusivity, user assistance), self-descriptiveness

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| A first-time user of a class; an expert; a user with a screen reader | Tries a task; makes a mistake | First use, unaided; on a phone; on assistive technology | Completes it; is warned and can undo | Task success rate unaided; time on task; errors per task; conformance level (e.g. WCAG 2.2 AA) |

### Reliability — faultlessness (maturity), availability, fault tolerance, recoverability

See *Availability as failure scenarios* above.

### Security — confidentiality, integrity, non-repudiation, accountability, authenticity, resistance

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| A named attacker class: an outsider, a user of another tenant (a disfavoured user class from the FRD), an insider with stolen credentials | Tries to read, change or deny an action; brute-forces sign-in | Normal operation; after a credential leak | Blocks, logs, alerts, revokes; proves who did what | Share of attempts blocked; time to detect; time to revoke; audit completeness |

Disfavoured user classes in the FRD are the best source of security scenarios: each one is an attacker class somebody already named.

### Maintainability — modularity, reusability, analysability, modifiability, testability

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| A developer; an operator | A change request of a stated kind (new tenant rule, new report); an incident to diagnose | Development time; a production incident | Change made without touching other parts; cause found | Effort (person-days) or number of modules touched; time to diagnose |

Test coverage and CI duration are not here: they describe how the team works, so they are process targets.

### Flexibility (portability) — adaptability, scalability, installability, replaceability

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| Growth in users, tenants or data; a new environment | Load doubles; a new tenant joins; moves to another cloud or region | Normal operation; onboarding day | Absorbs it by adding capacity; installs unaided | Capacity added per node; time to onboard a tenant; effort to move |

### Safety — operational constraint, risk identification, fail safe, hazard warning, safe integration

Considered where the product can harm people or property (clinical, vehicles, industrial, staffing levels). A safety scenario names the hazard, the unsafe state to avoid, and the time to reach a safe state. Most business software declines it with a reason.

### Functional suitability — completeness, correctness, appropriateness

Declined by default: the FRD's fit criteria own it.

### Deployability (Bass, 4th ed.; not a 25010 characteristic)

| Source | Stimulus | Environment | Response | Response measure |
|---|---|---|---|---|
| A developer or the pipeline | A fix or new increment is ready | Normal operation; peak; one service at a time | Deployed with no manual step and no downtime for other services; rolled back if it fails | Time from ready to running; downtime during deploy; time to roll back; services affected |

Deployability is the product property the architecture must have. How *often* the team chooses to deploy, and the share of deployments that fail, are process targets, owned by `dora-metrics`.

---

## Platform DX: when the product is an internal platform

When the artifact specifies a platform whose users are engineers (an internal developer platform, a CI/CD pipeline offered to product teams), its interaction capability is developer experience. Fournier and Nowland (*Platform Engineering*) give the measures; use the `NFR-PDX` prefix and keep them out of ordinary product specifications. `platform-engineering-design` owns the DX measurement cadence.

| Scenario | Short form |
|---|---|
| Time to first deploy | A new engineer, using only the golden path and its docs, deploys a service to a non-production environment within 1 working day (Must), without help from the platform team |
| Self-service coverage | Of the enumerated common operations (create a service, provision a database, rotate a secret, view logs, roll back), at least 90% (Plan) need no ticket |
| Exception rate | Requests to leave the golden path trend down quarter on quarter after adoption |
