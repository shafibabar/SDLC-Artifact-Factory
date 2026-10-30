#!/bin/bash
# Tests skills/story-mapping/scripts/check-story-map.py
# — a skill-owned script exercised directly with Markdown files (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/story-mapping/scripts/check-story-map.py"
T="check-story-map"

# 1. A clean standard story map passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: story-map
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-28
summary: Front-desk no-show journey with a three-story walking skeleton.
profile: standard
---

## Big Picture

- **Outcome:** KR-2.1

## Narrated Spine

First the appointment is in the diary, then the patient answers, then the front desk follows up.

## Story Map

| | Fill the diary | Patients answer | Act before the cut-off |
|---|---|---|---|
| **Tasks** | Book | Confirm or cancel | See unconfirmed |
| **Walking skeleton (Release 1)** | (existing: diary booking) | US-1, US-2 | US-4 (manual: phone from the US-1 list) |
| **Release 2 — refills run themselves** | — | US-3 | US-5 |

## Release Slices

### Release 1 — Walking Skeleton

**Outcome:** the front desk knows who is not coming.
**MVP kind:** Release-MVP, not a learning experiment
**Signal:** reply rate
**Re-cut trigger:** reply rate under 70% after four weeks

### Release 2 — Refills run themselves

**Outcome:** freed slots reach the waitlist.
**Signal:** slots refilled per week
**Re-cut trigger:** as Release 1

## Must Check (walking skeleton = Minimum Usable SubseT)

- **Skeleton → Must:** US-1, US-2, US-4.

## Gaps, Orphans and Open Questions

None.
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean story map passes" || _fail "$T: clean story map passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "bad profile" 's/^profile: standard/profile: huge/' "is not lean, standard or enterprise"
expect_error "broken skeleton (dash)" 's/| (existing: diary booking) |/| — |/' "walking skeleton is broken: no cell under 'Fill the diary'"
expect_error "broken skeleton (blank)" 's/| US-1, US-2 |/|  |/' "no cell under 'Patients answer'"
expect_error "no skeleton row" 's/Walking skeleton (Release 1)/First row/' "no 'Walking skeleton' row"
expect_error "no release 2 at standard" '/^| \*\*Release 2/d' "no release slice below the walking skeleton"
expect_error "story placed twice" 's/| US-3 | US-5 |/| US-3 | US-5, US-2 |/' "US-2 is placed in 2 cells"
expect_error "no release-MVP statement" '/^\*\*MVP kind/d' "release-MVP"
expect_error "slice without signal" '/^\*\*Signal:\*\* slots refilled/d' "'Release 2 — Refills run themselves' has no Signal line"
expect_error "slice without re-cut trigger" '/^\*\*Re-cut trigger:\*\* as Release 1/d' "has no Re-cut trigger line"
expect_error "no Must Check" 's/^## Must Check.*/## Priorities/' "no '## Must Check' section"
expect_error "no narrated spine" 's/^## Narrated Spine/## Spine/' "no '## Narrated Spine' section"
expect_error "enterprise needs re-cut log" 's/^profile: standard/profile: enterprise/' "no '## Re-cut Log' section"

# 3. Lean needs only the spine and the map.
sed -e 's/^profile: standard/profile: lean/' -e '/^## Must Check/,$d' -e '/^## Big Picture/,/^## Narrated Spine/{/^## Narrated Spine/!d}' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/lean.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: lean one-page map passes" || _fail "$T: lean one-page map passes" "rc=$rc $out"

# 4. Warning: a system-stage activity.
sed -e 's/| | Fill the diary | Patients answer |/| | Ingest | Patients answer |/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"names a system stage"* ]] && _pass "$T: warns on a system-stage activity" || _fail "$T: warns on a system-stage activity" "rc=$rc $out"

# 5. --backlog: orphans are errors, stories missing from the backlog are warnings.
printf '### US-1 a\n### US-2 b\n### US-3 c\n### US-4 d\n### US-5 e\n### US-6 f\n' > "$SCRATCH_DIR/backlog.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --backlog "$SCRATCH_DIR/backlog.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"US-6 is in the backlog but not on the map"* ]] && _pass "$T: orphan story caught" || _fail "$T: orphan story caught" "rc=$rc $out"
printf '### US-1 a\n### US-2 b\n### US-3 c\n### US-4 d\n' > "$SCRATCH_DIR/backlog2.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --backlog "$SCRATCH_DIR/backlog2.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"US-5 is on the map but not in the backlog"* ]] && _pass "$T: gap story warned" || _fail "$T: gap story warned" "rc=$rc $out"

# 6. --musts: the two-way check (Must = walking skeleton).
printf '## Must\n- US-1\n- US-2\n- US-4\n\n## Won'"'"'t this time\n- US-5\n' > "$SCRATCH_DIR/musts-ok.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --musts "$SCRATCH_DIR/musts-ok.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: Musts equal the skeleton" || _fail "$T: Musts equal the skeleton" "rc=$rc $out"
printf '## Must\n- US-1\n- US-2\n- US-5\n' > "$SCRATCH_DIR/musts-bad.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --musts "$SCRATCH_DIR/musts-bad.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"US-5 is a Must but not on the walking skeleton"* && "$out" == *"US-4 is on the walking skeleton but not a Must"* ]] \
  && _pass "$T: two-way Must check catches both directions" || _fail "$T: two-way Must check catches both directions" "rc=$rc $out"

python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 7. The skill's own worked story maps (standard, enterprise) pass cleanly.
for ex in "$REPO_ROOT"/skills/story-mapping/examples/0[23]-*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S)
     if x[1].startswith("---\nname: story-map")]
open(sys.argv[2], "w").write(b[0][1])
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
