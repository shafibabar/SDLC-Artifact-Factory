# Writing a Criterion: Formats, Testability and Edges

Self-contained. A criterion is one verifiable condition of a user story, identified `AC-US-n.m`, drawn from the story's ready example map, and written in the product's business language.

## Two formats

### Given/When/Then

The usual format, for anything a person or the system does. The keywords and their meaning follow the Cucumber project's Gherkin reference: `Given` context, `When` action, `Then` observable outcome. The one-`When` limit is this plugin's own rule.

| Step | Says | Rule |
|---|---|---|
| `Given` | The state that already holds ("the clerk has opened the day's returns") | A state, not an action to perform |
| `When` | The action under test | Exactly one. A second action belongs in the Given as settled state, or in its own criterion, so a failure names one behaviour |
| `Then` | The outcome | Observable: something the persona sees or receives, or a named operational record such as an audit record |
| `And` | More of the preceding step | |
| `But` | Something that must not happen, after a `Then` | |

```gherkin
Given Priya's membership lapsed on 31 October,
When she reserves the rowing machine for 3 November,
Then the reservation is refused with the reason "Membership lapsed"
But no fee is charged.
```

### Rule, Verify, Example

For a business rule that is not a single action flow: a calculation, a table of allowed values, a standing constraint.

```
**Rule:** A member holds at most two reservations at a time.
**Verify:** Reserve a third item while two are held and confirm it is refused.
**Example:** Priya holds the rower and the bike; her request for the treadmill is refused.
```

All three lines are filled. The rule format is not a place for how the system is built.

## Declarative, not scripted

Say what is true for the business, not how to drive it (Ken Pugh, *Lean-Agile Acceptance Test-Driven Development*). No clicks, field names, endpoints, queries or tool names. A technical check (traffic analysis, an encryption setting, log contents) belongs to the NFR specification or the design, not here.

| Scripted or technical | Declarative |
|---|---|
| "When she clicks Export and chooses PDF" | "When she exports the gap report as PDF" |
| "Then a row is inserted into the loans table" | "Then the loan appears in her list of current loans" |
| "Then the green button appears top right" | "Then the report can be exported" |

## Testability

Every criterion answers "how will we know this has been satisfied?" with a pass or a fail (Hathaway, *Getting and Writing IT Requirements in a Lean and Agile World*). Wiegers and Beatty (*Software Requirements*) list words that hide the answer. Replace each with a condition and an outcome from the map; if the map has none, ask.

| Fails | Why | Passes (values from the map) |
|---|---|---|
| "The user can easily find the report" | Subjective | "The report is listed on the home screen under Reports" |
| "Errors are handled gracefully" | No observable outcome | "The user sees which upload failed and can retry it" |
| "The system should reject bad files" | "Should" leaves it optional; "bad" is undefined | "A file over 25 MB is refused with the size limit shown" |
| "All data is secure" | Unmeasurable | Not a criterion: a quality attribute for the NFR specification |

The script rejects: should, may, fast, quick, quickly, easy, easily, intuitive, user-friendly, flexible, robust, seamless, efficient, properly, well (not "as well"), gracefully, appropriate, as needed, and/or, etc, approximately, several. Text inside double quotes (an on-screen message) is not checked. The script also rejects HTTP calls, queries, field assignments and backticked identifiers, and warns on words such as endpoint, JSON or database (acceptable only where that is the user's own language, as in a developer product).

## Quality targets

A response time, throughput, uptime or satisfaction figure is not an acceptance criterion. It belongs to the NFR specification (`nfr-specification`). Take it out, say so, cite its NFR ID under Derived From, and if there is none, say one is needed and ask. A time limit that is the business rule itself ("refunded if cancelled 48 hours before") is a criterion.

## Edge cases

Every story has at least one edge criterion, at every size. Check each of these against the map:

1. **Permission:** who may not do this?
2. **Empty state:** nothing there yet.
3. **Scale:** the maximum expected volume, and exactly on each limit.
4. **Concurrency:** two people do the same thing at once.
5. **Dependency down:** something the story relies on is unavailable.
6. **Tenant isolation**, when the product has tenants: another tenant's data.

For each: a criterion (when the map has the rule and example), a line under Explicitly Out of Scope (when the product owner or a source leaves it out, or it belongs to another story), or a question added to the map. Never invent the behaviour.

## How many

Enough that every rule is proven, and no criterion repeats another (Gojko Adzic's key examples, *Specification by Example*). More than 12 for one story is this plugin's signal to propose a split to the product owner; so are six or more rules on its map.
