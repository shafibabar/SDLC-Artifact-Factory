#!/bin/bash
# validate-python-contract-tests.sh <file-or-directory>...
# Text-pattern checks on Python contract-test code and the files that run it:
# *.py, *.yml, *.yaml, *.sh, *.toml and Makefile. .git, .venv, node_modules,
# __pycache__ and site-packages are skipped. It needs neither Python packages
# nor Docker and runs nothing: it finds known mistakes that make a contract
# check pass without checking, it does not prove a test is good.
# Exit 0 = no FAIL (each WARN needs judgement), 1 = at least one FAIL,
# 2 = usage error, missing path or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-python-contract-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import os, re, sys

SKIP = {".git", ".venv", "venv", "node_modules", "__pycache__", "site-packages", ".pytest_cache"}
found = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in SKIP)
            found += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)

def kind(path):
    name = os.path.basename(path)
    if name.endswith(".py"):
        return "py"
    if name.endswith((".yml", ".yaml")):
        return "yaml"
    if name.endswith(".sh"):
        return "sh"
    if name.endswith(".toml"):
        return "toml"
    if name in ("Makefile", "makefile") or name.endswith(".mk"):
        return "make"
    return None

files = [(f, kind(f)) for f in found if kind(f)]
if not files:
    print("ERROR: no .py, .yml, .yaml, .sh, .toml or Makefile given; nothing was checked")
    sys.exit(2)

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

def line_of(text, index):
    return text[:index].count("\n") + 1

def parts(path):
    return os.path.normpath(path).split(os.sep)

PY_NOISE = re.compile(r'"""(?:\\.|[^\\])*?"""|\'\'\'(?:\\.|[^\\])*?\'\'\'|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|#[^\n]*')
def py_code(raw):
    """Python source with comments and docstrings blanked, one-line strings kept, line numbers unchanged."""
    def keep(match):
        text = match.group(0)
        if text.startswith("#") or text.startswith(('"""', "'''")):
            return "\n" * text.count("\n")
        return text
    return PY_NOISE.sub(keep, raw)

serving, writing = [], []
GATE = r"(oasdiff\s+breaking|can-i-deploy|check-openapi-breaking|check-event-compatibility|buf\s+breaking)"
PACT_RUN = r"(pytest[^\n]*(pact_tests|-m\s+[\"']?pact\b)|\bmake\s+[^\n]*\bpact-(consumer|provider)\b|pact(-broker|\s+broker)\s+publish)"

