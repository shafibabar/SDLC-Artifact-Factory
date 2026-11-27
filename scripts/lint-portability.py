#!/usr/bin/env python3
"""
scripts/lint-portability.py — flags shell constructs that work on Linux but
fail, or silently behave differently, on stock macOS (#1510).

Every shell script in this repository must run the same on Linux (GNU tools,
Bash 5) and on stock macOS (BSD sed/awk/grep, Bash 3.2). Each rule below was
observed on macOS 26 with nothing from Homebrew on the PATH; the ones marked
SILENT exit 0 and give a different result, which is why a test suite alone
does not catch them.

  P1 sed-in-place     `sed -i` — BSD sed reads the next word as a backup suffix
  P2 sed-escape       GNU-only escapes in a sed script: \\s \\w \\b \\< \\> and, without
                      -E, \\+ \\? \\| (SILENT: the pattern just stops matching);
                      \\U \\L \\u \\l case conversion (SILENT: prints a literal letter)
  P3 sed-line-zero    the `0,/re/` address — BSD sed has no line 0
  P4 sed-newline      `\\n` in the replacement of `s///` (SILENT: prints the letter n)
  P5 grep-perl        `grep -P` — BSD grep has no Perl mode
  P6 awk-gnu          gawk-only: gensub, asort, asorti, strftime, systime,
                      PROCINFO, three-argument match; IGNORECASE and \\< \\> (SILENT)
  P7 bash-4           Bash 4+ only: mapfile/readarray, declare -A, local -n,
                      ${x,,} ${x^^}, |&, &>>, globstar, EPOCHSECONDS, wait -n,
                      ${x@Q}, printf %(…)T, negative array index, coproc;
                      `source <(…)` (SILENT: sources nothing on Bash 3.2)
  P8 gnu-command      GNU-only commands and options: timeout, tac, nproc, shuf,
                      numfmt, stat -c, date -d, find -printf, head -n -N,
                      mktemp --suffix, cp --parents, ln -r, du -b, xargs -d
  P9 quoted-replace   ${x/"a"/"b"} — Bash 3.2 keeps the replacement's quotes (SILENT)

What it reads: every `*.sh` under skills/, scripts/, tests/, hooks/, commands/
and .claude/. Comment lines and the bodies of here-documents are skipped (a
here-document here is fixture text or an embedded Python program, never
shell). A finding is silenced by `portable-ok: <reason>` in a comment on the
same line or the line above — for a construct that is guarded, e.g. a GNU
command used only after `command -v` finds it.

Not checked, because a line scan cannot see it: an empty array expanded under
`set -u` (Bash 3.2 calls it unbound — write `${a[@]+"${a[@]}"}`), `wc -l`
output compared as text (BSD pads it with spaces), and paths compared without
resolving (/tmp is a link on macOS). Those are in skill-authoring-standards
and are caught by running the tests on both systems in CI.

Usage:
  python3 scripts/lint-portability.py             # every finding
  python3 scripts/lint-portability.py --summary   # counts per rule
  python3 scripts/lint-portability.py <file...>   # only these files
Exit: 0 when clean, 1 when there are findings (the gate decides whether that blocks).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("skills", "scripts", "tests", "hooks", "commands", ".claude")

RULES = {
    "P1": "sed-in-place",
    "P2": "sed-escape",
    "P3": "sed-line-zero",
    "P4": "sed-newline",
    "P5": "grep-perl",
    "P6": "awk-gnu",
    "P7": "bash-4",
    "P8": "gnu-command",
    "P9": "quoted-replace",
}

# A command word: at the start, or after a pipe, list operator, subshell or `$(`.
_CMD = r"(?:^|[|;&(`{]|\$\(|\bthen\b|\bdo\b|\belse\b|\bxargs\b|\bexec\b)\s*"
_SED = re.compile(_CMD + r"(?:command\s+)?sed\s")
_AWK = re.compile(_CMD + r"(?:command\s+)?[gm]?awk\s")
_GREP = re.compile(_CMD + r"(?:command\s+)?[ef]?grep\s")

_SED_INPLACE = re.compile(r"\bsed\s+(?:-[A-Za-z]+\s+)*-[A-Za-z]*i\b|\bsed\s+(?:-\S+\s+)*--in-place")
_SED_EXTENDED = re.compile(r"\bsed\s+(?:-\S+\s+)*-[A-Za-z]*[Er]")
_SED_GNU_ESCAPE = re.compile(r"\\[swSWbB<>]")
_SED_BRE_ONLY = re.compile(r"\\[+?|]")
_SED_CASE = re.compile(r"\\[ULul](?![A-Za-z])|\\[ULul]\\[0-9&]")
_SED_LINE_ZERO = re.compile(r"""(?:['"\s]|-e\s*)0,\s*/""")
_SED_SUBST = re.compile(r"s([/#|,@!:])((?:\\.|(?!\1).)*)\1((?:\\.|(?!\1).)*)\1")
_GREP_PERL = re.compile(r"\bgrep\s+(?:-\S+\s+)*-[A-Za-z]*P|\bgrep\s+(?:-\S+\s+)*--perl-regexp")
_AWK_GNU = re.compile(
    r"\b(?:gensub|asorti?|strftime|systime|mktime|patsplit)\s*\(|\bIGNORECASE\b|\bPROCINFO\b"
    r"|\\[<>]|\bmatch\s*\([^()]*,[^()]*,[^()]*\)"
)
_BASH4 = re.compile(
    r"\b(?:mapfile|readarray|coproc)\b"
    r"|\b(?:declare|local|typeset)\s+-[A-Za-z]*[An]\b"
    r"|\$\{[A-Za-z_][A-Za-z_0-9]*(?:\[[^\]]*\])?(?:,,?|\^\^?)[^}]*\}"
    r"|\$\{[A-Za-z_][A-Za-z_0-9]*(?:\[[^\]]*\])?@[A-Za-z]\}"
    r"|\$\{[A-Za-z_][A-Za-z_0-9]*\[-[0-9]+\]\}"
    r"|\|&|&>>"
    r"|\bshopt\s+(?:-\S+\s+)*globstar\b"
    r"|\bEPOCH(?:SECONDS|REALTIME)\b"
    r"|\bwait\s+-[A-Za-z]*n\b"
    r"|%\([^)]*\)T"
    r"|(?:\bsource|(?:^|[;&|]\s*)\.)\s+<\("
)
_GNU_CMD = re.compile(
    r"(?:^|[|;&`]|\$\()\s*(?:timeout|tac|nproc|shuf|numfmt)\b(?=\s*(?:$|[-\"'$0-9|)<]))"
    r"|\bstat\s+(?:-\S+\s+)*(?:-c\b|--format|--printf)"
    r"|\bdate\s+(?:-\S+\s+)*(?:-d\b|--date)"
    r"|\bfind\b.*\s-printf\b"
    r"|\bhead\s+(?:-\S+\s+)*-n\s*-[0-9]"
    r"|\bmktemp\s+(?:-\S+\s+)*--(?:suffix|tmpdir)"
    r"|\bcp\s+(?:-\S+\s+)*--parents"
    r"|\bln\s+(?:-\S+\s+)*-[A-Za-z]*r[A-Za-z]*\b"
    r"|\bdu\s+(?:-\S+\s+)*-[A-Za-z]*b\b"
    r"|\bxargs\s+(?:-\S+\s+)*-d\b"
)
_QUOTED_REPLACE = re.compile(r"\$\{[A-Za-z_][A-Za-z_0-9]*//?[^}]*/\"[^}]*\"\}")

_HEREDOC = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z_0-9]*)\1")
_SUPPRESS = re.compile(r"#.*\bportable-ok:\s*\S")


