#!/bin/bash
# validate-go-mutation-setup.sh [<product-root>]
#
# Checks a Go product's mutation-testing setup against go-mutation-test (decision
# D048 and the mutation decisions of 2026-11-28), before any run. Reads, under
# <product-root> (the Go module root, also the repository root):
#   .gremlins.yaml, mutation/mutant-record.txt, mutation/exclusions.txt,
#   Makefile, .github/workflows/*.y*ml, scripts/*.sh, every non-test .go file.
# FAIL (exit 1):
#   - .gremlins.yaml missing; a key Gremlins v0.6.0 does not have (it is ignored
#     silently: threshold-efficacy as a flat key, excludes, ...); a threshold that
#     is not 0; any of the eleven mutant types not enabled; test-cpu (every mutant
#     then reports KILLED), dry-run or diff in the file
#   - exclude-files that leave out product code other than generated code, test
#     support under internal/test/ or an approved mutation/exclusions.txt entry
#   - a suppression comment (//gremlins:..., //nomutant): Gremlins has none
#   - Gremlins unpinned (@latest, no exact vX.Y.Z), run directly instead of
#     through run-go-mutation.sh, or given --threshold-* or --test-cpu
#   - a percentage on a mutation line (no percentage gate: every mutant is killed
#     or recorded); a masked exit status (|| true, continue-on-error)
#   - a mutation workflow triggered by release (that runs after publication), no
#     scheduled run, a schedule less often than monthly, or no workflow whose
#     publishing job needs the mutation job
#   - make mutation missing, using --diff, or not judging with --mode release
#   - a malformed record or exclusion line; the two scripts not copied in
# WARN (exit 0): timeout-coefficient under 10; coverpkg without integration; a
#   pull_request trigger; checkout without fetch-depth: 0; pending exclusions;
#   mutation-out/ not in .gitignore.
# Exit 0 = no FAIL, 1 = at least one FAIL, 2 = usage.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, os, re, sys

if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1].startswith("-")):
    print("usage: validate-go-mutation-setup.sh [<product-root>]")
    sys.exit(2)
root = os.path.realpath(sys.argv[1] if len(sys.argv) == 2 else ".")
if not os.path.isfile(os.path.join(root, "go.mod")):
    print(f"usage: no go.mod in {root}")
    sys.exit(2)
fails, warns = [], []
def fail(where, msg): fails.append(f"FAIL: {where}: {msg}")
def warn(where, msg): warns.append(f"WARN: {where}: {msg}")
def rel(p): return os.path.relpath(p, root)
def text(path):
    try:
        return open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        return None

MUTANTS = ("arithmetic-base", "conditionals-boundary", "conditionals-negation", "increment-decrement",
           "invert-assignments", "invert-bitwise", "invert-bwassign", "invert-logical", "invert-loopctrl",
           "invert-negatives", "remove-self-assignments")
UNLEASH = ("dry-run", "output-statuses", "output", "tags", "coverpkg", "workers", "test-cpu",
           "timeout-coefficient", "integration", "exclude-files", "diff", "threshold.efficacy",
           "threshold.mutant-coverage")
KNOWN = {"silent"} | {"unleash." + k for k in UNLEASH} | {f"mutants.{m}.enabled" for m in MUTANTS}

def parse_yaml(src):
    """Indentation-based reader for the plain YAML Gremlins' file uses:
    nested mappings, scalars, and lists of scalars. Returns {dotted key: (value, line)}."""
    flat, stack = {}, []
    for n, raw in enumerate(src.splitlines(), 1):
        line = re.sub(r"\s+#.*$", "", raw) if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        body = line.strip()
        if body.startswith("- "):
            parent = ".".join(k for _, k in stack)
            value, _ = flat.get(parent, ([], n))
            if not isinstance(value, list):
                value = []
            flat[parent] = (value + [body[2:].strip().strip("'\"")], n)
            continue
        m = re.match(r"([A-Za-z0-9_.-]+)\s*:\s*(.*)$", body)
        if not m:
            flat[f"<line {n}>"] = (body, n)
            continue
        while stack and stack[-1][0] >= indent:
            stack.pop()
        key, value = m.group(1), m.group(2).strip()
        dotted = ".".join([k for _, k in stack] + [key])
        flow = re.fullmatch(r"\{\s*(.*?)\s*\}", value)
        if flow:
            for part in filter(None, (p.strip() for p in flow.group(1).split(","))):
                k, _, v = part.partition(":")
                flat[f"{dotted}.{k.strip()}"] = (v.strip().strip("'\""), n)
        elif value:
            flat[dotted] = (value.strip("'\""), n)
        else:
            stack.append((indent, key))
            flat.setdefault(dotted, (None, n))
    return flat