def check_py(path, raw):
    code = py_code(raw)
    def each(pattern, level, rule, message, flags=0):
        for match in re.finditer(pattern, code, flags):
            report(level, rule, path, line_of(code, match.start()), message)
    uses_pact = re.search(r"(?m)^\s*(from\s+pact(\.[\w.]+)?\s+import|import\s+pact\b)", code)
    if uses_pact and "tests" in parts(path)[:-1]:
        report("FAIL", "PACTPLACE", path, line_of(code, uses_pact.start()),
               "Pact code under tests/: make ci collects that folder; Pact tests live in pact_tests/ and run daily")
    each(r"(?m)^\s*from\s+pact\.v2\b|^\s*from\s+pact\s+import\s+[^\n]*\b(Consumer|Provider)\b", "FAIL", "OLDAPI",
         "pact-python 4 removed pact.v2 (Consumer, Provider); use Pact and Verifier from pact")
    each(r"\bupon_receiving\([^)]*,\s*[\"'](Async|Sync)[\"']|\.message_handler\(", "FAIL", "MESSAGEPACT",
         "message pact; events are checked by schema, not by Pact")
    each(r"\bconsumer_version\([^)]*\blatest\s*=\s*True", "FAIL", "LATEST",
         "latest=True is the newest pact from any branch; select main_branch, matching_branch and deployed_or_released", re.S)
    each(r"\bset_error_on_empty_pact\(\s*enabled\s*=\s*False", "FAIL", "NOPACTS",
         "a verification that finds no pact then passes")
    each(r"\.add_custom_headers?\((?=[^)]*[\"']authorization[\"'])", "FAIL", "CUSTOMHEADER",
         "add_custom_header also adds the header to a request recorded without one; swap the token in a wrapper that only replaces", re.I | re.S)
    each(r"\b(Async)?Client\(\s*app\s*=", "FAIL", "APPSHORTCUT", "httpx removed app=; use transport=httpx.ASGITransport(app=...)")
    each(r"\bfrom_asgi\(", "FAIL", "SERVEDSPEC",
         "schemathesis from_asgi reads the description the app serves, not the authored file; load api/openapi.yaml")
    verifier = re.search(r"\bbroker_source\(", code)
    if verifier:
        if not re.search(r"\.include_pending\(\)", code):
            report("WARN", "PENDING", path, line_of(code, verifier.start()),
                   "no include_pending(); a consumer's new expectation fails the provider's run at once")
        if not re.search(r"\bset_error_on_empty_pact\(\s*\)", code):
            report("WARN", "NOPACTS", path, line_of(code, verifier.start()),
                   "set_error_on_empty_pact() is not stated; say that zero pacts is a failure")
    handler = re.search(r"\.state_handler\(", code)
    if handler and not re.search(r"\bteardown\s*=\s*True", code):
        report("WARN", "STATEGUARD", path, line_of(code, handler.start()),
               "no teardown=True; nothing resets the provider between interactions, so an unmatched state can pass")
    serve = re.search(r"\.serve\(\)", code)
    if serve:
        serving.append((path, line_of(code, serve.start())))
    if re.search(r"\.write_file\(", code):
        writing.append(path)
    validator = re.search(r"\bDraft\d+Validator\(|\bjsonschema\.validate\(", code)
    if validator and "format_checker" not in code:
        report("FAIL", "FORMAT", path, line_of(code, validator.start()),
               "no format_checker; a bad uuid or date-time passes")
    if re.search(r"\b(respx|ProviderDouble|MockTransport)\b", code):
        each(r"\bASGITransport\(", "WARN", "PROVIDERAPP",
             "a consumer test that drives an app in-process imports the provider; use a double checked against its description")
    if re.search(r"\brespx_mock\b", code) and not re.search(r"assert_all_called", code):
        report("WARN", "UNCALLED", path, line_of(code, re.search(r"\brespx_mock\b", code).start()),
               "the bare respx_mock fixture does not fail on a route that was never called")
    each(r"\bextra\s*=\s*[\"']forbid[\"']", "WARN", "UNKNOWNFIELDS",
         "a consumer model that rejects unknown fields breaks on an additive change")
    each(r"\bdef\s+\w*(backward|forward|full)_?compat\w*\(", "WARN", "OWNCHECKER",
         "hand-written compatibility checker; the event gate script runs the declared mode and the add-only pass")
    if {"contract", "pact_tests"} & set(parts(path)):
        each(r"\bpytest\.(mark\.)?(skip|skipif|xfail)\b", "WARN", "SKIPPED",
             "a skipped contract case is a documented response nobody exercised")

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

HEREDOC = re.compile(r"<<-?\s*[\"']?([A-Za-z_][A-Za-z0-9_]*)[\"']?")
def without_heredocs(raw):
    """A shell script with the bodies of here-documents blanked (they are data or another program)."""
    out, end = [], None
    for line in raw.split("\n"):
        if end is not None:
            if line.strip() == end:
                end = None
            out.append("")
            continue
        start = HEREDOC.search(line)
        if start and not line.lstrip().startswith("#"):
            end = start.group(1)
        out.append(line)
    return "\n".join(out)

