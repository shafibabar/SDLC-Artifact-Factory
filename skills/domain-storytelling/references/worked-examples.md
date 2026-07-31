# Domain Storytelling — Worked Examples

Self-contained reference for studying fully worked Domain Stories from this repo's
data-estate/compliance domain. Usable independently of
`skills/domain-storytelling/SKILL.md` being in context.

Two stories are included:

1. **Coarse-grained** — the DataAsset Management Bounded Context, 7 steps,
   used to discover BC boundaries before Event Storming
2. **Fine-grained** — the DataAsset classification workflow in detail, 18 steps,
   used to surface Aggregate operations and invariant candidates

Each story is presented as: the narrative, the structured story table, the discoveries
(Ubiquitous Language candidates, BC boundaries, Aggregate operations), and the
"Feeds Forward To" table.

---

## Story 1: Data Steward Classifies a DataAsset (Coarse-Grained)

### Session Context

- **Scope:** Coarse-grained (Bounded Context discovery)
- **Mode:** Pure
- **Scenario:** "Tell me about the last time you had to classify a dataset that came in
  from a new storage source."
- **Narrator:** Data Steward
- **Purpose:** Understand the big-picture workflow across the DataAsset Management domain
  before running an Event Storming session

---

### The Story (Narrative, Data Steward's Words)

"When a new storage source is connected, I get an alert — something appears on my dashboard
telling me there are new files I haven't looked at yet. I open the asset and I can see
its metadata — where it lives, what file type it is, when it was last modified. Then I
scan through the extracted content — the system shows me the entities it found, like names
and dates. Based on what I see, I classify it: Internal, Restricted, or Public. If I
classify it Restricted, I have to check that the folder permissions are correct — that's
actually done by the Storage Owner, not me. So I send them an Access Review request.
Once they confirm, I record the outcome in the audit trail."

---

### Story Steps (Structured)

| Step | Actor | Activity | Work Object | Annotation |
|---|---|---|---|---|
| 1 | Storage Connector | notifies | Data Steward (via dashboard alert) | Alert triggered on new file detection |
| 2 | Data Steward | opens | DataAsset | Shows metadata: location, file type, last modified |
| 3 | Data Steward | reviews | Extracted Entities | Entity list produced by classification scan |
| 4 | Data Steward | classifies | DataAsset | Assigns: Internal, Restricted, or Public |
| 5 | Data Steward | sends | Access Review Request | Only when classification = Restricted |
| 6 | Storage Owner | confirms or amends | Sharing Settings | Step happens in Google Drive — outside this team's system |
| 7 | Data Steward | records | Audit Record | "If I don't write it down, the auditor assumes it never happened" |

---

### Pictogram Description (Text Representation)

```
[Storage Connector] ---1: notifies---> [Data Steward]
                                             |
                                    2: opens |
                                             v
                                        [DataAsset]
                                             |
                                    3: reviews
                                             v
                                    [Extracted Entities]
                                             |
                                    4: classifies
                                             v
                                        [DataAsset] (classification applied)
                                             |  (only if Restricted)
                                    5: sends |
                                             v
                                    [Access Review Request]
                                             |
                              6: confirms/amends
                        [Storage Owner] <----|----> [Sharing Settings]
                        (Google Drive — External Actor, dashed border)
                                             |
                                    7: records
                                             v
                                        [Audit Record]
```

**Boundary marker:** Step 6 crosses from the team's internal system boundary into Google
Drive (an External Actor). This boundary becomes the Storage Integration Bounded Context
border and a candidate for the Conformist or Anti-Corruption Layer Context Map pattern.

---

### Discoveries from Story 1

#### Ubiquitous Language Candidates

| Term as used by narrator | Type | Status | Action |
|---|---|---|---|
| "dataset" / "files" | Work Object | Synonym conflict with "DataAsset" | Resolve: use `DataAsset` in the model; "file" is acceptable in UI copy only |
| "Storage Connector" | Actor | New | Add to glossary as a System Actor type |
| "Access Review Request" | Work Object | New | Candidate domain concept — may become a first-class entity or a Work Object transferred between contexts |
| "Extracted Entities" | Work Object | New | Named subset of DataAsset content — distinguish from the DataAsset itself |
| "Sharing Settings" | Work Object | New | Belongs to Google Drive context — represents ACL configuration |
| "Audit Record" | Work Object | Existing | Confirm canonical term; note it is distinct from a Classification Result |
| "classify" | Activity | New | Core domain verb — classify(level, classifiedBy) maps to an Aggregate command |