def _strip_comment(line: str) -> str:
    """Drop a trailing `# …` comment that is not inside quotes (best effort)."""
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "\\":
            i += 2
            continue
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1].isspace()):
            return line[:i]
        i += 1
    return line


def shell_lines(text: str):
    """Yield (line number, code, suppressed) for each shell line: here-document
    bodies and comment lines are left out; a sed/awk script that runs over
    several lines stays attached to the line that starts it."""
    lines = text.split("\n")
    terminator = None
    dash = False
    previous_suppresses = False
    for number, raw in enumerate(lines, 1):
        if terminator is not None:
            candidate = raw.lstrip("\t") if dash else raw
            if candidate == terminator:
                terminator = None
            continue
        stripped = raw.strip()
        suppressed = previous_suppresses or bool(_SUPPRESS.search(raw))
        previous_suppresses = stripped.startswith("#") and bool(_SUPPRESS.search(raw))
        if not stripped or stripped.startswith("#"):
            continue
        code = _strip_comment(raw)
        m = _HEREDOC.search(code)
        if m and "<<<" not in code[max(0, m.start() - 1):m.start() + 3]:
            terminator, dash = m.group(2), code[m.start():m.start() + 3] == "<<-"
        yield number, code, suppressed


def lint_text(text: str) -> list[dict]:
    """All findings for one script's text. Pure."""
    findings: list[dict] = []

    def add(rule, number, message):
        findings.append({"rule": rule, "line": number, "message": message})

    for number, code, suppressed in shell_lines(text):
        if suppressed:
            continue
        if _SED_INPLACE.search(code):
            add("P1", number, "`sed -i` is not portable; write to a temporary file and move it back")
        if _SED.search(code):
            extended = bool(_SED_EXTENDED.search(code))
            if _SED_GNU_ESCAPE.search(code) or (not extended and _SED_BRE_ONLY.search(code)):
                add("P2", number, "GNU-only escape in a sed pattern; use a POSIX class "
                                  "([[:space:]], [[:alnum:]_]) and `sed -E` for + ? |")
            if _SED_CASE.search(code):
                add("P2", number, "sed case conversion (\\U \\L) is GNU-only; use awk toupper/tolower or tr")
            if _SED_LINE_ZERO.search(code):
                add("P3", number, "the `0,/re/` address is GNU-only; use `1,/re/` or awk")
            for m in _SED_SUBST.finditer(code):
                if re.search(r"(?<!\\)(?:\\\\)*\\n", m.group(3)):
                    add("P4", number, "`\\n` in a sed replacement is GNU-only; use awk, or a "
                                      "backslash followed by a real line break")
                    break
        if _GREP.search(code) and _GREP_PERL.search(code):
            add("P5", number, "`grep -P` is GNU-only; use `grep -E` with POSIX classes")
        if _AWK.search(code) and _AWK_GNU.search(code):
            add("P6", number, "gawk-only function or variable; stay within POSIX awk")
        if _BASH4.search(code):
            add("P7", number, "needs Bash 4 or newer; macOS ships Bash 3.2")
        if _GNU_CMD.search(code):
            add("P8", number, "GNU-only command or option; absent on stock macOS")
        if _QUOTED_REPLACE.search(code):
            add("P9", number, "quoted replacement in ${x/a/\"b\"}: Bash 3.2 keeps the quotes; "
                              "cut and rejoin with ${x%%…} and ${x#…}")
    return findings


