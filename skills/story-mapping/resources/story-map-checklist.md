# Story Map Checklist

Self-contained. Run it on `ideate/story-map.md` (standard, enterprise), or on the lean Must / Won't-this-time block and any one-page map, before handing to `moscow-prioritization`. Every item must pass, or carry a written reason the user accepted. Then run `python3 ../scripts/check-story-map.py <map> [--backlog ideate/user-stories.md] [--musts <file>]` for the mechanical checks.

## Every profile

- [ ] The backbone narrates the primary persona's journey, left to right; no system stages ("ingest", "process", "store", "serve") and no UI clicks
- [ ] The spine was narrated to the user before the map was final, and what changed is recorded
- [ ] Every activity has a walking-skeleton cell: a story, an `(existing: …)` capability or a `(manual: …)` step; none blank
- [ ] The skeleton read across as one sentence completes the journey the product exists for
- [ ] Two-way Must check: every skeleton story is a Must; every Must is on the skeleton; a legal, safety or regulatory Must off the journey was added to the skeleton and marked
- [ ] No story with a workaround (even manual) is on the skeleton; its workaround is a named manual cell instead
- [ ] Only selected-path deliverables (through epics) are on the map, or the KR at lean; no option branch, no non-software deliverable as a story
- [ ] Every backlog story is placed; each gap step has a proposed story awaiting the user; nothing added to the backlog without the user
- [ ] The MVP is called a release-MVP; no fake door, concierge test or prototype is a slice
- [ ] No product-specific rule (a compliance persona, a tenant rule) is presented as a general rule

## Lean

- [ ] No `ideate/story-map.md` unless the user asked for one; no `ideate/moscow.md`
- [ ] The backlog closes with a Must / Won't-this-time block: one spine line, the skeleton stories, each Won't with a reason and when it is looked at again

## Standard and enterprise

- [ ] Frontmatter: name, version, phase (ideate), owner, created, summary, profile, primary persona, linked KR, impact map (or "none") and epics
- [ ] Big Picture cites the KR, the selected path and the primary persona; it does not re-derive them
- [ ] At least the walking skeleton and Release 2 are cut; the rest is "Later", not unplaced
- [ ] Each slice names an outcome and, added to the slices above it, leaves the journey complete for its users
- [ ] No slice finishes one activity or one component while later steps wait
- [ ] Each slice has a signal and a re-cut trigger, copied from the impact map where one exists
- [ ] The roadmap revision trigger is noted

## Enterprise only

- [ ] Several personas share one backbone, named per activity (a separate backbone only for a journey that never touches the others' work)
- [ ] The skeleton crosses tenant set-up and isolation for **one** tenant or pilot segment; other tenants are later slices
- [ ] Regulatory Musts on the skeleton are marked with their rule
- [ ] NFR hand-off items that bind skeleton stories are listed
- [ ] Epics from every impact map the journey crosses are placed
- [ ] A re-cut log exists