#### Synonym Conflicts

| Term A | Term B | Context | Resolution |
|---|---|---|---|
| "dataset" | "DataAsset" | Narrator used "dataset"; model uses "DataAsset" | Keep `DataAsset` in the model; educate UI copy team to use "asset" or "dataset" as display labels |
| "files" | "DataAsset" | Same narrator, same session | Same resolution as above |

#### Bounded Context Boundary Candidates

| Boundary location | Evidence | Candidate BC on each side |
|---|---|---|
| Step 6 handoff: Data Steward → Storage Owner → Google Drive | The activity crosses into Google Drive (External Actor); the Storage Owner operates in a different system | Left: DataAsset Management BC; Right: Storage Integration BC (Google Drive is an External System in this BC) |
| Step 1: Storage Connector → Data Steward | The Storage Connector triggers the notification — it is a separate system that monitors external storage sources | Left: Storage Integration BC; Right: DataAsset Management BC |

---

### Feeds Forward To (Story 1)

| Output | Target artifact |
|---|---|
| `DataAsset`, `Storage Connector`, `Access Review Request` | Ubiquitous Language glossary — `ubiquitous-language` skill |
| Synonym conflict "dataset"/"DataAsset" | `ubiquitous-language` skill — resolution required before Event Storming |
| Step 6 boundary (Google Drive) | Bounded Context Map — Storage Integration BC with Anti-Corruption Layer candidate |
| `classify` verb as Aggregate command candidate | Event Storming board — `ClassifyDataAsset` Command sticky note |
| Audit Record requirement ("must be recorded") | Acceptance criteria — `acceptance-criteria` skill |

---

## Story 2: Compliance Officer Investigates a Restricted DataAsset (Fine-Grained)

### Session Context

- **Scope:** Fine-grained (Aggregate design)
- **Mode:** Pure (with annotated overlay added after validation)
- **Scenario:** "Tell me about the last time you investigated a newly flagged Restricted document."
- **Narrator:** Compliance Officer
- **Purpose:** Expose the business rules, approval flows, and exception paths inside the
  classification workflow — surface Aggregate operations and invariant candidates not visible
  at the coarse-grained level

---

### The Story (Narrative, Compliance Officer's Words)

"I get an alert when something is classified Restricted — it shows up in my queue. I
click on it and I see the asset detail: what it is, where it lives, when it was classified,
and who classified it. First thing I do is check the sensitivity level myself — I want to
verify the classification makes sense. Sometimes the automated suggestion is wrong.

If I agree with Restricted, I check the access permissions on the source folder. I can
see from the system whether the permissions look correct — but I can't change them myself.
If they're wrong, I raise a formal Access Review with the Storage Owner. I fill in the
reason and the urgency level and send it. Then I wait.

While I'm waiting, the asset stays in a 'Pending Review' state — I can't close the case
yet. If the Storage Owner doesn't respond within five business days, I escalate to their
manager. Once they confirm or fix the permissions, I receive a notification.

After confirmation, I record my investigation notes — what I found, what action was taken,
what the outcome was — as an Investigation Record. Then I mark the case as resolved and
it disappears from my active queue."

---

### Story Steps (Structured)

| Step | Actor | Activity | Work Object | Annotation |
|---|---|---|---|---|
| 1 | Classification Service | sends | Restricted Alert | Triggered when DataAsset.sensitivity = Restricted |
| 2 | Compliance Officer | opens | Restricted Alert | Appears in Compliance Officer's queue |
| 3 | Compliance Officer | opens | DataAsset detail | Shows: asset identity, storage location, classification timestamp, classified-by |
| 4 | Compliance Officer | verifies | Sensitivity Level | "I check the classification makes sense — automated suggestion can be wrong" |
| 5 | Compliance Officer | checks | StorageSource permissions | Visible in system but not editable by Compliance Officer |
| 6 | Compliance Officer | raises | Access Review Request | When permissions are non-compliant; filled with reason and urgency |
| 7 | Compliance Officer | sends | Access Review Request | Sent to Storage Owner |
| 8 | DataAsset | transitions to | Pending Review state | Asset cannot be closed until access review resolves |
| 9 | [timer] | triggers | Escalation after 5 days | If Storage Owner has not responded by day 5 |
| 10 | Compliance Officer | escalates to | Storage Owner's Manager | Only when 5-day timeout fires |
| 11 | Storage Owner | confirms or amends | Sharing Settings | Happens in Google Drive (External Actor) |
| 12 | Google Drive | sends | Permission Confirmation | Confirmation notification back to the system |
| 13 | Compliance Officer | receives | Permission Confirmation | Notification arrives in queue |
| 14 | Compliance Officer | records | Investigation Notes | What was found, what action was taken, what the outcome was |
| 15 | Compliance Officer | creates | Investigation Record | Formal record of the investigation — distinct from the Audit Record in Story 1 |
| 16 | Compliance Officer | marks | Compliance Case | Status: Resolved |
| 17 | Compliance Case | transitions to | Resolved state | Removed from active queue |
| 18 | Compliance Officer | verifies | Audit Trail completeness | "Must be complete before I close — auditor will review every step" |

