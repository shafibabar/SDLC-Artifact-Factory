#!/bin/bash
# Tests skills/jtbd-analysis/scripts/check-jtbd-analysis.py — a skill-owned
# script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/jtbd-analysis/scripts/check-jtbd-analysis.py"
T="check-jtbd-analysis"

# 1. A clean standard analysis passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: jtbd-analysis
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-20
summary: One job; target outcome is never chasing a client who has paid.
profile: standard
evidence: ideate/interviews/snapshots/2026-10-14-dp-4.md
ranking: compare-and-contrast (n = 5 design partners)
---

## Evidence

| Snapshot | Date |
|---|---|
| [2026-10-14-dp-4] | 2026-10-14 |

## J-1: Collect

**Job statement (Ulwick):** Collect overdue client payments without damaging the client relationship

### What gets fired

| Alternative | Who | Evidence |
|---|---|---|
| Spreadsheet | DP-4 | [2026-10-14-dp-4] |

- **Big Hire:** the trial recovers money on the firm's ledger
- **Little Hire:** Monday approval in minutes

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | Friday afternoons | [2026-10-14-dp-4] |
| Pull | Let it run | [2026-10-14-dp-4] |
| Anxiety | Reminder to a client who paid | [2026-10-14-dp-4] |
| Habit | The spreadsheet | [2026-10-14-dp-4] |

#### JS-1.1: Friday batch

When the week ends with thirty invoices past due, I want to know which clients I can safely chase,
so I can send every reminder before I leave.

- **Evidence:** [2026-10-14-dp-4]

#### JS-1.2: Partner asks

When a partner asks about a 60-day debt, I want to show what was sent, so I can answer on the spot.

- **Evidence:** [assumption] — validate with DP-2

### Desired outcomes

| ID | Desired-outcome statement | Directional rating (n = 5) | Rank |
|---|---|---|---|
| O-1.1 | Minimize the likelihood a reminder reaches a client who has paid | 9 | 1 |

## Onboarding Requirements

| ID | Requirement | From |
|---|---|---|
| ONB-1 | Preview before send | J-1 anxiety |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean analysis passes" || _fail "$T: clean analysis passes" "rc=$rc $out"

# 2. The defects the skill names: Strategy phase, missing evidence field,
#    a job story under the job-statement label, no fired list / Little Hire,
#    a forces table with pull only, an uncited story, a story citing an
#    unlisted snapshot, a story not in job-story form, opportunity scored
#    on a whole job, bad arithmetic, and no onboarding section.
cat > "$SCRATCH_DIR/bad.md" <<'EOF'
---
name: jtbd-analysis
version: 1.0.0
phase: strategy
owner: requirements-analyst
created: 2026-10-20
summary: Jobs.
profile: standard
ranking: opportunity score
---

## Evidence

| Snapshot | Date |
|---|---|
| [2026-10-14-dp-4] | 2026-10-14 |

## Core Jobs

| ID | Job | Importance | Satisfaction | Opportunity |
|---|---|---|---|---|
| J-1 | Collect | 9 | 3 | 15 |

## J-1: Collect

**Job statement (Ulwick):** When an invoice is overdue, I want to chase it, so I can get paid.

- **Big Hire:** money recovered

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Pull | Automation | — |

#### JS-1.1: Batch

When the week ends, I want to see a report, so I can relax.

- **Evidence:** DP-4 said so

#### JS-1.2: Partner

When a partner asks, I want to show the history, so I can answer.

- **Evidence:** [2026-10-09-dp-3]

#### JS-1.3: Sensitive

The partner decides who is chased.

- **Evidence:** [2026-10-14-dp-4]

### Desired outcomes

