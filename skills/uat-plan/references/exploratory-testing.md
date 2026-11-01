# Exploratory Testing in UAT — Charters, Sessions and Heuristics

Self-contained: loadable without `SKILL.md`. Read it when drafting exploratory charters for a UAT plan, choosing test ideas inside a charter, running a debrief, or answering "can the agent do the exploratory testing?". This is the plugin's single home for the charter template and heuristics; `uat-scenario` points here.

Grounding: Elisabeth Hendrickson, *Explore It!* (charter, session, debrief, heuristics, human judgement); Lisa Crispin and Janet Gregory, *Agile Testing* (checking vs testing, the Q3 quadrant); Mark Winteringham, *Testing Web APIs* (why API exploration is a separate practice).

---

## Why It Sits Beside Scripted Scenarios

Exploratory testing is **simultaneous learning, test design and execution** (Hendrickson): what the explorer learns from one action shapes the next probe, in the same moment. A scripted `uat-scenario` separates those in time and so can only check what someone already wrote down. That is Crispin and Gregory's **checking vs testing**: scripts and automation check; exploration tests. A charter has **no pass/fail**. It produces findings, routed to `feedback-template` exactly like a failed scenario.

## The Charter

Hendrickson's template: **"Explore [target], with [resources], to discover [information]."**
- **Target:** a feature, workflow or area, narrow enough to focus an hour.
- **Resources:** test data, devices, accounts, a persona, a tool.
- **Information:** the risk or question you want answered.

It never lists steps. Steps would make it a script and remove the freedom to follow what turns up.

**Where to put charters:** one per area of real risk or complexity in scope, not one per Must story. Good candidates are the places a scripted scenario runs start to finish and never interrupts, data at its edges, and permissions.

Examples from different products:
- "Explore returning a tool, with a loan recorded on one phone and returned on another, to discover whether the loan list and the Friday overdue list ever disagree."
- "Explore replying to a confirm request, with replies in unexpected words, emoji and a second reply that changes the first, to discover how the front desk learns what the patient meant."
- "Explore submitting an application, with an expired session halfway through the upload and a 200 MB drawing, to discover whether the applicant loses work or sees a half-submitted application."

## The Session

- **Time-box:** 45–90 minutes. Hendrickson treats about an hour as a practical default.
- **Notes during the session**, not reconstructed afterwards: actions, observations, questions.
- **Same executor pool and same environment** as the scripted scenarios.
- **Debrief** at the end: what was learned, defects and issues (to `feedback-template`), and any **new charters** the session surfaced.

Record it in the session template, `../templates/exploratory-session.md`.

## Heuristics for Test Ideas

Run down the list when a charter needs concrete probes, and pick what fits the target:
- **CRUD:** create, read, update, delete, and how they interact (delete something still referenced; update, then re-read).
- **Boundaries:** minimum, maximum, zero, one past a limit, empty.
- **Goldilocks / position:** first, last, only one, none, too many.
- **Interruptions:** stop mid-workflow (navigate away, lose connection, let the session expire, switch user), then resume or abandon. This is one of the highest-yield heuristics for state bugs, because scripts never interrupt.
- **Configuration variance:** browser, device, locale, permission level, flag state.
- **Saboteur:** wrong input types, steps out of order, malformed data: what a well-behaved user never does.

## Coverage Across Charters

Before closing exploration for a release, check the set of charters touches **Structure, Function, Data, Interfaces, Platform, Operations and Time** (the SFDIPOT prompt, from the context-driven testing community, used alongside Hendrickson's heuristics). It is a completeness check across all charters, not a requirement on each. The pass rule is in `../resources/uat-plan-checklist.md`.

## Charter Generates Charter

Every debrief may produce follow-on charters. Exploration branches inside the UAT time-box. It is not one pass that either finds something or does not. A follow-on charter that cannot fit the window is recorded for the next release, or as a standing exposure in `risk-register` if it keeps recurring.

## Who Explores: a Human

The value of exploration is a person's in-the-moment judgement. **The adaptation this plugin uses:** the requirements-analyst drafts the charter and picks the heuristics; a **human executor** (an intended user, or the product owner under the solo-operator exception) explores, using the charter as a mission brief.

If asked "can you, the agent, do the exploratory testing?", the answer is no. An agent reasoning over screenshots or a UI description, with no human driving, produces **scripted testing labelled as exploratory**. Say so, then offer what the agent can do: draft the charters, prepare the data, take notes in the session, and run the debrief.

## Not the Same as API Exploration

Winteringham's exploratory testing of an API (unexpected verbs, missing headers, malformed bodies, stale tokens) targets the protocol surface, during Implement and Quality, and is done by engineers or testers. It shares a family resemblance but is a different practice, with a different owner (`test-strategist`), time and target. Do not plan it as a UAT session, and do not count it toward UAT exploration.
