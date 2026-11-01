#!/bin/bash
# Tests skills/moscow-prioritization/scripts/check-moscow.py
# — a skill-owned script exercised directly with Markdown files (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/moscow-prioritization/scripts/check-moscow.py"
T="check-moscow"

# 1. A clean standard moscow.md passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: moscow-prioritized-backlog
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-29
summary: Release 1 Musts are the three skeleton stories; two contingency stories in cut order.
profile: standard
---

## Prioritisation Agreement

- **Who decides:** the product owner.

## Must Have (Minimum Usable SubseT = walking skeleton)

| Story | Journey step | Why Must (DSDM signal) | Workaround |
|---|---|---|---|
| US-1 Ask | Ask | No point delivering | none |
| US-2 Answer | Answer | No point delivering | none |
| US-4 Unconfirmed list | Act | No point delivering | none that meets BR-2 |

## Should Have

| Story | Pain | Workaround | Kano |
|---|---|---|---|
| US-5 Waitlist offer | Phoning | Phone the waitlist | Delighter |

## Could Have

| Story | Pain | Workaround | Kano |
|---|---|---|---|
| US-3 Odd replies | Small | SMS inbox | Performance |

## Won't Have this time

| Story | Why not now | Look again |
|---|---|---|
| US-9 Paper bookings | Partners book in the app | Release 3 |

## Contingency (cut order)

1. US-3 Odd replies (Could) — least pain
2. US-5 Waitlist offer (Should) — Delighter, last

## Skeleton Check (two-way)

- Both ways hold.
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean moscow.md passes" || _fail "$T: clean moscow.md passes" "rc=$rc $out"

# 2. Each defect is caught.
expect_error() {  # expect_error <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/bad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_error "strategy phase rejected" 's/^phase: ideate/phase: strategy/' "phase is 'strategy'"
expect_error "missing summary" '/^summary:/d' "missing 'summary'"
expect_error "wrong name" 's/^name: moscow-prioritized-backlog/name: moscow/' "expected 'moscow-prioritized-backlog'"
expect_error "lean has no moscow.md" 's/^profile: standard/profile: lean/' "there is no moscow.md"
expect_error "no agreement" 's/^## Prioritisation Agreement/## Notes/' "no '## Prioritisation Agreement' section"
expect_error "no skeleton check" 's/^## Skeleton Check.*/## Checks/' "no '## Skeleton Check' section"
expect_error "enterprise needs change log" 's/^profile: standard/profile: enterprise/' "no '## Priority Change Log' section"
expect_error "Must with a workaround" 's/| US-2 Answer | Answer | No point delivering | none |/| US-2 Answer | Answer | No point delivering | phone them |/' "Must US-2: Workaround is 'phone them'"
expect_error "Must with no reason" 's/| US-1 Ask | Ask | No point delivering | none |/| US-1 Ask | Ask | | none |/' "Must US-1: no 'Why Must' reason"
expect_error "Won't with no look-again" 's/| Partners book in the app | Release 3 |/| Partners book in the app | |/' "Won't US-9: no look-again point"
expect_error "story in two bins" 's/| US-9 Paper bookings |/| US-9, US-5 Paper bookings |/' "US-5 is in more than one bin"
expect_error "Should missing from cut order" '/^2\. US-5/d' "US-5 is a Should or Could but not in the Contingency cut order"
expect_error "no numbered cut order" 's/^\([12]\)\. /- /' "Contingency has no numbered cut order"
expect_error "Must in the contingency" 's/^2\. US-5 Waitlist offer/2. US-5, US-1 Waitlist offer/' "US-1 is in the Contingency but is not a Should or Could"
expect_error "person-week estimates" 's/^- \*\*Who decides:\*\* the product owner\./- Musts: 9.5 person-weeks of 16./' "estimate found"
expect_error "capacity percentage" 's/^- Both ways hold\./- Musts are 56% of capacity./' "estimate found"

# 3. Warning: a Could cut after a Should.
sed -e 's/^1\. US-3 Odd replies (Could)/1. US-5 Waitlist offer (Should)/' -e 's/^2\. US-5 Waitlist offer (Should)/2. US-3 Odd replies (Could)/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/w.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/w.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"US-3 (Could) is cut after a Should"* ]] && _pass "$T: warns on a Could after a Should" || _fail "$T: warns on a Could after a Should" "rc=$rc $out"

# 4. --story-map: the two-way check (Must = walking skeleton).
cat > "$SCRATCH_DIR/map.md" <<'EOF'
## Story Map

| | Ask | Answer | Act |
|---|---|---|---|
| **Walking skeleton (Release 1)** | US-1 | US-2 | US-4 (manual: phone from the US-5 list) |
| **Release 2** | — | US-3 | US-5 |
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --story-map "$SCRATCH_DIR/map.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: Musts equal the skeleton" || _fail "$T: Musts equal the skeleton" "rc=$rc $out"
sed -e 's/| US-4 (manual/| US-6 (manual/' "$SCRATCH_DIR/map.md" > "$SCRATCH_DIR/map2.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --story-map "$SCRATCH_DIR/map2.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"US-4 is a Must but not on the walking skeleton"* && "$out" == *"US-6 is on the walking skeleton but not a Must"* ]] \
  && _pass "$T: two-way check catches both directions" || _fail "$T: two-way check catches both directions" "rc=$rc $out"

