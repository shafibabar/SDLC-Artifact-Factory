# Roles, Test Independence and the Solo-Operator Exception

Self-contained: loadable without `SKILL.md`. Read it when naming who executes, who leads and who accepts; when the product owner is the only person available; when a design partner cannot attend; or when asked whether the agent can be the tester.

Grounding: the three-way role split and "the business accepts" are from Hambling and van Goethem, *User Acceptance Testing: A Step-by-Step Guide*. The independence levels are the ISTQB Certified Tester Foundation Level standard. The solo-operator techniques are this plugin's synthesis from those levels and the product owner's decision D045: neither source discusses a single person who is product owner, only tester and accepting party.

---

## The Three Roles

| Role | Who | Does | Never |
|---|---|---|---|
| **Executor** | An intended user acting in their real role: a design partner, a pilot customer's staff, a member of the user community | Runs the scenarios and exploratory sessions; records results and observations | Changes a scenario to fit what was built |
| **UAT lead** | The requirements-analyst | Plans, briefs, hands out charters, observes without leading, logs defects and feedback, compiles the completion summary | Executes in place of a human, or decides acceptance |
| **Accepting authority** | The product owner plus a customer representative; plus a compliance signatory when regulatory acceptance is in scope | Agrees the yardstick before execution; makes the decision in `acceptance-sign-off` | Accepts without the evidence attached |

Development, platform and security staff **support** (environment, fixes, OAT evidence, attestations). They do not judge UAT results.

## Test Independence (ISTQB)

From least to most independent:

1. **None:** the author of the work tests and accepts it.
2. Independent people **within the team**.
3. An independent test team **within the organisation**.
4. Independent testers **from the business or user community**.
5. **External** independent testers.

More independence finds different defects and brings different biases. It also costs something: isolation from the team and slower feedback. Independence complements familiarity; it does not replace it. **Every plan states the level reached**, per acceptance type at enterprise (UAT at level 4 with council staff, regulatory at level 5 with an external assessor, for example).

---

## The Solo-Operator Exception (D045)

**When it applies:** the product owner is the only person available to execute and to accept: a solo-built internal tool, a one-person product with no design partner yet, or a release where no customer representative can take part.

**What it allows:** the product owner runs UAT **and** signs off. A **full sign-off is allowed**. The outcome is not capped at conditional; the exception record carries the risk, and whoever reads the sign-off later can see exactly how much independence there was.

**What the plan must then contain:**

```markdown
## Exception: solo operator
- Executor and accepting authority: [the product owner, by role]
- Independence level (ISTQB): none
- Why no second party: [e.g. the product has no external users yet; the one design partner cannot attend before the release date]
- Independence in time: scenarios frozen from Ideate acceptance criteria on [date], before the build was seen
- Evidence per scenario: screenshot or recording, date, environment, digest, flag state
- Borrowed session: [name or role, which scenarios, date] or "none available, because …"
```

**Getting independence without headcount:**
- **Independence in time.** The scenarios come from Ideate's acceptance criteria, agreed before the build existed. Freeze them before execution, so the executor cannot quietly bend a test to fit what was built.
- **Independence of the test basis.** The executor tests against criteria an earlier self agreed, not against memory of what they meant.
- **Evidence anyone can audit.** A screenshot or recording per scenario, with tester, date, environment and digest, so a later reviewer can re-judge the result.
- **Borrowed independence.** Even a 30-minute session with one intended user, a colleague or a friend, running two scenarios cold, gives a second pair of eyes no amount of self-testing gives. Plan one wherever such a person exists.
- **Declare what you could not get.** "Independence: none" in the plan and on the sign-off turns a hidden weakness into a reviewable exception.

**What the exception never means:**
- **The agent is never the independent party.** It wrote the scenarios and facilitates the session, so it cannot also be the check on them. An agent "running UAT" on its own is neither UAT nor independent.
- It does not waive any exit criterion: every scenario still needs a result, Blocked and Not run still fail, and the defect rule in `acceptance-sign-off` still applies.
- It is not hidden. Executor = accepting authority **with no recorded exception** fails the plan.

The sign-off's own Exception block, and how the decision is recorded, are `acceptance-sign-off`'s.

---

## A Design Partner Who Cannot Attend

If the customer representative cannot attend execution but can attend the decision, the plan names an internal executor (independence level 2 or lower) and the representative still accepts, after reviewing the per-scenario evidence. If they can attend neither, it is the solo-operator exception: record it the same way.

## Briefing Without Leading

The UAT lead briefs the executor on **what** to do (the scenario's context and steps, the charter's mission), never on **what to think** about the result. During the session, the lead observes and asks open, past-tense questions ("what did you expect to happen there?"), never "that was easy, wasn't it?". Leading questions turn a test into a demo.
