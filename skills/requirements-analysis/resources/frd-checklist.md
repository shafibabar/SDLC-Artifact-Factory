# Functional Requirements Document — Hand-off Checklist

Self-contained. Validate the FRD against every row before presenting it. Rows marked **(script)** are also checked by `../scripts/check-frd.py`. The per-requirement rows are the Robertsons' quality gateway (Volere): apply them as each requirement is written, not only at the end.

## The document

| # | Check | Fail when |
|---|---|---|
| 1 | Frontmatter has `name`, `version`, `phase: ideate`, `owner`, `created`, `summary`, `profile`, `linked-kr`, `linked-impact-map`, `linked-jtbd` **(script)** | Any missing; `profile: lean` (lean has no FRD) |
| 2 | Written after the impact map (where one exists) and from its selected path | The map was drawn from these requirements; an option deliverable became a UR |
| 3 | A translation line names inputs and consumers | No statement of what this document translates for whom |
| 4 | "Priorities are provisional" stated once; finalised by `moscow-prioritization` | Missing |
| 5 | Scope and exclusions written; business requirements cited by KR ID, not restated | No exclusions; OKRs rewritten |
| 6 | User classes with favoured / disfavoured / ignored and a champion | Only favoured classes; no champion named |
| 7 | Business rules catalogued once with kind and source; FRs cite the ID | A rule restated in several FRs; no source |
| 8 | Constraints name who imposed them; none is a configured stack default | "Backend in Go" as a constraint because it is the default |
| 9 | Transition requirements present when anything is replaced (spreadsheet, paper, legacy), or "None, because …" **(script: section exists)** | Section missing; a replacement with no migration, training or decommission |
| 10 | Quality concerns handed off to `nfr-specification` with the FRs they constrain; no targets set here | A response time, uptime or throughput target in the FRD |
| 11 | Assumptions logged with how each is confirmed; nothing attributed to an interview that did not happen | "Stakeholder interview (simulated)"; "the finance team told us" with no snapshot |
| 12 | TBD list ties each question to the requirement it blocks | TBDs hidden in requirement text |
| 13 | Waiting room holds deferred items with reasons | Preferences and options silently dropped or silently kept |
| 14 | Traceability table: every selected-path deliverable and every cited job story is served by a UR | A selected deliverable or job story with no UR |
| 15 | Enterprise: conflicts recorded for the user; forward-trace columns present; change log | Conflicts resolved silently; no change log |
| 16 | Canonical glossary terms; product-specific rules only in this product's FRD | Synonyms for glossary terms |

## Each user requirement

| # | Check | Fail when |
|---|---|---|
| U1 | Traces to a selected-path deliverable (or, with no map at standard, the KR) **(script)** | No deliverable, or an option deliverable |
| U2 | Traces to a job statement **and** the job story beneath it (J-n → JS-n.m) **(script)** | Only a persona; only a job statement; a user story ID in place of a job story |
| U3 | Has a rationale | — |

## Each functional requirement (the quality gateway)

| # | Characteristic (Wiegers and Beatty) | Fail when |
|---|---|---|
| F1 | **Verifiable**: a fit criterion a tester can pass or fail **(script: cell not empty, not a bare test type)** | "Test: integration test"; "works correctly" |
| F2 | **Unambiguous**: no ambiguous words **(script: warning)** | fast, user-friendly, flexible, support, etc., and/or, as appropriate, should |
| F3 | **Atomic**: one behaviour | "and" joining two capabilities |
| F4 | **Solution-free** unless a real constraint | A widget, technology or vendor named |
| F5 | **Necessary**: passes the necessity test | "Nice to have", nothing happens without it |
| F6 | **Functional**: no performance or availability number in the statement or fit criterion **(script: warning on time units and percentages of uptime)** | "within 30 minutes", "99.9%" |
| F7 | **Prioritised, provisionally** **(script: no Must / Should / Could / Won't)** | A MoSCoW label |
| F8 | **Feasible** and **consistent**: no conflict with another requirement, or the conflict recorded | Two FRs that cannot both pass |

## The set (Wiegers and Beatty)

| # | Characteristic | Fail when |
|---|---|---|
| S1 | **Complete**: every selected-path deliverable, cited job story and user class covered; every KR the release serves supported | A gap the traceability table shows |
| S2 | **Consistent** | Contradictions across FRs, rules and constraints |
| S3 | **Modifiable**: one fact, one home | A rule or number repeated in several places |
| S4 | **Traceable**: backward at standard; forward columns at enterprise | Requirements with no source |
