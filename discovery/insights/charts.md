# SKILL GEN Project: Insights chart catalog (#1266)

This is for a scrum master or PM reading the board at
<https://github.com/users/shafibabar/projects/1/insights>. Each chart answers
one question. The fields it uses are filled from evidence by
`scripts/github-project/ghp/insights.py`. Field definitions and rules are in
`scripts/github-project/README.md` § Insights fields.

| # | Chart | Question | Layout | X-axis | Y-axis | Group by | Filter |
|---|---|---|---|---|---|---|---|
| 1 | Campaign burn-up | Will Fresh-Eyes land? | Stacked area (historical) | Time | Count | (status) | `campaign:Fresh-Eyes is:issue` |
| 2 | Sprint velocity | Are we speeding up? | Stacked column | Sprint | Sum Effort-Points | Work-Type | `is:closed is:issue` |
| 3 | Sprint throughput | How much flows through? | Stacked column | Sprint | Count | Hierarchy | `is:closed` |
| 4 | WIP & flow | Where is work piling up? | Stacked bar | Status | Count | Hierarchy | `-status:Done` |
| 5 | Hierarchy shape | How is each campaign broken down? | Stacked column | Campaign | Count | Hierarchy | `is:issue` |
| 6 | Purpose mix | What kind of work is each campaign? | Stacked column | Campaign | Count | Work-Type | `is:issue` |
| 7 | Cycle time by type | What is slow? | Column | Work-Type | Avg Cycle-Days | — | `is:closed is:issue` |
| 8 | Duration spread | How long do items live? | Stacked column | Duration | Count | Hierarchy | `is:closed` |
| 9 | Complexity vs time | Does size predict duration? | Column | Complexity | Avg Cycle-Days | — | `is:closed is:issue` |
| 10 | Complexity per sprint | Is the load changing? | Stacked column | Sprint | Count | Complexity | `is:issue` |
| 11 | Branch flow | How does code reach main? | Stacked bar | Branch-Type | Count | Merge-Target | `is:pr` |
| 12 | Priority backlog | What is open and how urgent? | Stacked bar | Priority | Count | Status | `is:open` |
| 13 | Bug severity | How bad are the defects? | Stacked column | Severity | Count | Status | `work-type:Bug is:issue` |
| 14 | Dependency risk | What is blocked? | Stacked bar | Dependency | Count | Priority | `is:issue -status:Done` |
| 15 | Data trust | How much is triaged vs derived? | Bar | Data-Source | Count | Priority | — |

## Baseline at backfill (2026-10-12, 1,276 items)

- **Hierarchy:** Standalone 420 · Sub-issue PR 379 · Direct PR 237 · Sub-issue 200 · Parent 24 · Integration PR 16
- **Campaign:** Skill-Refactor 634 · Arch-Review 442 · Maintenance 68 · Fresh-Eyes 54 · Foundation 44 · Research 34
- **Priority:** P2 950 · P1 248 · P3 71 · P0 7. **Severity** (bugs): S1 5 · S2 5 · S3 14
- **Complexity:** XS 512 · S 208 · M 234 · L 259 · XL 63
- **Duration:** <1h 1,098 · <1d 130 · 1–3d 7 · 3–7d 7 · >7d 9 · open 25
- **Sprint:** Sprint 03 (07-20 → 08-02) holds 1,195 items. That matches git history: the Skill-Refactor and Arch-Review bursts both landed in that window.

## Reading caveats

1. **Every pre-2026-10-12 value is Derived** (chart 15). Priority and Severity for past items come from keyword and link rules, not triage. Read them as indicators.
2. **Duration measures machine time plus approval time.** Most sub-issues close in under an hour because Claude executes them. Human approval waits show up on parents and integration PRs, not on sub-issues.
3. **In Review is mostly skipped** for integration-branch sub-issues (exec-complete auto-merges). Measure review time on Integration PRs (Hierarchy = Integration PR).
4. **Arch-Review ran as standalone `[P<n>]` issues**, not native sub-issues. Its PRs are linked to issues by branch slug (`arch-review/p2-<skill>` → `[P2] enrich <skill>`).
5. **XS is real, not missing data.** The 189 P2 enrichment PRs were 3-line frontmatter edits.
6. **Paused campaigns inflate calendar lead time.** Arch-Review is paused at P5 (5/15).
