# Example 3 — Enterprise: four contexts, one word, and a rename that reaches a published event (hardest case)

Self-contained. **Ashgrove Mutual** is a commercial property insurer replacing its policy platform, at the **enterprise** profile. Four Bounded Contexts: **Quoting**, **Underwriting**, **Policy Administration** and **Claims**. A human Event Storming session was held with underwriters and claims handlers; the domain-modeler wrote it up.

## Input

> **User:** "'Policy' is everywhere and means different things. Claims also has a `PolicyRecord` type that's just a copy of the cover at the date of the incident. We've agreed to call that a Cover Snapshot and banned 'PolicyRecord' in the Claims language document. Can we mark the rename done? The `PolicyRecordCaptured` event is already in production; three other systems read it."

## Working it

**Step 1: what "Policy" means in each context.**

| Context | "Policy" means | Lifecycle |
|---|---|---|
| Quoting | An offer of terms, valid 30 days | Issued, accepted, lapsed |
| Underwriting | The decision to accept a risk, with conditions | Referred, accepted, declined |
| Policy Administration | The contract in force: cover, premium, dates, endorsements | Incepted, endorsed, renewed, cancelled |
| Claims | The cover that applied on the date of loss | Captured once, never changes |

Four meanings. Policy Administration owns **Policy** (the contract). In the session, the people in Quoting and Underwriting turned out to say **Quote** and **Underwriting Decision** day to day, and used "policy" only loosely, so those are their terms. Nothing was banned to get there. Had they really said "Policy", each context would have kept it as a homonym, with its translation named. Claims' concept is the frozen copy: **Cover Snapshot**, as the user says.

**Step 2: is the Claims rename done?** No. The ban is in the document, but:

| Medium | State |
|---|---|
| Code | `PolicyRecord` type and `policy_records` table still there |
| API | Claims API returns `policyRecord` |
| Events | `PolicyRecordCaptured` published; three consumers |
| Tests | 14 scenarios say "Given a policy record" |
| Docs | Claims artifacts updated; the drift hook flags two left in `design/claims/` |

A rename is done only when every medium uses the new word. Until then the document says Cover Snapshot and the code says PolicyRecord, and the code wins.

**Step 3: the published event can't simply be renamed.** Three consumers depend on `PolicyRecordCaptured`. Under `event-schema-design` (D047-1), a breaking change is a **new event type**, never `PolicyRecordCaptured.v2`. So: publish `CoverSnapshotTaken` alongside the old event, move the three consumers over, then deprecate and retire `PolicyRecordCaptured` on a date agreed with their owners. The API field goes through `api-contract-design`'s deprecation the same way.

**Step 4: severity** (`../references/drift-detection.md` § 6): the event and API field are Critical (consumers have copied the word); the type and table are High; the scenarios are Medium; the two artifact leftovers are Low.

## Output — the reply

> Not yet. The Claims document is right, but the rename is only done when the code, the API, the event and the tests all say Cover Snapshot, and today none of them do. Plan:
> 1. Rename the type, the table and the 14 scenarios in the next change.
> 2. Publish a new `CoverSnapshotTaken` event beside `PolicyRecordCaptured`, never as a `.v2`. Move the three consumers over, then retire the old event on a date their owners agree.
> 3. Deprecate the `policyRecord` API field in favour of `coverSnapshot`.
> 4. Fix the two artifact leftovers the drift hook found.
>
> I'll keep the rename status in the Claims Banned Synonyms table, so "done" is a row of ticks you can check. Separately, "Policy" now belongs only to Policy Administration. Quoting and Underwriting use Quote and Underwriting Decision, and Claims uses Cover Snapshot, each with its translation on the Context Map.

**`artifacts/ashgrove/design/claims/ubiquitous-language.md`** (extract):

```markdown
## Banned Synonyms

| Banned | Use instead | Renamed in (code · API · events · tests · docs) |
|---|---|---|
| policy record, PolicyRecord | Cover Snapshot | ✘ code · ✘ API (deprecating `policyRecord`) · ✘ events (`CoverSnapshotTaken` added; `PolicyRecordCaptured` retiring) · ✘ tests (14) · ✔ docs |

## Homonyms at the Boundary

| Term | Meaning here | Other context | Meaning there | Translation (Context Map relationship) |
|---|---|---|---|---|
| Policy | Not used; Claims says Cover Snapshot | Policy Administration | The contract in force | Claims' ACL takes a Cover Snapshot from Policy Administration's published Policy at the date of loss |

## Key Scenarios

    Scenario: A Cover Snapshot doesn't change when the Policy is endorsed later
      Given a Cover Snapshot taken for an incident on 3 March
      When Policy Administration endorses the Policy on 10 March
      Then the Cover Snapshot still shows the cover in force on 3 March

## Retired Terms

| Term | Retired on | Reason | Successor (if merged) |
|---|---|---|---|
| PolicyRecordCaptured (event) | retiring, date with consumer owners | Breaking rename | CoverSnapshotTaken |
```

## Why this is right

- "Done" was refused on evidence: a status per medium, not an opinion.
- The published event got a new type, not a rename and not a version suffix, so the three consumers aren't broken.
- "Policy" was settled context by context. One context owns it, two renamed by choice, and every crossing has a named translation. There's no global definition, and nothing went into the plugin glossary.
- The drift hook won't flag "Policy" in a general Ashgrove document, because Policy is canonical in Policy Administration. It does flag "PolicyRecord" anywhere, because that word is canonical nowhere.
