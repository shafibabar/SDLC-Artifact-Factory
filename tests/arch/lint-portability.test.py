#!/usr/bin/env python3
"""
tests/arch/lint-portability.test.py — contract for scripts/lint-portability.py
(#1510).

Feeds the linter small shell snippets and asserts each rule fires on the
Linux-only construct and stays quiet on the portable form:
  P1 sed -i · P2 sed escapes · P3 sed line 0 · P4 sed \\n · P5 grep -P
  P6 gawk-only · P7 Bash 4 · P8 GNU-only commands · P9 quoted replacement
plus: what must NOT be flagged (here-document bodies, comments, embedded
Python, the harness helpers, prose that mentions a command), the
`portable-ok:` suppression, purity, and the live-tree smoke run.

Standalone:  python3 tests/arch/lint-portability.test.py
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-portability.py"

spec = importlib.util.spec_from_file_location("_lint_portability_under_test", MODULE_PATH)
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-portability ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-portability ({name})")
        failed.append(name)


def rules(text: str) -> list[str]:
    return sorted({f["rule"] for f in P.lint_text(text)})


def flags(rule: str, name: str, snippet: str):
    check(f"{rule}: {name} is flagged", rules(snippet) == [rule])


def quiet(name: str, snippet: str):
    check(f"clean: {name}", rules(snippet) == [])


# --- P1 sed -i ----------------------------------------------------------------
flags("P1", "sed -i", "sed -i 's/a/b/' file.md")
flags("P1", "sed -i -E", 'sed -i -E "s/a+/b/" "$1"')
flags("P1", "sed -E -i", "sed -E -i 's/a/b/' f")
flags("P1", "sed --in-place", "sed --in-place 's/a/b/' f")
quiet("sed to a temporary file", "sed 's/a/b/' f > f.tmp && mv f.tmp f")
quiet("the harness helper sed_in_place", "sed_in_place 's/a/b/' f")
quiet("sed -n with an i in the script", "sed -n '/title/p' f")

# --- P2 sed escapes -----------------------------------------------------------
flags("P2", r"\s in a sed pattern", r"sed 's/a\s*b/X/' f")
flags("P2", r"\b in sed -E", r"echo x | sed -E 's/\bword\b/X/'")
flags("P2", r"\+ without -E", r"sed 's/a\+/X/' f")
flags("P2", r"\| without -E", r"sed 's/a\|b/X/' f")
flags("P2", r"\U case conversion", r"echo x | sed -E 's/(^|-)([a-z])/\1\U\2/g'")
quiet(r"\+ as a literal under -E", r"sed -E 's/a\+b/X/' f")
quiet("POSIX classes", "sed -E 's/[[:space:]]+/ /g' f")
quiet(r"\s in a Python regex on a line with no sed", r'check(bool(re.search(r"\bfirst\b\s", x)))')

# --- P3 sed line 0 ------------------------------------------------------------
flags("P3", "the 0,/re/ address", "sed '0,/^x/s//y/' f")
quiet("the 1,/re/ address", "sed '1,/^x/s/^x/y/' f")
quiet("a 10,/re/ address", "sed '10,/^x/d' f")

# --- P4 sed \n in a replacement -----------------------------------------------
flags("P4", r"\n in a replacement", r"sed 's/^## A$/## B\n\n## A/' f > g")
flags("P4", r"\n after & in a replacement", r"sed 's/^| a |$/&\n| b |/' f")
quiet(r"\n in the pattern only", r"sed -e ':a' -e 'N' -e 's/a\nb/ab/' f")
quiet("the harness helper sed_multiline", r"sed_multiline 's/^## A$/## B\n\n## A/' f > g")
quiet(r"printf with \n", r"printf 'a\nb\n' > f")

# --- P5 grep -P ---------------------------------------------------------------
flags("P5", "grep -P", r"grep -P '\d+' f")
flags("P5", "grep -oP", r"echo x | grep -oP 'a\K.'")
quiet("grep -E", "grep -E '[0-9]+' f")
quiet("grep for a capital P", "grep -q 'PASS' f")

# --- P6 gawk-only -------------------------------------------------------------
flags("P6", "gensub", """awk '{ print gensub(/a/, "b", 1) }' f""")
flags("P6", "three-argument match", "awk '{ match($0, /([0-9]+)/, m); print m[1] }' f")
flags("P6", "strftime", """awk 'BEGIN { print strftime("%Y") }'""")
flags("P6", "IGNORECASE", "awk 'BEGIN { IGNORECASE = 1 } /a/' f")
quiet("POSIX awk", "awk -F- '{ print toupper(substr($1, 1, 1)) substr($1, 2) }' f")
quiet("two-argument match", "awk 'match($0, /[0-9]+/) { print substr($0, RSTART, RLENGTH) }' f")

# --- P7 Bash 4 ----------------------------------------------------------------
flags("P7", "mapfile", "mapfile -t LINES < file")
flags("P7", "declare -A", "declare -A seen")
flags("P7", "local -n", "f() { local -n ref=$1; }")
flags("P7", "${x,,}", 'lower="${NAME,,}"')
flags("P7", "${x^^}", 'upper="${NAME^^}"')
flags("P7", "|&", "make |& tee log")
flags("P7", "&>>", "echo x &>> log")
flags("P7", "source <(…)", "source <(printf 'A=1\\n')")
flags("P7", "negative array index", 'last="${ARR[-1]}"')
flags("P7", "globstar", "shopt -s globstar")
quiet("a read loop instead of mapfile", "while IFS= read -r line; do A+=(\"$line\"); done < file")
quiet("tr for lower case", "lower=\"$(printf '%s' \"$NAME\" | tr '[:upper:]' '[:lower:]')\"")
quiet("|| and &&", "a || b && c")
quiet("2>&1 | tee", "make 2>&1 | tee log")
quiet("${x:-default} and ${x%%.*}", 'a="${X:-y}"; b="${X%%.*}"; c="${#ARR[@]}"')
quiet("the safe empty-array expansion", 'for t in ${A[@]+"${A[@]}"}; do :; done')

# --- P8 GNU-only commands -----------------------------------------------------
flags("P8", "timeout", 'timeout "$SECS" claude -p hi')
flags("P8", "timeout in $(…)", 'out="$(timeout 5 cmd)"')
flags("P8", "stat -c", "size=$(stat -c %s f)")
flags("P8", "date -d", 'date -d "2026-01-01" +%s')
flags("P8", "find -printf", "find . -name '*.md' -printf '%f\\n'")
flags("P8", "head -n -1", "head -n -1 f")
flags("P8", "mktemp --suffix", "mktemp --suffix=.md")
flags("P8", "tac", "tac f | head -1")
quiet("the word timeout in a message", 'expect "a sync call without a timeout fails" 1 "has a timeout" f.md')
quiet("timeout in prose inside a string", '_fail "x" "empty response (timeout or invocation error)"')
quiet("the harness helper run_with_timeout", 'run_with_timeout "$SECS" claude -p hi')
quiet("a variable named timeout", "timeout=30")
quiet("mktemp with a template", 'mktemp "${TMPDIR:-/tmp}/x.XXXXXX"')
quiet("date -u with a format", "date -u +%Y-%m-%d")
quiet("head -n 5", "head -n 5 f")

# --- P9 quoted replacement ----------------------------------------------------
flags("P9", 'a quoted replacement ${x/"a"/"b"}', 'new="${ROW/"$3"/"$4"}"')
quiet("an unquoted replacement", 'new="${ROW/$old/$new}"')
quiet("cut and rejoin", 'new="${ROW%%"$3"*}$4${ROW#*"$3"}"')

# --- what is not shell --------------------------------------------------------
quiet("a here-document body (embedded Python)", """python3 - "$1" <<'PY'
import re
last = parts[-1]
x = re.sub(r"\\bfoo\\b", "", "sed -i s/a/b/")
mapfile = 1
PY
""")
quiet("a here-document body (fixture text)", """cat > f.md <<EOF
Run `sed -i` and `timeout 5 x` and declare -A here.
EOF
""")
check("code after a here-document is read again",
      rules("cat > f <<EOF\nsed -i x\nEOF\nsed -i 's/a/b/' f\n") == ["P1"])
check("a here-string does not start a here-document",
      rules('grep -q x <<<"$OUT"\nsed -i s/a/b/ f\n') == ["P1"])
quiet("a comment line", "# sed -i is not portable, nor is mapfile")
quiet("a trailing comment", "echo ok  # not sed -i, not timeout 5")

# --- suppression --------------------------------------------------------------
quiet("portable-ok on the same line", 'timeout "$@"  # portable-ok: used only when present')
quiet("portable-ok on the line above", "# portable-ok: guarded by command -v\ntimeout 5 x")
check("portable-ok needs a reason", rules("timeout 5 x  # portable-ok:") == ["P8"])
check("portable-ok covers one line only",
      rules("# portable-ok: guarded\ntimeout 5 x\ntimeout 5 y") == ["P8"])

# --- line numbers and purity ---------------------------------------------------
found = P.lint_text("echo a\n\nsed -i 's/a/b/' f\n")
check("a finding carries its line number", [f["line"] for f in found] == [3])

with tempfile.TemporaryDirectory() as td:
    script = Path(td) / "x.sh"
    script.write_text("#!/bin/bash\nsed -i 's/a/b/' f\n")
    before = script.read_text()
    proc = subprocess.run([sys.executable, str(MODULE_PATH), str(script)], capture_output=True, text=True)
    check("CLI exits 1 on a finding", proc.returncode == 1)
    check("CLI prints file, line and rule", ":2: P1 sed-in-place" in proc.stdout)
    check("the linter never edits what it reads", script.read_text() == before)
    clean = Path(td) / "ok.sh"
    clean.write_text("#!/bin/bash\necho ok\n")
    proc = subprocess.run([sys.executable, str(MODULE_PATH), str(clean)], capture_output=True, text=True)
    check("CLI exits 0 on a clean script", proc.returncode == 0)

# --- the live tree ------------------------------------------------------------
proc = subprocess.run([sys.executable, str(MODULE_PATH), "--summary"], capture_output=True, text=True)
check("CLI --summary prints the totals block", "lint-portability summary:" in proc.stdout)
# The live tree being clean is NOT asserted here: this file runs inside the
# gate's blocking step 1, and the check is report-only for now (gate step 7).
check("it finds the repository's scripts", len(P.discover()) > 250)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for name in failed:
        print(f"  - {name}")
    sys.exit(1)
