# Example 2 — Standard: a fine to-be digitalised story from a workshop, with a variant told as its own story

Self-contained. **Refillr** handles repeat prescriptions for Marsh Lane Pharmacy, at the **standard** profile. A coarse as-is pure story already exists. The product owner held a 90-minute session with the lead pharmacist and a dispenser to design how repeats will work with Refillr. The domain-modeler moderated and drew.

## Input

> **User:** "Draw the new repeat flow. Put a diamond where the GP approves or rejects, and add the app's steps onto our existing as-is picture so we see before and after together."

## Working it

- **Scope from the question:** requirements for the new system, so **fine-grained / to-be / digitalised.** Refillr and the GP surgery's system appear as actors.
- **Not onto the as-is picture.** That one is pure and as-is; this is to-be digitalised. Each story has one point in time, so this is a separate story, cross-referenced.
- **No diamond.** The usual case (the GP approves) is this story; "the GP rejects" is its own variant story. "The patient's card is declined" is minor, an annotation.
- **Recipients kept:** "Refillr sends the request *to* the GP surgery system" is where the hand-over happens.
- **Retold** at the end; the dispenser corrected sentence 6 ("I label it, then the pharmacist checks it", not the other way round).

## Output — `artifacts/refillr/design/domain-stories/fine-repeat-to-be.md`

````markdown
---
name: domain-story-fine-repeat-to-be
product: refillr
scenario: Mr Adeyemi orders his monthly repeat through Refillr and collects it
granularity: fine-grained
point_in_time: to-be
purity: digitalised
run: workshop on 2026-06-03 with lead pharmacist and dispenser
variant_of: none
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-06-03
summary: Refillr repeat order, fine to-be digitalised from a workshop; 8 sentences; the GP-rejects case is its own variant story; corrected order of labelling and checking.
traces-to: [design/domain-stories/coarse-repeat-as-is.md, session notes 2026-06-03]
---

# Domain Story: Mr Adeyemi orders his monthly repeat through Refillr

**Scope:** fine-grained / to-be / digitalised. **How it was made:** told by the lead pharmacist and a dispenser on 2026-06-03, moderated and drawn by the domain-modeler.

## Roles

- **Storytellers:** lead pharmacist, dispenser
- **Moderator / modeller:** domain-modeler

## The Story

| # | Actor | Activity | Work object | To (recipient) | Annotation | Source |
|---|---|---|---|---|---|---|
| 1 | Patient | orders | repeat request | Refillr | From the app, items ticked | session 2026-06-03 |
| 2 | Refillr | sends | repeat request | GP surgery system | — | session 2026-06-03 |
| 3 | GP | approves | prescription | — | Within two working days | session 2026-06-03 |
| 4 | GP surgery system | sends | electronic prescription | Refillr | — | session 2026-06-03 |
| 5 | Dispenser | picks | the medicines | — | From the dispensing list | session 2026-06-03 |
| 6 | Dispenser | labels | the bag | Pharmacist | Corrected in the retelling: labelling comes before the check | session 2026-06-03 |
| 7 | Pharmacist | checks | the bag | — | Against the electronic prescription | session 2026-06-03 |
| 8 | Refillr | sends | ready text | Patient | Card charged on collection; declined card → annotation | session 2026-06-03 |

## Variants

| Variant | Told as | Why |
|---|---|---|
| The GP rejects the request | `domain-story-fine-repeat-gp-rejects` (its own story) | Ends differently; the patient must be told why |
| The patient's card is declined at collection | Annotation on sentence 8 | Minor |

## Terms Found

| Term | Kind | Whose word | Note |
|---|---|---|---|
| repeat request | work object | storyteller's word | Not "order": the pharmacist was firm |
| dispensing list | work object | storyteller's word | — |
| the bag | work object | storyteller's word | The labelled bag of medicines |

## Feeds Forward

| Output | Goes to |
|---|---|
| Sentences 1, 8 (person and Refillr) | Candidate user stories |
| GP-rejects variant | `acceptance-criteria` |
| Terms | `ubiquitous-language` |
````

**The variant story** (`fine-repeat-gp-rejects.md`) tells sentences 1–2 the same, then: "3. GP rejects the repeat request, with a reason. 4. GP surgery system sends the rejection to Refillr. 5. Refillr sends the reason to the Patient." It becomes a candidate acceptance criterion: *Given a rejected repeat request, when the rejection arrives, then the patient is told the reason.*

## Why this is right

- The scope was picked from the question; to-be digitalised is its own story, never painted onto the as-is pure one.
- No diamond: the rejection is a separate story, and the minor case is an annotation.
- The recipient was kept at every hand-over, and the retelling caught a real ordering error.