def lint_file(path: Path) -> list[dict]:
    try:
        text = path.read_text(errors="replace")
    except OSError as exc:
        return [{"rule": "P0", "line": 0, "message": f"cannot read: {exc}"}]
    return lint_text(text)


def discover(root: Path = REPO_ROOT) -> list[Path]:
    files: list[Path] = []
    for name in SCAN_DIRS:
        base = root / name
        if base.is_dir():
            files.extend(p for p in base.rglob("*.sh") if p.is_file())
    return sorted(files)


def main(argv: list[str]) -> int:
    summary = "--summary" in argv
    named = [a for a in argv if not a.startswith("--")]
    files = [Path(a).resolve() for a in named] if named else discover()

    counts = {rule: 0 for rule in RULES}
    dirty = 0
    for path in files:
        found = lint_file(path)
        if found:
            dirty += 1
        for f in found:
            counts[f["rule"]] = counts.get(f["rule"], 0) + 1
            if not summary:
                shown = path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path
                print(f"{shown.as_posix()}:{f['line']}: {f['rule']} "
                      f"{RULES.get(f['rule'], 'error')}: {f['message']}")
    total = sum(counts.values())
    if summary or total:
        print("lint-portability summary:")
        print(f"  scripts clean  {len(files) - dirty}/{len(files)}")
        for rule, label in RULES.items():
            print(f"  {rule} {label:<15} {counts[rule]}")
        print(f"  TOTAL          {total} finding(s)")
    else:
        print(f"lint-portability: {len(files)} script(s) clean.")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
