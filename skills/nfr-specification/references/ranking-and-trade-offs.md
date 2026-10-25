# Ranking, the Utility Tree, the Conflict Check and the Architecture Handoff

Self-contained reference for the `nfr-specification` skill. Read it when ranking candidate scenarios, when checking them for conflicts, and before writing the Architecture Handoff.

Sources: Bass, Clements and Kazman, *Software Architecture in Practice* (4th ed.) for architecturally significant requirements, the utility tree and ATAM's vocabulary; Wiegers and Beatty, *Software Requirements* (3rd ed.) for ranking quality attributes and the attribute trade-off matrix; Richards and Ford, *Fundamentals of Software Architecture* for characteristics as competing forces.

---

## 1. Walk the characteristics

Before ranking, every characteristic gets one line in **Characteristics Considered**: kept (with the scenario IDs it produced) or declined (with a reason the user could disagree with). The list is ISO/IEC 25010 (2023) plus deployability:

| Characteristic | Prefix | Ask |
|---|---|---|
| Functional suitability | — | Declined by default: the FRD's fit criteria own it |
| Performance efficiency | PERF | Which user waits, at what peak, on what data? |
| Compatibility | COMPAT | Which external system must we exchange with or sit beside? |
| Interaction capability (usability) | USE | Which user class must succeed unaided, on what device, with what assistive technology? |
| Reliability | REL | What fails (node, zone, dependency), and what may be lost? |
| Security | SEC | Which attacker class (the FRD's disfavoured user classes first)? |
| Maintainability | MAINT | Which kind of change is expected often? |
| Flexibility (portability, scalability) | FLEX | What grows (users, tenants, data), and how fast? |
| Safety | SAFE | Can the product harm a person or property? |
| Deployability | DEPLOY | Can one part ship and roll back alone, with no manual step? |
| Obligations from business rules | OBL | Which BR-n requires this system to do or prove something measurable? |
| Platform DX (platform products only) | PDX | Can an engineer use the platform unaided? |

At lean, walk the top level only. At standard and enterprise, go into the relevant sub-characteristics (`./quality-attribute-scenarios.md` lists them).

IDs are `NFR-<PREFIX>-<nn>` (`NFR-REL-01`). Process targets are `PT-n`; trade-off points `TP-n`.

## 2. Rank

Wiegers and Beatty: do not try to specify every attribute; rank them and specify the few that matter. Bass ranks the **scenarios**, the unit that will be tested, on two scales:

| Rating | High | Medium | Low |
|---|---|---|---|
| **Business value** (how much it matters if missed) | A KR, a contract, a regulator or users' safety depends on it | Users notice and complain | Hardly anyone would notice |
| **Architectural impact** (how hard to achieve; how much it shapes the design) | Changes the structure: topology, data placement, redundancy, tenancy model | Needs specific design work in one part | Met by any reasonable design |

- **(H, H)**: the design must address it first.
- **Architectural impact H** (any value): an **architecturally significant requirement (ASR)**. It goes in the Architecture Handoff.
- **(L, L)**: one line, or drop it.
- A scenario rated **M or L on business value** but carrying an expensive target (99.99%) is the copy-paste target, caught by its own rating. Lower the target or find the business driver.

| Profile | Ranking shape |
|---|---|
| lean | An ordered list. Keep a scenario only if it changes a design decision (that is, its impact would be H); 3–8 survive |
| standard | A table: scenario, business value, architectural impact, rank |
| enterprise | A **utility tree**: utility → characteristic → refinement → concrete scenario leaves, each leaf rated (value, impact) |

Utility tree, written as an indented list so it reads in plain Markdown:

```
Utility
├── Reliability
│   ├── Availability
│   │   └── NFR-REL-01  zone loss in office hours → fail over, RTO 5 min  (H, H)
│   └── Recoverability
│       └── NFR-REL-02  region loss → restore in the second UK region, RPO 15 min  (H, H)
├── Security
│   └── Confidentiality
│       └── NFR-SEC-01  officer of council B requests council A's case → refused, logged  (H, M)
└── Performance efficiency
    └── Time behaviour
        └── NFR-PERF-01  checklist on slow GIS → P95 ≤ 4 s (Must)  (M, M)
```

**One stakeholder, honestly stated.** Bass's Quality Attribute Workshop has many stakeholders voting. Here the agent drafts and rates the scenarios and the user confirms the ratings at the gate. Say so in the artifact; do not present the ratings as a workshop result.

## 3. The conflict check

Richards and Ford: every architecture characteristic competes with others, so the architect needs the tensions up front, not mid-design. Wiegers and Beatty's **attribute trade-off matrix** does this at requirements time; Bass's ATAM finds **trade-off points** in a design later. At Ideate, record **candidate trade-off points**.

For each pair of kept scenarios rated H on either scale, ask: does meeting one make the other harder?

| Common pair | Why they pull apart |
|---|---|
| Availability with failover to another region **vs** data that must stay in one country (a BR-n) | The failover region must be inside the boundary, or failover is forbidden |
| Low latency **vs** encryption, audit logging or policy checks on every call | Each check adds time on the hot path |
| Tenant isolation (separate stores) **vs** cost per tenant or time to onboard | Isolation multiplies infrastructure |
| Fast recovery (low RTO/RPO) **vs** cost | Hot standby and synchronous replication cost more |
| Deployability (independent, frequent releases) **vs** a manual approval gate a BR-n requires | The gate adds wait time; the rule may allow an automated check instead |
| Usability (fewer steps) **vs** security (stronger authentication) | Each factor adds friction |
| Privacy of message content **vs** usefulness of the message | Less detail is safer and less useful |

Record each as:

| ID | Scenarios | Why they pull apart | Options open (not chosen) | Decided by |
|---|---|---|---|---|
| TP-1 | NFR-REL-02 × NFR-OBL-01 | Region failover vs UK-only processing (BR-5) | Second UK region; UK-only backup with longer RTO | `enterprise-architect` (ADR); the user if the RTO must be relaxed |

Do not resolve it here. A trade-off that changes cost or scope goes to the user; one that only changes the design goes to `enterprise-architect`, whose ADR names the attributes traded (`adr-authoring`).

## 4. Derived requirements

For each kept scenario ask what functional behaviour it implies (Wiegers): "block after 5 failed sign-ins" (security), "show a read-only banner while degraded" (reliability), "queue replies while the SMS provider is down" (compatibility). Send each to the FRD as a new FR (a change request if the FRD is approved) and list it under **Derived Requirements** with the FR it became.

## 5. The Architecture Handoff

Every ASR (architectural impact H) and every candidate trade-off point goes in. The handoff is a rule, not a fixed list of constraint types:

| NFR | Rating (value, impact) | Trade-off points | Tactic families that usually serve it (pointers only) |
|---|---|---|---|
| NFR-REL-01 | (H, H) | TP-1 | Redundancy and failover; health monitoring (heartbeat) |
| NFR-SEC-01 | (H, M) | — | Authorise every request against tenant; separate entities |

Tactic families come from Bass (availability: detect, recover, prevent faults; performance: control demand, manage resources; security: detect, resist, react, recover; modifiability: cohesion, coupling, deferred binding; deployability: manage the pipeline and the deployed system). They are hints. **Choosing a tactic is a Design decision**: the NFR stops at the response measure.

At enterprise, flag the top scenarios for a **lightweight architecture evaluation** at Design: `enterprise-architect` walks them against the first container diagram and ADRs and records risks, non-risks, sensitivity points and trade-off points.
