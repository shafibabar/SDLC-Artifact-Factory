# Example 2 — Standard: three contexts where "Course" means three things, and a team-based split rejected

Self-contained. **Coursebridge** is a platform where professional bodies publish courses, run cohorts and award certificates, at the **standard** profile. The Big Picture (agent-run), the subdomain classification and the language documents exist.

## Input

> **User:** "Our two developers split it as Frontend and Backend, so let's make those the two contexts. Simple."

## Working it

- **Teams don't make contexts.** Frontend and Backend share every word; that's a technical layer, not a model boundary. And the product is agent-built, so the team axis barely applies.
- **Where does the language change?** The term divergence table (from the language documents and the Big Picture):

| Term | Catalogue | Enrolment | Certification |
|---|---|---|---|
| Course | A published description with modules and a price | A cohort with a start date and seats | The set of assessments leading to a certificate |
| Learner | — | A person holding a seat | A candidate with an assessment record |

- **Confirmed by who writes what:** only Catalogue writes listings and prices; only Enrolment writes cohorts and seats; only Certification writes assessments and certificates.
- **Big Picture hints agree:** pivotal events `CoursePublished` and `CohortClosed` sit at the two lines.
- **Size:** three contexts, not seven; Certification is Core and least settled, so it stays wide, with "Proctoring" recorded as a candidate split.

## Output — the reply, and `artifacts/coursebridge/design/context-map.md` (extract)

> I wouldn't split by Frontend and Backend: both halves use the same words for the same things, so that's a technical layer, not a model boundary. The real lines are where "Course" changes meaning. To the catalogue it's a listing with a price; to enrolment it's a cohort with seats; to certification it's the assessments that lead to a certificate. That gives three contexts. Each is confirmed by who writes which records, and by the two turning points on the Event Storming wall. Which services to run is a later step, in the architecture.

````markdown
---
name: context-map
product: coursebridge
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-06-17
summary: Coursebridge has three contexts (Catalogue, Enrolment, Certification) split where "Course" and "Learner" change meaning; team-based split rejected.
profile: standard
mode: agent-run
traces-to: [design/subdomain-classification.md, design/event-storming/big-picture.md, design/catalogue/ubiquitous-language.md, design/enrolment/ubiquitous-language.md, design/certification/ubiquitous-language.md]
---

# Context Map: Coursebridge

## Contexts

### Catalogue

| Field | Value |
|---|---|
| **Responsibility** | Publishes course listings and their prices |
| **Subdomain(s)** | Course publishing (Supporting) |
| **Boundary evidence** | "Course" means a listing here, a cohort in Enrolment (language documents); pivotal event CoursePublished; only Catalogue writes listings and prices |
| **Language** | `design/catalogue/ubiquitous-language.md` |
| **Owns (Aggregates)** | Course Listing, Price |
| **Publishes** | CoursePublished, PriceChanged |
| **Consumes** | — |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | none |

### Enrolment

| Field | Value |
|---|---|
| **Responsibility** | Runs cohorts and fills their seats |
| **Subdomain(s)** | Cohort enrolment (Supporting) |
| **Boundary evidence** | "Course" means a cohort here; "Learner" means a seat-holder; pivotal events CoursePublished and CohortClosed bound it; only Enrolment writes cohorts and seats |
| **Language** | `design/enrolment/ubiquitous-language.md` |
| **Owns (Aggregates)** | Cohort, Seat |
| **Publishes** | SeatTaken, CohortClosed |
| **Consumes** | CoursePublished (Catalogue) |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | none |

### Certification

| Field | Value |
|---|---|
| **Responsibility** | Assesses candidates and awards certificates |
| **Subdomain(s)** | Assessment and certification (Core) |
| **Boundary evidence** | "Course" means the assessment set; "Learner" means a candidate with a record; only Certification writes assessments and certificates |
| **Language** | `design/certification/ubiquitous-language.md` |
| **Owns (Aggregates)** | Assessment, Certificate |
| **Publishes** | AssessmentPassed, CertificateAwarded |
| **Consumes** | CohortClosed (Enrolment) |
| **Owner** | domain-modeler (agent-built) |
| **Candidate split** | Proctoring, if remote invigilation gets its own rules and vocabulary |

## External Systems

| System | Used by | What it provides |
|---|---|---|
| Payment Provider | Enrolment | Seat payments |

## Target Map

```
┌─────────────┐        ┌─────────────┐        ┌────────────────┐
│ Catalogue   │──U──D─▶│ Enrolment   │──U──D─▶│ Certification  │
│ (Supporting)│        │ (Supporting)│        │ (Core)         │
└─────────────┘        └──────▲──────┘        └────────────────┘
                              D
                              │
                              U
                       ┌──────┴──────────┐
                       │ Payment Provider│
                       │ [external]      │
                       └─────────────────┘
```

## Relationships

| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| Catalogue | Enrolment | Customer/Supplier | Enrolment needs listing facts on its own terms and Catalogue is built to serve it; Conformist rejected because Enrolment's needs shape what Catalogue publishes | Consumer-driven contract tests from Enrolment, run in Catalogue's pipeline |
| Enrolment | Certification | Anticorruption Layer | Certification is Core; it translates "cohort" and "seat" into its own candidate model. Conformist rejected: the meanings differ | None beyond Enrolment's published events; Certification owns its translation |
| Payment Provider | Enrolment | Conformist | The provider's model is adequate and Enrolment isn't Core; a translation layer rejected as cost without benefit | None; note the provider's version |
````

## Why this is right

- The team-based split was refused with a reason (a technical layer shares one language), not just overruled.
- Each boundary cites the word that changes meaning, the Event Storming hint and who writes what.
- Three contexts, not one per Aggregate; the least settled Core context stays wide with a recorded candidate split. Patterns came from `context-map-patterns`.
