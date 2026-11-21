# Domain Story Checklist

Check each story under `artifacts/<product>/design/domain-stories/` against this list before the domain-modeler's review gate. Any "no" is fixed first.

## Before drafting

- [ ] The profile includes domain stories (skipped at lean; optional at standard and enterprise).
- [ ] Each story has one concrete scenario, named.
- [ ] Each story's three scope factors are chosen from the question: granularity, point in time, purity.

## Each story

- [ ] One case, no branches, loops or "if"; no numbered sub-steps (4a, 4b).
- [ ] Every sentence is actor – activity – work object, with the recipient kept where something is handed over.
- [ ] One verb per sentence.
- [ ] Actors are roles, never personal names, never "the system".
- [ ] A pure story shows no software; software appears only in a digitalised story.
- [ ] As-is and to-be are not mixed in one story.
- [ ] Every sentence has a Source: an artifact item, a session, or *assumed*.

## Around the story

- [ ] Important variants are their own stories, cross-referenced; minor ones are annotations.
- [ ] Coarse-grained stories have groups, each with its hint; groups are candidates, not decided contexts.
- [ ] Terms record whose word they are (the storyteller's, or a document term).
- [ ] The Feeds Forward table is filled.
- [ ] No code (D047-10); work objects and activities are named as candidate model elements at most.

## Agent-run, and at the gate

- [ ] The story is marked agent-run and never presented as told by experts.
- [ ] Every *assumed* sentence or gap is an open question for the product owner, with the assumption used meanwhile.
- [ ] The retelling is written out for the product owner to check.
- [ ] The reply says how many sentences are *assumed* and lists the open questions.