def check_text(path, raw, sort):
    lines = logical_lines(without_heredocs(raw) if sort == "sh" else raw)
    for number, text in lines:
        if "can-i-deploy" in text and "--dry-run" in text:
            report("FAIL", "DRYRUN", path, number, "can-i-deploy --dry-run always exits 0")
        if "can-i-deploy" in text and re.search(r"(--output|-o)[= ]\s*json", text) and not re.search(r"(^|[^2&])>\s*\S", text):
            report("WARN", "JSONEXIT", path, number,
                   "can-i-deploy --output json exits 0 even when the answer is no; save it for the report, never use it as the deployment check")
        if re.search(r"oasdiff\s+breaking", text) and "--fail-on" not in text:
            report("FAIL", "NOFAILON", path, number, "oasdiff breaking without --fail-on exits 0 on a breaking change")
        if "MISSING-VERSION-BUMP" in text:
            report("FAIL", "VERSIONBUMP", path, number,
                   "passes a breaking change when info.version is raised; a breaking change is a new version beside the old one")
        if re.search(GATE, text) and re.search(r"\|\|\s*(true|:|exit\s+0)\b|;\s*true\s*$", text):
            report("FAIL", "IGNORED", path, number, "the result of a contract gate is discarded")
        if re.search(r"pactflow\.io|PACTFLOW_", text, re.I):
            report("FAIL", "PAID", path, number, "PactFlow is a paid service; use the self-hosted open-source Pact Broker unless the product owner approved it")
        if re.search(r"\bpact-verifier\b", text):
            report("FAIL", "OLDAPI", path, number, "pact-python 4 removed the pact-verifier command; verification is a pytest test")
        if re.search(r"-m\s+[\"']?contract\b", text):
            report("FAIL", "CONTRACTMARKER", path, number,
                   "no test carries a contract marker, so this selects nothing; contract tests are plain tests in make ci")
        if sort == "toml" and re.search(r"^\s*addopts\s*=", text) and re.search(r"-m\b|--ignore|--deselect", text):
            report("FAIL", "ADDOPTS", path, number, "test selection in addopts hides tests from every run; select on the command line")
    joined = "\n".join(text for _, text in lines)
    if sort == "yaml":
        runs_pact = re.search(PACT_RUN, joined)
        trigger = re.search(r"(?m)^\s*(pull_request|pull_request_target|push)\s*:|^\s*on\s*:\s*\[?[^\n]*\b(pull_request|push)\b", joined)
        if runs_pact and trigger:
            report("FAIL", "PACTONPR", path, line_of(joined, trigger.start()),
                   "Pact runs on a pull request or push; it runs on a daily schedule (and by hand for a commit about to deploy)")
        if re.search(GATE, joined):
            for match in re.finditer(r"(?m)^\s*continue-on-error\s*:\s*true\b", joined):
                report("WARN", "CONTINUE", path, line_of(joined, match.start()),
                       "continue-on-error in a workflow with a contract gate; it must not sit on the gate's step")
    if sort == "make":
        target = None
        for number, text in lines:
            header = re.match(r"^([A-Za-z0-9_.-]+)\s*:(?!=)(.*)$", text)
            if header:
                target = header.group(1)
                if target in ("ci", "test") and re.search(r"\bpact-(consumer|provider)\b", header.group(2)):
                    report("FAIL", "PACTINCI", path, number, f"target '{target}' depends on a Pact target; Pact stays out of make ci")
            if target in ("ci", "test", "lint", "typecheck") and re.search(PACT_RUN, text):
                report("FAIL", "PACTINCI", path, number, f"target '{target}' runs Pact; Pact stays out of make ci and runs daily")

pact_tests, marked, settings = [], False, []
for path, sort in files:
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)
    if sort == "py":
        check_py(path, raw)
        if "pact_tests" in parts(path)[:-1]:
            name = os.path.basename(path)
            if name == "conftest.py" and re.search(r"\bmark\.pact\b", py_code(raw)):
                marked = True
            elif name.startswith("test_") and not re.search(r"\bmark\.pact\b", py_code(raw)):
                pact_tests.append(path)
    else:
        check_text(path, raw, sort)
        if sort == "toml" and re.search(r"(?m)^\[tool\.pytest", raw):
            settings.append((path, raw))

if serving and not writing:
    for path, line in serving:
        report("WARN", "NOWRITE", path, line, "no write_file() in the files given; pact-python does not write the pact file by itself")
if pact_tests and not marked:
    for path in pact_tests:
        report("FAIL", "NOMARKER", path, 1, "no pact marker here and no conftest.py in pact_tests/ adds one; -m pact selects nothing")
if any("pact_tests" in parts(path) for path, _ in files):
    for path, raw in settings:
        if not re.search(r"[\"']pact\s*:", raw):
            report("FAIL", "UNREGISTERED", path, 1, "the pact marker is not registered under markers; with strict settings every Pact run errors")

print(f"checked {len(files)} file(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
