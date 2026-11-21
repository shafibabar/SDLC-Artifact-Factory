# Domain Storytelling: Notation

The detail behind `SKILL.md` § 3: the pictographic language, how to write each sentence, how to read a story back, and the shapes that don't belong. Grounded in Hofer & Schwentner (*Domain Storytelling*), as summarised in `research/domain-driven-design/domain-storytelling-hofer-schwentner.md`. Conventions marked *house* are this plugin's, not the book's.

## 1. The sentence

> **[Actor] – activity → [Work object] (→ to [Actor])**

"The receptionist **books** the appointment." "The patient **sends** the repeat request **to** the pharmacist."

- **One verb per sentence.** "Checks and files" is two sentences, two arrows. Each verb is a candidate term in the language.
- **The storyteller's verb, in the present tense.** "Approves", not "approval" or "is approving".
- **A recipient comes after a preposition** and is an actor. Don't drop it to force three parts; the hand-over is often the most important thing in the sentence.

## 2. The elements

| Element | Draw as | Rules |
|---|---|---|
| **Actor** | An icon for a person, a group or a software system, with a role name | A role, never a personal name ("Customs Broker", not "Priya"). Never "the system": ask which system, or who. Drawn once, reused |
| **Work object** | An icon chosen for the domain (a document, a parcel, a phone call, money, an email), with the teller's name for it | The teller's word, not the implementation's ("the slip", not "the record"). Drawn once, reused |
| **Activity** | A labelled arrow from actor to work object, and on to a recipient | One verb; numbered |
| **Sequence number** | On the arrow | The order told. Two arrows may share a number when they happen at the same time |
| **Annotation** | Free text near an arrow or object | Conditions ("only for controlled drugs"), minor variants, example data, comments |
| **Group** | A labelled outline around part of the story | An organisation, a place, a subdomain, or a candidate boundary, with the hint recorded |

**The icon set is open.** The book picks icons to suit the domain; there is no fixed set of shapes. *House convention:* in a digitalised story, draw an external system with a dashed outline so hand-overs to software outside the product stand out.

## 3. Reading a story back

1. Find sentence 1.
2. Say it in full: "[Actor] [verb] [work object] (to [recipient])."
3. Follow the numbers in order. A work object passed on reappears in the next sentence.
4. At each group boundary, say what changes: the word, the role, the pace, the hand-over.
5. Read each annotation where it applies.

A story drawn well reads as plain sentences to someone who wasn't there. Reading it back to the people who do the work is the method's main check.

## 4. What doesn't belong

| Shape | Why it fails | Instead |
|---|---|---|
| **Decision diamond, branch, loop** | A story is one concrete case; a branch hides two stories | Tell each important case as its own story; a minor one is an annotation |
| **Swim lanes** | Turns sentences into a grid and loses the hand-overs | Actors drawn once; groups where boundaries matter |
| **Flowchart or BPMN shapes** | Imports another notation; readers can't tell what a box means | Actors, work objects, activities, numbers, annotations, groups only |
| **"The system"** | Hides who does the work | Name the system, or in a pure story the person |
| **Compound arrows** ("checks and files") | Loses a verb | One arrow per verb |
| **Technical work objects in a pure story** ("database row", "API call") | A pure story has no software | Use the teller's words; software belongs in a separate digitalised story |
| **Numbered sub-steps for variants** (4a, 4b) | A branch in disguise | A separate story |

## 5. Tools

- **Egon.io:** the authors' free, open-source browser modeller. It draws the language with an adjustable icon set, replays a story sentence by sentence, and exports images and its own story file.
- **Any shared canvas** (a whiteboard, paper, a general drawing tool) also works. Keep the legend visible, and use one frame per story.

The transcript in `../templates/domain-story.md` is the artifact the plugin keeps; a picture is attached when one exists.
