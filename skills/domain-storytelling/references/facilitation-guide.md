# Domain Storytelling: Running a Session with People

For when the product owner holds a real session; agent-run mode is in `./agent-run-mode.md`. Grounded in Hofer & Schwentner (*Domain Storytelling*), as summarised in `research/domain-driven-design/domain-storytelling-hofer-schwentner.md`. Numbers marked *house* (group size, timings) are this plugin's guidance; the book gives none that is recalled.

## 1. Roles

| Role | Does |
|---|---|
| **Storytellers** | Domain experts telling the work they do. There can be several, each telling their part |
| **Moderator** | Runs the session: picks the scenario, asks questions as the story unfolds, keeps it concrete |
| **Modeller** | Draws each sentence as it is spoken, on a screen everyone can see, and retells the story. May be the moderator; the book finds two people easier |
| **Listeners** | Developers and product people. Mostly listen; ask questions when the moderator invites them |

**Who tells:** the person who does the work daily, not the manager who oversees it, and someone who knows the exceptions. Architects and analysts tend to tell the system as it should be.

**Size (*house*):** small enough that everyone can see the picture and be heard, typically up to about six. When storytellers disagree about how the work goes, tell both versions as separate stories rather than negotiating one.

## 2. Choosing the scenario

A good first scenario is concrete (a case that happened), within the teller's own experience, urgent for the team, and complete from a clear trigger to a clear outcome.

| Ask | Not |
|---|---|
| "Tell me about the last time a parcel was held at the border." | "How does customs clearance work?" (a general description, not a story) |
| "Walk me through yesterday's first repeat prescription, from the request arriving." | "What are the steps in the repeat process?" (a procedure, not a narrative) |

The usual case comes first. Exceptions are variant stories afterwards.

## 3. Opening

1. **Explain in a minute:** "Tell me a real case. I'll draw it as you talk: a shape for each person or system, a shape for each thing you work with, an arrow for each thing you do. Then I'll read it back and you tell me where I got it wrong."
2. **Show one sentence from another domain:** "The librarian lends the book to the reader": a person, a book, a numbered arrow.
3. **Two ground rules:** your own words, not technical ones; and name who does each step, never "the system".

## 4. Telling and drawing

- **Draw each sentence as it is said:** an actor for each role, a work object for each thing, a numbered arrow for each verb, an annotation for each condition ("only if…", "unless…").
- **Ask as it unfolds** (as recalled, the moderator questions during the telling, not only at the end): "Who gets it next?", "What do you call that?", "What do you do with it?" Keep questions on the story being told; save "what if…" for variants.
- **When the teller uses a technical word** in a pure story, record it and ask afterwards whether colleagues use the same word.
- **"Hold on, let me catch up"** is fine; a lost sentence breaks the sequence.
- **Stop** when the teller says it's done, or the story loops back to an earlier state (note where). If it sprawls, scope it down: "What tells you this case is finished?"

## 5. The retelling

The modeller reads the picture back, sentence by sentence, at points during the session and at the end: "First, the patient sends the request to the pharmacy. Then the pharmacist checks the prescription record…". Pause every few sentences: "Is that right?"

- A changed word is a vocabulary finding: change the label and note it.
- A changed order is an ordering finding: renumber.
- Don't defend the drawing; it exists to capture their work.

The retelling also reveals sentences said too quickly, actors implied but not named, and work objects that appear and are never used again.

## 6. Variants

After the usual case: "What else can happen?" Each important answer becomes its **own story**, named, cross-referenced to the first, and retold the same way. Minor variants go in an annotation.

| Variant kind | Prompt |
|---|---|
| Exception | "What happens when the broker never answers?" |
| Another role's view | "Tell me the same case from the importer's side." |
| Negative case | "What happens when the prescription has expired?" |
| Breakdown | "What do you do when the portal is down?" |

## 7. After the session

- Transcribe the same day into `../templates/domain-story.md`, one file per story, with the scope factors and `run: workshop`.
- Where an agent-run draft existed, the told story replaces the sentences it confirms; drop their *assumed* labels.
- Fill the Feeds Forward table: terms to `ubiquitous-language`, groups to `bounded-context-mapping`, variants to `acceptance-criteria`.

## 8. Failure modes

| Failure | Looks like | Correction |
|---|---|---|
| Designing while drawing | The picture shows the system intended | Draw only what is said |
| Translating on the fly | Technical words replace the teller's | Record the exact word; reconcile later |
| Committee storytelling | Several experts negotiate an average | Tell differing versions as separate stories |
| General description | "Usually what happens is…" | "Tell me about a specific time, last week" |
| Happy path only | No variants told | Ask "what else can happen?" |
| Never retold | The picture was never checked | Retell before calling it done |