# 5. --backlog: every story binned.
printf '### US-1 a\n### US-2 b\n### US-3 c\n### US-4 d\n### US-5 e\n### US-9 f\n### US-10 g\n' > "$SCRATCH_DIR/backlog.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md" --backlog "$SCRATCH_DIR/backlog.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"US-10 is in the backlog but in no bin"* ]] && _pass "$T: unbinned story caught" || _fail "$T: unbinned story caught" "rc=$rc $out"

# 6. Lean: the closing Must / Won't-this-time block in the backlog.
cat > "$SCRATCH_DIR/lean.md" <<'EOF'
---
name: user-story-backlog
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-29
summary: Lean backlog closed by the Release 1 Must / Won't-this-time block.
profile: lean
---

## Stories

#### US-1: See a tool
#### US-2: Borrow a tool
#### US-3: Reminder
#### US-4: Extend

## Must / Won't-this-time — Release 1 (the walking skeleton)

Spine: find → borrow.

### Must (the walking skeleton)
| Step | Story |
|---|---|
| Find a tool | US-1 See a tool |
| Borrow it | US-2 Borrow a tool |

### Won't this time
| Story | Why not now | Look again |
|---|---|---|
| US-4 Extend | Workaround: return and re-lend | After Release 1 |

Contingency, built after the Musts if the release allows:
US-3 reminder (high).

Learning checkpoint: after four weeks, read KR-1.1.
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: lean closing block passes" || _fail "$T: lean closing block passes" "rc=$rc $out"
expect_lean() {  # expect_lean <label> <sed-expression> <expected substring>
  sed -e "$2" "$SCRATCH_DIR/lean.md" > "$SCRATCH_DIR/lbad.md"
  local out rc
  out="$(python3 "$CHK" "$SCRATCH_DIR/lbad.md")"; rc=$?
  [[ $rc -eq 1 && "$out" == *"$3"* ]] && _pass "$T: $1" || _fail "$T: $1" "rc=$rc $out"
}
expect_lean "lean block missing" 's/^## Must \/ Won.t-this-time.*/## Release 1/' "no closing '## Must / Won't-this-time' block"
expect_lean "blank skeleton step" 's/| Borrow it | US-2 Borrow a tool |/| Borrow it | — |/' "Must step 'Borrow it' has no story"
expect_lean "Won't with no reason" 's/| Workaround: return and re-lend |/| |/' "Won't US-4: no reason"
expect_lean "no contingency line" 's/^Contingency, built/Spare, built/' "no 'Contingency' line"
expect_lean "story left out of the block" 's/^US-3 reminder (high)\./reminder (high)./' "US-3 is in the backlog but not in the closing block"
expect_lean "Should label at lean" 's/^### Won.t this time/### Should Have/' "no Should / Could labels"
expect_lean "block not last" 's/^Learning checkpoint: after four weeks, read KR-1.1./&\n\n## Notes\n\nmore/' "must close the backlog"

python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 7. The skill's own worked artifacts pass (standard and enterprise moscow.md; the lean
#    block is checked on user-story-writing's Toolshed backlog, which carries the same block).
extract() {  # extract <example.md> <out> — the first fenced artifact with frontmatter
  python3 - "$1" "$2" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
b = [x[1] for x in re.findall(r"(`{3,4})markdown\n(.*?)\n\1\n", t, re.S) if x[1].startswith("---\nname:")]
open(sys.argv[2], "w").write(b[0] + "\n")
PY
}
for ex in "$REPO_ROOT"/skills/moscow-prioritization/examples/0[23]-*.md "$REPO_ROOT"/skills/user-story-writing/examples/01-lean-toolshed.md; do
  extract "$ex" "$SCRATCH_DIR/ex.md"
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 && "$out" == *"0 warning(s)"* ]] && _pass "$T: example $(basename "$(dirname "$(dirname "$ex")")")/$(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done
# The standard example agrees with story-mapping's Rebound skeleton, both ways.
extract "$REPO_ROOT/skills/moscow-prioritization/examples/02-standard-rebound.md" "$SCRATCH_DIR/reb.md"
extract "$REPO_ROOT/skills/story-mapping/examples/02-standard-rebound.md" "$SCRATCH_DIR/reb-map.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/reb.md" --story-map "$SCRATCH_DIR/reb-map.md")"; rc=$?
[[ $rc -eq 0 ]] && _pass "$T: Rebound Musts equal story-mapping's Rebound skeleton" || _fail "$T: Rebound Musts equal story-mapping's Rebound skeleton" "$out"

smoke_test_summary
