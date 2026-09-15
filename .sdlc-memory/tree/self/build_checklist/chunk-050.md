# Chunk 50: test-fixture-design deep rebuild under skill-authoring-standards (issue #424, wave 2 of 3)

**Status:** complete

**Completed:** 2026-07-31

**Deliverables:**
- skills/test-fixture-design/SKILL.md: v1.1.0 → v2.0.0 (MAJOR: description rewritten as trigger surface, naming test-strategist, implement phase, exact capability nouns — Test Data Builder, Object Mother, hermetic fixture, t.Cleanup, golden file, parallel-safe isolation, Testcontainers, unit-vs-integration fixture strategy); related: field added (go-unit-test, go-integration-test, go-e2e-test, mock-generation); all 5 Go code blocks moved from body to references/; Object Mother vs. Test Data Builder distinction added; unit-vs-integration fixture strategy section added; cross-reference to go-integration-test's rollback-vs-tenant tradeoff added; Khorikov maintainability rationale for builders added
- skills/test-fixture-design/references/fixture-patterns-catalogue.md (new, 420 lines): 7 self-contained sections — Test Data Builder (full Go code, DataAssetBuilder), Object Mother (MakeClassifiedAsset/MakeArchivedAsset/MakeUnclassifiedAsset/SeedActiveTenant with Go code), t.Cleanup Teardown (SetupTestDB/FreshTenant Go code, why defer fires too early), Deterministic Data (fixed clock, explicit IDs, seeded rand), Golden Files (AssertGolden helper, normalizeForGolden pattern), Parallel-Safe Isolation (tenant-scoped vs. transaction rollback), Unit-Layer vs. Integration-Layer Fixtures (decision table and rule)
- tests/skills/test-fixture-design.contract.sh (new): probes SeedActiveTenant — the Object Mother factory for creating a fully-configured active tenant in the test database; this function exists only in references/, not SKILL.md body, proving progressive-disclosure split is functional
- New canonical glossary terms warranted: Object Mother, Test Data Builder (to be added in glossary-management when that skill is next touched)
- Sub-issues: #436/#438 (discovery wave 1), #439 (blueprint), #440 (content), #441 (tests), #442 (housekeeping); all merged into issue-424-test-engineering-rebuild integration branch
