# Ubiquitous Language Checklist

Check each context's `ubiquitous-language.md` against this list before the domain-modeler's review gate. Any "no" is fixed before presenting.

## The document

- [ ] It sits at `artifacts/<product>/design/<context>/ubiquitous-language.md`, one per Bounded Context, and nothing was added to the plugin glossary (`glossary-management`).
- [ ] The frontmatter has `name`, `version`, `phase`, `owner`, `created` and a specific `summary`, plus `traces-to` naming the artifacts it was drawn from.
- [ ] The Context Boundary paragraph names what the context is responsible for and its neighbours.
- [ ] It says how the language was found: a human session (date, roles) or agent-run.

## Terms

- [ ] Every term has a DDD type. Every Entity and Aggregate Root has at least one rule that always holds.
- [ ] Every meaning is in domain words. None says "a row in", "a record in table", "a JSON object".
- [ ] No hedged meanings ("usually", "generally") unless the exception is named as a rule or a second term.
- [ ] Every term has a Source: an artifact path, a session, or *assumed*.
- [ ] Every Aggregate Root and Policy has at least one Given/When/Then in Key Scenarios (lean included).
- [ ] Key terms point to the event, command or scenario that shows their behaviour.
- [ ] The terms read naturally in sentences about the domain (modeling out loud).

## Bans and homonyms

- [ ] Every word the team uses for an existing term is in Banned Synonyms, with its replacement in the second column.
- [ ] Each ban was checked as a true synonym (same meaning in this context), not a homonym from another context.
- [ ] Rename status is filled for each ban (standard and enterprise; lean may say "nothing built yet").
- [ ] No homonym was "settled" by banning the word in one context; each context keeps its own meaning.
- [ ] Every word shared with another context is either the same concept (owned by one context, or a deliberate Shared Kernel) or listed under Homonyms with its translation.
- [ ] No version-suffixed names (`V2`, `New…`, `Real…`).

## Agent-run honesty

- [ ] No term is presented as confirmed by domain experts unless someone confirmed it.
- [ ] Every disputed or guessed word is an open question for the product owner, with the assumption in use.
- [ ] No unconfirmed synonym is in Banned Synonyms; candidates wait in Open Questions until the product owner confirms.
- [ ] The reply at the gate lists the open questions, not only the document path.
- [ ] The reply gives the product owner sentences to read aloud (or a story to hear told back) as the check with a person.
- [ ] Any rename still outstanding in existing code, API or scenarios is reported as in progress, not done.