---

### Discoveries from Story 2 — What the Fine-Grained Story Reveals

The fine-grained story reveals structure that was invisible at the coarse-grained level.
This is the primary value of zooming in: Aggregate boundaries and invariants emerge.

#### New Ubiquitous Language Candidates (not in Story 1)

| Term as used | Type | Status | Action |
|---|---|---|---|
| "Restricted Alert" | Work Object | New — distinct from Story 1's "dashboard alert" | Confirm: this is `ClassificationAlert` scoped to Sensitivity = Restricted |
| "Pending Review" | State / Work Object | New | Name for the DataAsset state during active Access Review |
| "Access Review Request" | Work Object | Confirmed from Story 1 | Now has documented structure: reason + urgency level |
| "Investigation Record" | Work Object | New | Distinct from `Audit Record` in Story 1 — two separate concepts |
| "Compliance Case" | Work Object | New | First-class domain concept grouping: the Restricted Alert + Investigation Record + outcome |
| "Escalation" | Activity | New | Timeout-driven action — not the same as the initial Access Review |
| "5 business days" | Annotation | New | Business rule: SLA for Access Review response |
| "classified-by" | Attribute | New | Who performed the classification — appears in DataAsset detail (actor attribution) |

#### Business Rules Surfaced (Invariant Candidates)

Each of these rules was stated by the narrator as a non-negotiable constraint. They are
candidates for explicit invariants enforced by an Aggregate's command method.