def number(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None

# --- the exclusions register and the record --------------------------------------
approved, pending = [], []
reg = os.path.join(root, "mutation", "exclusions.txt")
for n, l in enumerate((text(reg) or "").splitlines(), 1):
    if not l.strip() or l.lstrip().startswith("#"):
        continue
    p = [x.strip() for x in l.split("|")]
    ok = len(p) == 3 and p[0] and len(p[2]) >= 10 and (p[1] == "pending" or re.fullmatch(r"approved \d{4}-\d{2}-\d{2}", p[1]))
    if ok and p[1] != "pending":
        try:
            datetime.date.fromisoformat(p[1][9:])
        except ValueError:
            ok = False
    if not ok:
        fail(f"mutation/exclusions.txt:{n}", "write <path or folder/> | approved YYYY-MM-DD | <reason>, or | pending | while awaiting the product owner")
    elif p[1] == "pending":
        pending.append(p[0])
        warn(f"mutation/exclusions.txt:{n}", f"{p[0]} awaits the product owner and is not excluded until approved")
    else:
        approved.append(p[0])

rec = os.path.join(root, "mutation", "mutant-record.txt")
for n, l in enumerate((text(rec) or "").splitlines(), 1):
    if not l.strip() or l.lstrip().startswith("#"):
        continue
    p = [x.strip() for x in l.split("|")]
    ok = (len(p) == 6 and re.fullmatch(r"\S+\.go:\d+:\d+", p[0]) and re.fullmatch(r"[A-Z_]+", p[1])
          and p[2] in ("equivalent", "timeout", "not-viable") and re.fullmatch(r"[0-9a-f]{12}", p[3])
          and len(p[4]) >= 10 and not p[4].startswith("<") and re.fullmatch(r".+ \d{4}-\d{2}-\d{2}", p[5]))
    if not ok:
        fail(f"mutation/mutant-record.txt:{n}", "write <file>:<line>:<col> | <TYPE> | equivalent|timeout|not-viable | "
             "<fingerprint from check-go-mutation.sh> | <reason> | <who> <YYYY-MM-DD>")

# --- .gremlins.yaml ---------------------------------------------------------------
cfg_path = os.path.join(root, ".gremlins.yaml")
cfg_src = text(cfg_path)
GENERATED = re.compile(r"^// Code generated .* DO NOT EDIT\.$", re.M)
if cfg_src is None:
    fail(".gremlins.yaml", "missing at the module root")
else:
    cfg = parse_yaml(cfg_src)
    for key, (value, n) in sorted(cfg.items(), key=lambda kv: kv[1][1]):
        if value is None and any(k.startswith(key + ".") for k in KNOWN):
            continue
        if key not in KNOWN:
            fail(f".gremlins.yaml:{n}", f"'{key}' is not a Gremlins v0.6.0 setting and is ignored without a warning")
    for key in ("unleash.threshold.efficacy", "unleash.threshold.mutant-coverage"):
        value, n = cfg.get(key, ("0", 0))
        if number(value) != 0:
            fail(f".gremlins.yaml:{n}", f"{key} is {value}: keep it 0; the verdict is check-go-mutation.sh's, never a percentage")
    off = [m for m in MUTANTS if str(cfg.get(f"mutants.{m}.enabled", ("", 0))[0]).lower() != "true"]
    if off:
        fail(".gremlins.yaml", "enable every mutant type (six are off by default): " + ", ".join(off))
    tc, n = cfg.get("unleash.test-cpu", ("0", 0))
    if number(tc) not in (0, None):
        fail(f".gremlins.yaml:{n}", "test-cpu makes Gremlins pass '-cpu N' as one argument; go test then fails and every mutant reports KILLED")
    for key, why in (("unleash.dry-run", "a dry run tests nothing"), ("unleash.diff", "the release run covers everything; the runner adds --diff only for scheduled runs")):
        value, n = cfg.get(key, ("", 0))
        if value not in ("", None, "false", '""'):
            fail(f".gremlins.yaml:{n}", f"{key} is set: {why}")
    coef, n = cfg.get("unleash.timeout-coefficient", (None, 0))
    if number(coef) is None or number(coef) < 10:
        warn(f".gremlins.yaml:{n or 1}", "timeout-coefficient under 10: on a fast module most mutants then report TIMED OUT and need the runner's recheck")
    if cfg.get("unleash.coverpkg", ("", 0))[0] and str(cfg.get("unleash.integration", ("false", 0))[0]).lower() != "true":
        warn(".gremlins.yaml", "coverpkg without integration: a mutant covered only by another package's tests is run against its own package's tests and reports LIVED")
    patterns = []
    for p in cfg.get("unleash.exclude-files", ([], 0))[0] or []:
        try:
            patterns.append((p, re.compile(p.replace("\\\\", "\\"))))
        except re.error:
            fail(".gremlins.yaml", f"exclude-files pattern does not compile: {p}")
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if not x.startswith(".") and x not in ("vendor", "testdata", "mutation-out")]
        for f in files:
            if not f.endswith(".go") or f.endswith("_test.go"):
                continue
            name = rel(os.path.join(d, f)).replace(os.sep, "/")
            src = text(os.path.join(d, f)) or ""
            for n, line in enumerate(src.splitlines(), 1):
                if re.search(r"//\s*(gremlins:|nomutant|nolint:\s*gremlins)", line):
                    fail(f"{name}:{n}", "Gremlins has no suppression comment; kill the mutant or record it in mutation/mutant-record.txt")
            hit = [p for p, rx in patterns if rx.search(name)]
            if not hit:
                continue
            head = src.split("\npackage ", 1)[0]
            if f.endswith("_moq.go") or GENERATED.search(head) or name.startswith("internal/test/"):
                continue
            if any(name == a or (a.endswith("/") and name.startswith(a)) for a in approved):
                continue
            why = "before the product owner approved it" if any(name == a or (a.endswith("/") and name.startswith(a)) for a in pending) else "without an exclusion in mutation/exclusions.txt"
            fail(".gremlins.yaml", f"exclude-files {hit[0]} leaves out {name} {why}")

