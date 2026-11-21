# Agent-Run Mode

The procedure behind `SKILL.md` § 1. Decision D047-8 adds it because the domain-modeler usually works with no storyteller. It is this plugin's adaptation, not the authors' method: the book's storyteller is the person who does the work, and a story with no storyteller is a draft to be confirmed (`research/domain-driven-design/domain-storytelling-hofer-schwentner.md`, Caveats).

## 1. Inputs

Read and list in the story's `traces-to`: personas and the stakeholder map (who acts); job stories, user stories and acceptance criteria (what they do and why); user journey maps (one customer's path, which hints at the work behind it); the problem statement and vision; for an existing system, its documentation, and any spreadsheets or emails described as doing real work.

## 2. Drafting a story

1. **Pick the scenario and the scope factors.** A concrete case ("Ms Okafor's repeat request arriving on a Monday"), not the general process. Record granularity, point in time and purity.
2. **Write the usual case as numbered sentences:** actor – activity – work object, with a recipient where there is a hand-over.
3. **Cite each sentence.** In the Source column, put the artifact and item it came from (`ideate/job-stories.md J3`), or *assumed*.
4. **Never invent the teller's words.** Terms come from the documents; label them as document terms in the Terms table.
5. **Pose the variants.** For each persona and each failure the artifacts mention or imply, decide whether it is worth its own story. Draft the important ones; note the minor ones as annotations.
6. **Draw groups** on a coarse-grained story with the hint for each: a word changes, a role takes over, the pace or trigger changes, a hand-over.

## 3. Open questions

Every *assumed* sentence and every gap becomes a question for the product owner, with why it matters and the assumption used meanwhile:

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | Who checks the prescription is still valid, the pharmacist or the dispenser? | Decides the actor of sentence 3 and a role in the language | The pharmacist |

## 4. The retelling for the product owner

Write the story out as plain numbered sentences for the product owner, or a person who does the work, to read and correct. It's the book's main check, done asynchronously: every correction is a finding. A corrected sentence loses its *assumed* label and cites the correction (`product owner YYYY-MM-DD`).

## 5. What the reply says

- That the stories are drafts built from documents, not told by the people who do the work.
- How many sentences are *assumed*.
- The open questions, most important first.
- The retelling to check.
- That a real session with the people who do the work stays optional, and would replace the draft sentences it confirms.

A real session stays optional. When held, its stories replace the drafts they confirm (`./facilitation-guide.md` § 7).