| Business rule (narrator's words) | Invariant form | Candidate Aggregate |
|---|---|---|
| "Asset stays in Pending Review — I can't close the case" | A DataAsset in Pending Review state cannot be marked Resolved | DataAsset or ComplianceCase Aggregate |
| "Automated classification can be wrong" | A Compliance Officer may override the automated Sensitivity Level | DataAsset Aggregate — `OverrideSensitivity(level, reason, by)` |
| "Can't change permissions myself" | Compliance Officer role cannot modify StorageSource.sharingSettings | StorageSource Aggregate — enforced by access control |
| "Must record before I close" | A ComplianceCase cannot be marked Resolved without an InvestigationRecord | ComplianceCase Aggregate — `Resolve(record InvestigationRecord)` |
| "5-day SLA for Storage Owner response" | An unresponded AccessReviewRequest escalates after 5 business days | ComplianceCase Aggregate or a Saga for the escalation flow |

#### Aggregate Operations Surfaced

The fine-grained story maps naturally to Aggregate command methods. These are the verbs
that belong in the domain model — each is an activity the narrator performed on a named
Work Object, with a constraint attached.

```go
// DataAsset Aggregate
func (a *DataAsset) VerifySensitivity(verifiedBy UserID, at time.Time) error
func (a *DataAsset) OverrideSensitivity(level SensitivityLevel, reason string, by UserID, at time.Time) error
func (a *DataAsset) TransitionToPendingReview(reviewRequestID AccessReviewRequestID, at time.Time) error

// AccessReviewRequest Aggregate (or Value Object)
type AccessReviewRequest struct {
    ID        AccessReviewRequestID
    DataAsset DataAssetID
    Reason    string
    Urgency   UrgencyLevel
    SentAt    time.Time
    SentTo    StorageOwnerID
}

// ComplianceCase Aggregate
func (c *ComplianceCase) OpenFromAlert(alertID ClassificationAlertID, assignedTo ComplianceOfficerID, at time.Time) error
func (c *ComplianceCase) RaiseAccessReview(req AccessReviewRequest, at time.Time) error
func (c *ComplianceCase) EscalateToManager(manager ManagerID, reason string, at time.Time) error
func (c *ComplianceCase) ReceivePermissionConfirmation(confirmedBy StorageOwnerID, at time.Time) error
func (c *ComplianceCase) Resolve(record InvestigationRecord, resolvedBy ComplianceOfficerID, at time.Time) error
```

**Key observation from the fine-grained story:** `ComplianceCase` is a separate Aggregate
from `DataAsset`. The narrator treated them as two distinct things: the asset (the
DataAsset) and the investigation (the ComplianceCase). A `DataAsset` can exist without a
`ComplianceCase`; a `ComplianceCase` always references a `DataAsset` by ID but is not
contained within it.

This boundary would have been invisible at the coarse-grained level. The coarse story
showed "classifies" and "records audit trail" — two steps. The fine story shows 18 steps
across two Aggregates with distinct lifecycles, five business rules, and a timeout-driven
escalation path that is a strong Saga candidate.

#### Bounded Context Boundary Evidence (Additional)

The fine-grained story confirms the Google Drive boundary from Story 1 and reveals an
additional structural question:

| Boundary | Evidence | Design implication |
|---|---|---|
| DataAsset Management → Storage Integration | Step 11–12: Storage Owner amends settings in Google Drive; confirmation notification returns | Confirms the anti-corruption layer pattern: the Storage Integration BC translates Google Drive's permission model into the domain's own `PermissionConfirmation` concept |
| DataAsset Management (internal) boundary | Steps 1–18 all occur within the team's system — no second internal boundary crossed | The `ComplianceCase` Aggregate and the `DataAsset` Aggregate both live in the same Bounded Context; they reference each other by ID |

#### What Was Not Visible in the Coarse-Grained Story

| Concept | Visible in Story 1? | Visible in Story 2? | Implication |
|---|---|---|---|
| Pending Review state | No | Yes (step 8) | DataAsset has a lifecycle state machine — coarse story only showed the happy-path end state |
| 5-day SLA / escalation | No | Yes (steps 9–10) | Saga or process manager needed for time-based escalation |
| ComplianceCase as distinct concept | No | Yes (steps 16–17) | Two Aggregates, not one — missed without the fine-grained story |
| InvestigationRecord vs AuditRecord | No | Yes (steps 14–15) | Two distinct Work Objects — would have been conflated from the coarse story alone |
| classified-by attribution | No | Yes (step 3) | DataAsset needs `ClassifiedBy UserID` attribute — security/audit traceability requirement |
| Compliance Officer's override capability | No | Yes (step 4) | DataAsset command `OverrideSensitivity(...)` — not visible at coarse granularity |

---

### Feeds Forward To (Story 2)

| Output | Target artifact |
|---|---|
| `ComplianceCase`, `InvestigationRecord`, `AccessReviewRequest`, `Pending Review` | Ubiquitous Language glossary — `ubiquitous-language` skill |
| `ComplianceCase` as a distinct Aggregate | `aggregate-design` skill — separate from `DataAsset` Aggregate |
| Aggregate command methods (see Go signatures above) | `aggregate-design` skill → `go-domain-model` skill for implementation |
| 5-day SLA escalation path | `acceptance-criteria` skill — Gherkin scenario: "Given an AccessReviewRequest unanswered after 5 business days, When the SLA check runs, Then the case is escalated to the Storage Owner's Manager" |
| Timeout-driven escalation as Saga candidate | `event-driven-patterns` skill — Saga pattern for multi-step compensating flows |
| `ComplianceCase.Resolve()` invariant (requires InvestigationRecord) | Event Storming — `ResolveComplianceCase` Command with Policy: "cannot proceed without InvestigationRecord" |
| `DataAsset.OverrideSensitivity()` | Event Storming — `OverrideSensitivityLevel` Command with `SensitivityOverridden` Domain Event |

---

## Key Observation: Coarse Before Fine

Story 1 (coarse-grained, 7 steps) took 45 minutes. Story 2 (fine-grained, 18 steps) took
75 minutes. Running Story 2 first would have been overwhelming — there would have been no
established vocabulary, no shared understanding of the Bounded Context boundaries, and no
basis for distinguishing "important detail" from "irrelevant implementation noise."

The correct sequence is always:
1. Coarse-grained story → discover BC boundaries, vocabulary, and the big-picture workflow
2. Event Storming (optional intermediate) → add Domain Events and commands to the vocabulary
3. Fine-grained story → zoom into a specific workflow to expose Aggregate operations and invariants

This matches the guidance in Evans' "Refactoring Toward Deeper Insight" (Domain-Driven
Design, Ch. 8): the deeper model emerges from repeated, progressively finer engagement
with domain experts — not from a single session. A fine-grained story run before a
coarse-grained one is exactly the "breakthrough without foundation" failure Evans describes.