# --- Makefile, workflows, scripts -------------------------------------------------
files = []
for name in ("Makefile", "makefile", "GNUmakefile"):
    if os.path.isfile(os.path.join(root, name)):
        files.append(os.path.join(root, name))
wf_dir = os.path.join(root, ".github", "workflows")
workflows = sorted(os.path.join(wf_dir, f) for f in (os.listdir(wf_dir) if os.path.isdir(wf_dir) else [])
                   if f.endswith((".yml", ".yaml")))
scripts_dir = os.path.join(root, "scripts")
own = ("run-go-mutation.sh", "check-go-mutation.sh", "validate-go-mutation-setup.sh")
for f in own[:2]:
    if not os.path.isfile(os.path.join(scripts_dir, f)):
        fail(f"scripts/{f}", "missing: copy it from go-mutation-test unchanged")
others = sorted(os.path.join(scripts_dir, f) for f in (os.listdir(scripts_dir) if os.path.isdir(scripts_dir) else [])
                if f.endswith(".sh") and f not in own)
pinned_var = None
for path in files + workflows + others:
    src = text(path) or ""
    for n, line in enumerate(src.splitlines(), 1):
        where = f"{rel(path)}:{n}"
        low = line.lower()
        v = re.match(r"\s*GREMLINS_VERSION\s*:?=\s*(\S+)", line)
        if v:
            pinned_var = v.group(1)
            if not re.fullmatch(r"v\d+\.\d+\.\d+", pinned_var):
                fail(where, f"GREMLINS_VERSION is {pinned_var}: pin an exact version such as v0.6.0")
        if "go-gremlins/gremlins" in line and "install" in line:
            at = re.search(r"gremlins@(\S+)", line)
            ver = at.group(1) if at else ""
            if ver in ("$(GREMLINS_VERSION)", "${GREMLINS_VERSION}", "$GREMLINS_VERSION"):
                ver = pinned_var or ver
            if not re.fullmatch(r"v\d+\.\d+\.\d+", ver):
                fail(where, f"Gremlins installed as {'@' + ver if ver else 'unpinned'}: pin an exact version (pre-1.0 releases change their settings)")
        if re.search(r"(^|[\s;&|(])gremlins\s+(unleash|run|r)\b", line):
            fail(where, "Gremlins run directly: run it through scripts/run-go-mutation.sh, which pins the config, rechecks and records the commit")
        if re.search(r"--threshold-(efficacy|mcover)|--test-cpu", line):
            fail(where, "Gremlins thresholds and --test-cpu are not used (CLI thresholds are ignored by v0.6.0; --test-cpu makes every mutant KILLED)")
        if re.search(r"mutation|gremlins|mutant|efficacy", low) and re.search(r"\b\d{1,3}(\.\d+)?\s*%", line):
            fail(where, "a percentage on a mutation line: there is no percentage target; every mutant is killed or recorded")
        if ("mutation" in low or "gremlins" in low) and re.search(r"\|\|\s*true|;\s*true\s*$", line):
            fail(where, "the exit status is masked")

