# Chunk 46: Deep rebuild: skill-authoring-standards (issue #422, PR #423)

**Status:** complete

**Completed:** 2026-07-30

**Deliverables:**
- scripts/validate-skill-structure.sh — new governance script checking 7 required frontmatter fields in canonical order, body line count ≤200, and bidirectional references/ pointer integrity (body mentions file ↔ file exists on disk). Exit 0 = all pass, exit 1 = failures. 15/15 synthetic tests passing in tests/scripts/validate-skill-structure.test.sh (no live model call).
- skills/skill-authoring-standards/references/vocabulary-and-collision-detection.md — formally defines the six named terms the SKILL.md body uses: Trigger Surface, Resident Content, Skill Collision, Progressive Disclosure, Declared Composability, Self-Contained Reference. Includes Periodic Collision Detection guidance with a known-adjacent skill pairs table (5 pairs identified by grep, sampled 3-5 per batch, judgment check not automated CI).
- skills/skill-authoring-standards/assets/skill-template.md — minimal copyable SKILL.md starter with all 7 required frontmatter fields in canonical order, the four-section body structure (Purpose, Core Section, Quality Criteria, Anti-Patterns), and placeholder commentary for writing the description as a trigger surface rather than a summary.
- skills/skill-authoring-standards/SKILL.md — version 1.0.0 → 1.1.0 (MINOR: new content, description unchanged). Added related: [glossary-management, methodology-review]. Added vocabulary pointer sentence in Purpose section pointing to references/vocabulary-and-collision-detection.md. Added two pointers in Applying section: assets/skill-template.md (starter template) and scripts/validate-skill-structure.sh (structural validation). Fixed two body false-positives that fooled the validator: cross-skill reference example using the exact references/<file>.md grep pattern rephrased to avoid matching, and Anti-Patterns example rephrased similarly.
- tests/skills/skill-authoring-standards.contract.sh — updated from the 200-line threshold question (answerable from body) to a Skill Collision symptom question ('answers questions it does not own') answerable only from references/vocabulary-and-collision-detection.md, proving the progressive-disclosure split is followed.