| ID | Statement | Importance | Satisfaction | Opportunity |
|---|---|---|---|---|
| O-1.1 | Minimize the time to prepare reminders | 7 | 4 | 12 |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
[[ $rc -eq 1 ]] && _pass "$T: defective analysis exits 1" || _fail "$T: defective analysis exits 1" "rc=$rc $out"
[[ "$out" == *"phase is 'strategy'"* ]] && _pass "$T: rejects phase strategy" || _fail "$T: rejects phase strategy" "$out"
[[ "$out" == *"missing 'evidence'"* ]] && _pass "$T: requires evidence field" || _fail "$T: requires evidence field" "$out"
[[ "$out" == *"J-1: the job statement is in job-story form"* ]] && _pass "$T: job statement vs job story" || _fail "$T: job statement vs job story" "$out"
[[ "$out" == *"J-1: no 'What gets fired' section"* ]] && _pass "$T: requires what gets fired" || _fail "$T: requires what gets fired" "$out"
[[ "$out" == *"J-1: no Little Hire line"* ]] && _pass "$T: requires Little Hire" || _fail "$T: requires Little Hire" "$out"
[[ "$out" == *"forces table lacks push, anxiety, habit"* ]] && _pass "$T: four forces" || _fail "$T: four forces" "$out"
[[ "$out" == *"JS-1.1: Evidence cites no snapshot and is not tagged [assumption]"* ]] && _pass "$T: story must cite" || _fail "$T: story must cite" "$out"
[[ "$out" == *"JS-1.2: cites snapshot [2026-10-09-dp-3] that is not listed"* ]] && _pass "$T: citation must be listed" || _fail "$T: citation must be listed" "$out"
[[ "$out" == *"JS-1.3: not in 'When…, I want to…, so I can…' form"* ]] && _pass "$T: job-story form" || _fail "$T: job-story form" "$out"
[[ "$out" == *"row 'J-1': opportunity scored on a whole job"* ]] && _pass "$T: no whole-job score" || _fail "$T: no whole-job score" "$out"
[[ "$out" == *"row 'O-1.1': Opportunity 12.0 ≠ 7.0 + max(7.0 − 4.0, 0) = 10.0"* ]] && _pass "$T: opportunity arithmetic" || _fail "$T: opportunity arithmetic" "$out"
[[ "$out" == *"WARNING: no '## Onboarding Requirements' section"* ]] && _pass "$T: warns on no onboarding" || _fail "$T: warns on no onboarding" "$out"

# 3. Lean profile is refused; evidence: none with a citation is refused;
#    numeric scores under compare-and-contrast need the "directional" label.
sed -e 's/profile: standard/profile: lean/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/lean.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"skipped at lean"* ]] && _pass "$T: lean has no artifact" || _fail "$T: lean has no artifact" "rc=$rc $out"
sed -e 's#^evidence: .*#evidence: none#' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/none.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/none.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"but frontmatter says 'evidence: none'"* ]] && _pass "$T: no invented evidence" || _fail "$T: no invented evidence" "rc=$rc $out"
python3 - "$SCRATCH_DIR/ok.md" "$SCRATCH_DIR/dir.md" <<'PY'
import sys
t = open(sys.argv[1]).read()
t = t.replace("| ID | Desired-outcome statement | Directional rating (n = 5) | Rank |\n|---|---|---|---|\n| O-1.1 | Minimize the likelihood a reminder reaches a client who has paid | 9 | 1 |",
              "| ID | Desired-outcome statement | Importance | Satisfaction | Opportunity |\n|---|---|---|---|---|\n| O-1.1 | Minimize the likelihood a reminder reaches a client who has paid | 9 | 3 | 15 |")
open(sys.argv[2], "w").write(t)
PY
out="$(python3 "$CHK" "$SCRATCH_DIR/dir.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"label small-sample ratings 'directional'"* ]] && _pass "$T: small-n scores labelled directional" || _fail "$T: small-n scores labelled directional" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 4. The skill's own worked analyses (standard, enterprise) pass.
for ex in "$REPO_ROOT"/skills/jtbd-analysis/examples/0[23]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"```markdown\n(.*?)\n```\n", t, re.S) if x.startswith("---\nname: jtbd-analysis")]
open(sys.argv[2], "w").write(b[0])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
