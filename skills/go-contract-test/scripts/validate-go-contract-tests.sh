#!/bin/bash
# validate-go-contract-tests.sh <file-or-directory>...
# Text-pattern checks on contract-test code and the pipeline files that run
# it: *.go, *.yml, *.yaml, *.sh and Makefile. vendor/, testdata/, node_modules/
# and .git are skipped. It needs neither Go nor Docker and runs nothing: it
# finds known mistakes that make a contract check pass without checking, it
# does not prove a test is good.
# Exit 0 = no FAIL (each WARN needs judgement), 1 = at least one FAIL,
# 2 = usage error, missing path or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-go-contract-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import os, re, sys

found = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in {".git", "vendor", "testdata", "node_modules"})
            found += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)

def kind(path):
    name = os.path.basename(path)
    if name.endswith(".go"):
        return "go"
    if name.endswith((".yml", ".yaml")):
        return "yaml"
    if name.endswith(".sh") or name in ("Makefile", "makefile") or name.endswith(".mk"):
        return "make" if not name.endswith(".sh") else "sh"
    return None

files = [(f, kind(f)) for f in found if kind(f)]
if not files:
    print("ERROR: no .go, .yml, .yaml, .sh or Makefile given; nothing was checked")
    sys.exit(2)

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

def line_of(text, index):
    return text[:index].count("\n") + 1

GO_COMMENT = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|`[^`]*`', re.S)
def go_code(raw):
    """Go source with comments blanked and strings kept, line numbers unchanged."""
    return GO_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n") if m.group(0).startswith("/") else m.group(0), raw)

GATE = r"(oasdiff\s+breaking|can-i-deploy|check-openapi-breaking|check-event-compatibility|buf\s+breaking)"
PACT_RUN = r"(-tags[= ]\s*\"?[\w,]*\bpact\b|pact-broker\s+publish|\bpublish\s+\S*pacts)"

def check_go(path, raw):
    code = go_code(raw)
    uses_pact = re.search(r'"github\.com/pact-foundation/pact-go/', code)
    if uses_pact and not re.search(r"(?m)^//go:build\b.*\bpact\b", raw):
        report("FAIL", "PACTTAG", path, line_of(code, uses_pact.start()),
               "Pact code without '//go:build pact'; every build would need the native library and the broker")
    for match in re.finditer(r'"github\.com/pact-foundation/pact-go/v2/message[/"]', code):
        report("FAIL", "MESSAGEPACT", path, line_of(code, match.start()),
               "message pact; events are checked by schema, not by Pact")
    for match in re.finditer(r"\bLatest:\s*true\b", code):
        report("FAIL", "LATEST", path, line_of(code, match.start()),
               "Latest: true is the newest pact from any branch; select MainBranch, MatchingBranch and DeployedOrReleased")
    for match in re.finditer(r"\bSoftFail:\s*true\b", code):
        report("FAIL", "SOFTFAIL", path, line_of(code, match.start()), "SoftFail makes a failed verification pass")
    request = re.search(r"\bVerifyRequest\s*\{", code)
    if request:
        if not re.search(r"\bFailIfNoPactsFound:\s*true\b", code):
            report("FAIL", "NOPACTS", path, line_of(code, request.start()),
                   "no FailIfNoPactsFound: true; a verification that finds no pact passes")
        if re.search(r"\bStateHandlers:", code) and not re.search(r"\bBeforeEach:", code):
            report("WARN", "STATEGUARD", path, line_of(code, request.start()),
                   "no BeforeEach reset; a Provider State name with no handler runs without setup and may pass")
    validate = re.search(r"\bopenapi3filter\.ValidateResponse\(", code)
    if validate and not re.search(r"\bIncludeResponseStatus:\s*true\b", code):
        report("FAIL", "STATUS", path, line_of(code, validate.start()),
               "no IncludeResponseStatus: true; an undocumented status passes validation")
    compiler = re.search(r"\bjsonschema\.NewCompiler\(\)", code)
    if compiler and not re.search(r"\.AssertFormat\(\)", code):
        report("FAIL", "FORMAT", path, line_of(code, compiler.start()),
               "no AssertFormat(); a bad uuid or date-time passes")
    for match in re.finditer(r"\.DisallowUnknownFields\(\)", code):
        report("WARN", "UNKNOWNFIELDS", path, line_of(code, match.start()),
               "a consumer that rejects unknown fields breaks on an additive change")

def logical_lines(raw):
    """(first line number, text) with backslash continuations joined and # comments dropped."""
    out, buffer, start = [], "", 0
    for number, line in enumerate(raw.split("\n"), 1):
        text = re.sub(r"(^|\s)#.*$", "", line)
        if not buffer:
            start = number
        if text.rstrip().endswith("\\"):
            buffer += text.rstrip()[:-1] + " "
            continue
        out.append((start, buffer + text))
        buffer = ""
    if buffer:
        out.append((start, buffer))
    return out

def check_text(path, raw, sort):
    lines = logical_lines(raw)
    for number, text in lines:
        if re.search(r"can-i-deploy", text) and "--dry-run" in text:
            report("FAIL", "DRYRUN", path, number, "can-i-deploy --dry-run always exits 0")
        if re.search(r"oasdiff\s+breaking", text) and "--fail-on" not in text:
            report("FAIL", "NOFAILON", path, number, "oasdiff breaking without --fail-on exits 0 on a breaking change")
        if "MISSING-VERSION-BUMP" in text:
            report("FAIL", "VERSIONBUMP", path, number,
                   "passes a breaking change when info.version is raised; a breaking change is a new version beside the old one")
        if re.search(GATE, text) and re.search(r"\|\|\s*(true|:|exit\s+0)\b|;\s*true\s*$", text):
            report("FAIL", "IGNORED", path, number, "the result of a contract gate is discarded")
        if re.search(r"pactflow\.io|PACTFLOW_", text, re.I):
            report("FAIL", "PAID", path, number, "PactFlow is a paid service; use the self-hosted open-source Pact Broker unless the product owner approved it")
    joined = "\n".join(text for _, text in lines)
    if sort == "yaml":
        runs_pact = re.search(PACT_RUN, joined)
        trigger = re.search(r"(?m)^\s*(pull_request|pull_request_target|push)\s*:|^\s*on\s*:\s*\[?[^\n]*\b(pull_request|push)\b", joined)
        if runs_pact and trigger:
            report("FAIL", "PACTONPR", path, line_of(joined, trigger.start()) ,
                   "Pact runs on a pull request or push; it runs on a daily schedule (and by hand for a commit about to deploy)")
        if re.search(GATE, joined):
            for match in re.finditer(r"(?m)^\s*continue-on-error\s*:\s*true\b", joined):
                report("WARN", "CONTINUE", path, line_of(joined, match.start()),
                       "continue-on-error in a workflow with a contract gate; it must not sit on the gate's step")
    if sort == "make":
        target = None
        for number, text in lines:
            header = re.match(r"^([A-Za-z0-9_.-]+)\s*:(?!=)", text)
            if header:
                target = header.group(1)
            if target in ("ci", "test", "cover") and re.search(PACT_RUN, text):
                report("FAIL", "PACTINCI", path, number,
                       f"target '{target}' runs Pact; Pact stays out of make ci, behind the pact build tag")

for path, sort in files:
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)
    if sort == "go":
        check_go(path, raw)
    else:
        check_text(path, raw, sort)

print(f"checked {len(files)} file(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