make_src = "\n".join(text(p) or "" for p in files)
target = re.search(r"^mutation\s*:[^\n=]*\n((?:\t[^\n]*\n?)+)", make_src, re.M)
if not target:
    fail("Makefile", "no mutation target (the full run before each release)")
else:
    recipe = target.group(1)
    if "--diff" in recipe:
        fail("Makefile", "make mutation uses --diff: the release run covers the whole module")
    if "run-go-mutation.sh" not in recipe or not re.search(r"check-go-mutation\.sh[^\n]*--mode\s+release", recipe):
        fail("Makefile", "make mutation must run scripts/run-go-mutation.sh, then scripts/check-go-mutation.sh --mode release")

mut_wf = []
for path in workflows:
    src = text(path) or ""
    if not re.search(r"make\s+mutation|run-go-mutation\.sh", src):
        continue
    mut_wf.append(path)
    on = re.search(r"^on:\s*\n((?:[ \t]+[^\n]*\n?)+)", src, re.M)
    triggers = on.group(1) if on else ""
    if re.search(r"^\s{2}release\s*:", triggers, re.M) or re.search(r"^on:\s*\[?[^\n]*\brelease\b", src, re.M):
        fail(rel(path), "a release trigger fires after the release is published; the publishing workflow calls this one and its publish job needs it")
    if re.search(r"^\s{2}pull_request(_target)?\s*:", triggers, re.M):
        warn(rel(path), "runs on pull requests: allowed only as the product's chosen extra cadence, never instead of the release run")
    if "workflow_call" not in triggers:
        fail(rel(path), "no workflow_call: the publishing workflow cannot run it as a job its publish job needs")
    crons = re.findall(r"cron:\s*['\"]([^'\"]+)['\"]", src)
    if not crons:
        fail(rel(path), "no schedule: a scheduled run between releases is the default cadence (monthly)")
    for c in crons:
        f = c.split()
        if len(f) != 5 or f[3] != "*":
            fail(rel(path), f"cron '{c}' runs less often than monthly; a product may run more often, never less")
    if re.search(r"continue-on-error:\s*true", src):
        fail(rel(path), "continue-on-error hides an INVALID run")
    if "actions/checkout" in src and not re.search(r"fetch-depth:\s*0", src):
        warn(rel(path), "checkout without fetch-depth: 0: the scheduled --diff run needs the last release tag")
if workflows and not mut_wf:
    fail(".github/workflows", "no workflow runs make mutation")
callers = []
for path in workflows:
    src = text(path) or ""
    for m in re.finditer(r"^  ([A-Za-z0-9_-]+):\s*\n((?:    [^\n]*\n?)+)", src, re.M):
        if re.search(r"uses:\s*\./\.github/workflows/[^\s]+", m.group(2)) and any(
                os.path.basename(w) in m.group(2) for w in mut_wf):
            job = m.group(1)
            ok =re.search(r"needs:\s*\[?[^\n\]]*\b" + re.escape(job) + r"\b", src)
            callers.append((rel(path), job, bool(ok)))
if mut_wf and not any(ok for _, _, ok in callers):
    fail(".github/workflows", "no publishing workflow runs the mutation workflow as a job its publish job needs; "
         "the release must wait for the full run to finish")

gi = text(os.path.join(root, ".gitignore")) or ""
if "mutation-out" not in gi:
    warn(".gitignore", "add mutation-out/ so run output is never committed")

for line in fails + warns:
    print(line)
print(f"{len(fails)} FAIL, {len(warns)} WARN")
sys.exit(1 if fails else 0)
PY
