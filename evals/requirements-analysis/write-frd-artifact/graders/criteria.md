---
type: llm
weight: 1
---

The artifact satisfies ALL of the following:
1. It begins with a frontmatter block containing at least name, version, phase, owner, created and a one-sentence summary, with phase "ideate"; and every user requirement (or every requirement group) traces both to a selected-path deliverable by ID (SOL-1 or SOL-3) and to a job statement together with a job story beneath it by ID (for example J-1 → JS-1.1).
2. The options that were not selected (SOL-2 refund credit, the native mobile app) are not written as requirements; they are explicitly recorded as excluded, deferred or parked (for example in an exclusions list or waiting room).
3. Each functional requirement has a measurable pass/fail fit criterion or acceptance condition (stating inputs and an observable result, not just a test type such as "integration test"; a requirement whose details are still open may instead be held on an open-questions / TBD list rather than in the requirements table), and the coordinator's "instantly" and "99.9%" are not written into functional requirements as targets: they are handed to the NFR specification (or a quality-attribute / NFR hand-off list) instead.
4. Priorities are marked provisional (for example high / medium / low) and stated to be finalised later by MoSCoW prioritisation; no requirement is labelled Must, Should, Could or Won't. The pool policies (8-child limit, same-level swaps) appear as business rules referenced by the requirements rather than restated in each one.
Fail if any of the four is missing.
