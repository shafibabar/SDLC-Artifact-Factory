# Terminology Drift: How It Appears, How to Find It, How to Correct It

The detail behind `SKILL.md` § 6: the shapes drift takes, how to find it in each medium, the correction loop, what the `terminology-drift-detector` hook does and doesn't check, and how to rank what you find. Stack-neutral (D047-10); the search examples work on any codebase.

## 1. What drift is

Drift is the widening gap between the words the team speaks and the words the code, API, events, tests and documents use. The language is only ubiquitous if it is used the same way everywhere (Evans Ch. 2), so any medium that starts using a different word has forked it. No single divergence breaks the system. Each one adds a translation step in someone's head, and translation steps are where meaning gets lost: two services joining on a "Booking" that means a held slot to one and a billed stay to the other.

## 2. The shapes it takes

| Shape | Looks like |
|---|---|
| **Synonym creep** | The team agreed "Shift Swap"; a new endpoint returns `trade`, a migration adds a `cover_requests` table, a log line says "swap processed". Each author reached for a near word |
| **Developer dialect** | People say "Claim"; the code says `IncidentRecord`. The concept is right, the word is wrong, and the translation lives only in engineers' heads (Evans's Intention-Revealing Interfaces failing) |
| **Definition by implementation** | The only surviving definition is the table, and it has grown a column nobody can explain. The concept has drifted towards the storage |
| **Homonym collapse** | A type was copied across a boundary without its translation, so one context now uses a word in both its own sense and the neighbour's |
| **Retired-word return** | A term retired months ago reappears because someone copied an old example |

## 3. Finding it, medium by medium

| Medium | How to look |
|---|---|
| **Code** | Search identifiers for every banned and retired word in the context's document: types, fields, functions, modules, tables, columns. Any public name in the domain code that matches no term is either a missing term (add it) or drift (rename it) |
| **API schemas** | Request and response field names must use the canonical term. API drift does the most damage, because external consumers copy the word into their own systems |
| **Domain Events** | Event type names and payload keys. Once published, the old word can only be retired through a new event type (`event-schema-design`) |
| **Gherkin and tests** | Step text and scenario names. Gherkin is the executable specification, so drift here means the specification and the code speak different languages |
| **Artifacts** | Prose has no compiler. The hook warns on known drift (§ 5); review catches what it doesn't know |

A generic search, adjusted to the repository's layout:

```bash
# every banned word for the context, whole words, case-insensitive, across code, schemas and feature files
grep -rniwE 'trade|cover request' src/ api/ features/
```

## 4. The correction loop

1. **Classify the finding.**
   - (a) A synonym, to rename to the canonical term.
   - (b) A real concept the language has no word for.
   - (c) A homonym that needs a qualifier or a translation.

   Treating (b) as (a) renames away a real concept and loses information, so don't skip this step.
2. **(a) Synonym:** rename every medium (`./discovery-and-lifecycle.md` § 5.3) and track it in the Banned Synonyms table's "Renamed in" column. Done means every medium is ✔ and the search returns nothing.
3. **(b) Missing concept:** run the entry procedure (`./discovery-and-lifecycle.md` § 5.1), then let it into code.
4. **(c) Homonym:** record it in both contexts' Homonyms tables and make sure the translation at the boundary exists. If the collapse is inside one context, qualify the word or take the split to `bounded-context-mapping`.
5. **Update the product's language document.** Add the ban to the Banned Synonyms table, or retire the word, in the context's `ubiquitous-language.md`. That table is what the hook reads. Never add product words to the plugin glossary (D047-9).

## 5. What the hook checks

`terminology-drift-detector` is a PostToolUse hook on Write and Edit. It runs only for files under `artifacts/`, and it **warns without blocking**: work goes on, and the warning is for the agent or the user to fix before review.

| It checks | Using |
|---|---|
| Plugin drift forms ("outbox pattern" → Transactional Outbox, lowercase "circuit breaker" → Circuit Breaker, …) | A short fixed list taken from `glossary-management` |
| The product's banned synonyms | The Banned Synonyms table (first two columns) in every `artifacts/<product>/design/<context>/ubiquitous-language.md` |

How the product check scopes a ban:

- A file inside `design/<context>/` is checked against that context's bans.
- A file anywhere else in the product is checked against every context's bans, **except** a word that is a canonical term in some context. That word is a homonym, so it's legitimate somewhere, and the hook can't tell which sense a general document means.
- The language documents themselves aren't checked; they list banned words on purpose.

**What it can't check:** the product's source code, API schemas and feature files (they live outside `artifacts/`); meaning (it matches words, so a banned word used correctly in a quotation still warns); and a ban written anywhere but the table. Those are review's job, with the search in § 3.

## 6. Ranking what you find

Rank by how far the wrong word has already spread, not by how it looks:

| Severity | Where | Why | When to fix |
|---|---|---|---|
| **Critical** | Published API field, published Domain Event name or payload key | External consumers have copied it; fixing it later needs a migration across teams | Before the contract ships; after, through a new event type or API deprecation |
| **High** | Public names in domain code; table and column names | Load-bearing inside the product, and spreads with every new caller | In the current change |
| **Medium** | Gherkin text; private identifiers | Specification and code disagree, but the spread is contained | Before the feature merges |
| **Low** | Artifact prose | Nothing depends on it; the hook usually catches it | At the next edit |

## 7. Periodic sweep

Review and the hook catch drift as it comes in. Drift from before a ban needs a sweep at the start of each Design session that revisits a context:

1. Take the context's banned and retired words from its language document.
2. Search for each across code, migrations, schemas and feature files (§ 3).
3. Classify each hit (§ 4) and correct it, or enter the new concept.
4. Record the result. Zero hits is worth recording: it is evidence that the language and the code still agree.

A sweep that keeps finding the same synonym suggests the canonical word doesn't come naturally to the team. Ask whether the choice was wrong, not only whether the offenders should be renamed.
