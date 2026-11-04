# Example 1 — Standard: a coarse as-is pure story, agent-run, with groups as boundary hints (simplest case)

Self-contained. **Shelfmark** is a reservation app for Holloway Town Library's four branches, at the **standard** profile. The plan includes domain stories. No librarians are free this month, so the domain-modeler drafts from `ideate/personas.md` (Dana, a reader; Felix, a branch librarian; Ines, the stock coordinator) and `ideate/job-stories.md` (J1–J6).

## Input

> **User:** "Write up how reservations work today, as a story the librarians told us. And tell me which services to build."

## Working it

- **Scope from the question:** orientation and boundaries, so **coarse-grained / as-is / pure.** No software in the story; today's catalogue terminal is not an actor in a pure story.
- **Not "as the librarians told us".** Nobody told it. It's an agent-run draft; each sentence cites its source or is *assumed*.
- **One concrete case:** Dana reserves a book held at another branch. The case where the book is lost is a variant, its own story; "the reader is away when it arrives" is minor, an annotation.
- **Groups and their hints:** sentences 1–3 at Dana's branch; 4–6 belong to Ines, who moves stock between branches (a role takes over, and to her the book is "an item in transit", a word change); 7–9 back at the branch. These are candidates, not services. Which services to build is `container-diagram`'s question later.

## Output — the reply, and `artifacts/shelfmark/design/domain-stories/coarse-reservation.md`

> Here's a first draft of today's reservation story. I've built it from your personas and job stories, not from the librarians, so 3 of its 9 sentences are my assumptions and are marked. Read the numbered sentences at the end to Felix or Ines; every correction makes it better. The story suggests two candidate boundaries: the branch counter, and stock moving between branches, where "the book" becomes "an item in transit". Those are hints for the boundary work, not services; services are decided much later, in the architecture. Two questions for you: who tells the reader the book has arrived, and how long is it held?

````markdown
---
name: domain-story-coarse-reservation
product: shelfmark
scenario: Dana reserves a book that is held at another branch
granularity: coarse-grained
point_in_time: as-is
purity: pure
run: agent-run
variant_of: none
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-05-11
summary: Shelfmark reservation today, coarse as-is pure, agent-run; 9 sentences, 3 assumed; two candidate groups (branch counter, stock transfer).
traces-to: [ideate/personas.md, ideate/job-stories.md]
---

# Domain Story: Dana reserves a book held at another branch

**Scope:** coarse-grained / as-is / pure. **How it was made:** agent-run from the artifacts in `traces-to`: a draft, 3 of 9 sentences *assumed*.

## Roles

- **Storytellers:** none: agent-run
- **Moderator / modeller:** domain-modeler (agent-run)

## The Story

| # | Actor | Activity | Work object | To (recipient) | Annotation | Source |
|---|---|---|---|---|---|---|
| 1 | Reader | asks for | the book | Branch Librarian | At the desk | job-stories J1 |
| 2 | Branch Librarian | fills in | reservation slip | — | Book held at another branch | job-stories J1 |
| 3 | Branch Librarian | sends | reservation slip | Stock Coordinator | Daily batch | personas (Felix) |
| 4 | Stock Coordinator | finds | the item | — | At the holding branch | personas (Ines) |
| 5 | Stock Coordinator | puts | the item in transit | Delivery Van Driver | Van runs Tuesdays and Fridays | job-stories J3 |
| 6 | Delivery Van Driver | delivers | the item | Branch Librarian | — | *assumed* |
| 7 | Branch Librarian | shelves | the book | — | On the reservations shelf | job-stories J4 |
| 8 | Branch Librarian | tells | arrival note | Reader | By phone or card | *assumed* |
| 9 | Reader | collects | the book | — | Within the hold period | *assumed* |

## Variants

| Variant | Told as | Why |
|---|---|---|
| The book can't be found at the holding branch | `domain-story-coarse-reservation-lost` (its own story) | Changes who acts and ends differently |
| The reader is away when it arrives | Annotation on sentence 9 | Minor |

## Groups (candidate boundaries)

| Group | Sentences | Hint: word changes · role takes over · pace or trigger changes · hand-over |
|---|---|---|
| Branch counter | 1–3, 7–9 | Branch Librarian and Reader; "the book" |
| Stock transfer | 4–6 | Stock Coordinator takes over; "the book" becomes "the item in transit"; runs on the van's twice-weekly pace |

## Terms Found

| Term | Kind | Whose word | Note |
|---|---|---|---|
| reservation slip | work object | document term | Is it still paper? |
| item in transit | work object | document term | Ines's word for the book once it leaves |
| hold period | annotation | document term | Length unknown |

## Open Questions for the Product Owner

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | Who tells the reader the book has arrived? | Decides the actor of sentence 8 | The branch librarian |
| 2 | How long is a reserved book held? | A rule on sentence 9 | Seven days |

## Retelling (agent-run: for the product owner to check)

1. The reader asks the branch librarian for the book.
2. The branch librarian fills in a reservation slip.
3. The branch librarian sends the slip to the stock coordinator.
4. The stock coordinator finds the item at the holding branch.
5. The stock coordinator puts the item in transit with the van driver.
6. The van driver delivers the item to the branch librarian.
7. The branch librarian shelves the book on the reservations shelf.
8. The branch librarian tells the reader it has arrived.
9. The reader collects the book.

## Feeds Forward

| Output | Goes to |
|---|---|
| Terms | `ubiquitous-language` |
| Groups | `bounded-context-mapping` |
| Variants | `acceptance-criteria` |
````

## Why this is right

- The scope was picked from the question and recorded; the story has no software in it.
- It's marked agent-run with a source per sentence, never presented as told by librarians.
- The variant is its own story; the groups are candidates with hints. The question of which services to build was redirected, not answered from a discovery story.
