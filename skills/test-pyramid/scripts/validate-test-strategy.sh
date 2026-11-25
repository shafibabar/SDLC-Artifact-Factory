#!/bin/bash
# validate-test-strategy.sh — skill-owned script for skills/test-pyramid.
# Purpose: mechanically check a Test Strategy
#          (artifacts/<product>/implement/test-strategy.md): frontmatter; no
#          unfilled placeholders; profile, languages and (with typescript) a
#          WCAG 2.2 accessibility line; rated and traced risks; all eight layers
#          planned with no layer skipped and no ratios; criteria mapped; targets
#          citing an NFR, SLO or open question; chaos hypotheses; the 100% line
#          and branch gate with per-language measurement; exclusions with
#          reasons; the mutation rule including timeouts and type-checker
#          rejections; retries only at end-to-end; quarantine, deletion and
#          regression rules; delegated checks; open questions. Judgement stays
#          with the agent.
# Usage:   validate-test-strategy.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-test-strategy.sh <file.md>" >&2
  exit 2
fi
if [ ! -f "$1" ]; then
  echo "error: file not found: $1" >&2
  exit 2
fi

python3 - "$1" <<'PYEOF'
import re, sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
fails = 0

def check(label, ok):
    global fails
    print(("PASS: " if ok else "FAIL: ") + label)
    if not ok:
        fails += 1

def warn(label):
    print("WARN: " + label)

def filled(c):
    c = (c or "").strip()
    return bool(c) and c not in ("—", "-", "?", "TBD", "tbd")

def table(raw):
    rows, header = [], None
    for line in raw.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        if header is None:
            header = [c.lower() for c in cells]
            continue
        rows.append(dict(zip(header, cells)))
    return rows

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
check("frontmatter block is present", bool(fm))
front = fm.group(1) if fm else ""
for key in ("name", "version", "phase", "owner", "created", "summary"):
    check("frontmatter has '%s'" % key, bool(re.search(r"^%s:\s*\S" % key, front, re.M)))
check("frontmatter name is test-strategy", bool(re.search(r"^name:\s*test-strategy\s*$", front, re.M)))
check("frontmatter phase is implement", bool(re.search(r"^phase:\s*implement\s*$", front, re.M)))
check("frontmatter has no unfilled value",
      not re.search(r"^(name|product|version|phase|owner|created|summary):\s*[\"']?\[", front, re.M)
      and not re.search(r"^traces-to:.*\[.*\[", front, re.M))

body = text[fm.end():] if fm else text
body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
left = re.findall(r"\[[^\]\n]+\](?!\()", body)
check("no unfilled [placeholder] remains%s" % ((": " + left[0][:40]) if left else ""), not left)

parts = re.split(r"^## (.+?)[ \t]*$", body, flags=re.M)
head = parts[0]
secs = {parts[i].strip().lower(): parts[i + 1] for i in range(1, len(parts), 2)}

def bold(label, where):
    m = re.search(r"\*\*%s:\*\*[ \t]*(.+)" % re.escape(label), where)
    return m.group(1).strip() if m else ""

profile = bold("Profile", head).lower()
check("profile is lean, standard or enterprise", profile in ("lean", "standard", "enterprise"))
langs = [l.strip() for l in bold("Languages", head).lower().split(",") if l.strip()]
check("languages are named from go, python, typescript",
      bool(langs) and all(l in ("go", "python", "typescript") for l in langs))
if "typescript" in langs:
    check("accessibility target is WCAG 2.2", "WCAG 2.2" in bold("Accessibility target", head))

risks = table(secs.get("risk", ""))
check("risk table has at least one row", bool(risks))
for r in risks:
    rid = r.get("id", "?")
    check("risk %s: traces to a source" % rid, filled(r.get("traces to", "")))
    check("risk %s: impact and likelihood are H, M or L" % rid,
          r.get("impact") in ("H", "M", "L") and r.get("likelihood") in ("H", "M", "L"))
    check("risk %s: states the depth" % rid, filled(r.get("extra depth", "")))

lsec = secs.get("layers", "")
layers = {r.get("layer", "").lower(): r for r in table(lsec)}
for name in ("unit", "integration", "contract", "end-to-end", "performance", "load", "chaos", "mutation"):
    r = layers.get(name)
    check("layer '%s' is planned" % name, r is not None)
    if r is None:
        continue
    cols = ("what it proves here", "skill", "author", "when it runs", "selected by")
    check("layer '%s': every column is filled" % name, all(filled(r.get(c, "")) for c in cols))
    skipped = r"^\s*(skip(ped)?|none|never|n/?a|not applicable|not required|deferred|later|out of scope)\b"
    check("layer '%s' is not skipped" % name,
          not any(re.search(skipped, r.get(c, ""), re.I) for c in ("what it proves here", "when it runs")))
check("no layer ratios", not re.search(r"\d+\s*%|\b\d{2}\s*/\s*\d{2}\s*/\s*\d{2}\b", lsec))

js = table(secs.get("acceptance and journeys", ""))
check("journeys table has at least one row", bool(js))
for r in js:
    n = r.get("journey or scenario group", "?")[:30]
    check("journey '%s': cites an AC-US-n.m id" % n, bool(re.search(r"AC-US-\d+\.\d+", r.get("criteria", ""))))
    s = r.get("smoke", "").lower()
    check("journey '%s': smoke is 'no' or read-only" % n, s == "no" or "read-only" in s)

targets = table(secs.get("targets", ""))
check("targets table has at least one row", bool(targets))
for r in targets:
    check("target '%s': cites an NFR, SLO or open question" % r.get("check", "?")[:30],
          bool(re.search(r"NFR-[A-Z]+-\d+|SLO-[A-Z0-9-]+|OQ-\d+", r.get("source", ""))))

ch = table(secs.get("chaos experiments", ""))
check("at least one chaos experiment with hypothesis and pattern",
      bool(ch) and all(filled(r.get("steady-state hypothesis", "")) and filled(r.get("resilience pattern proven", "")) for r in ch))

cov = secs.get("coverage gate", "")
check("coverage rule is 100% of lines and branches", "100% of lines and branches" in bold("Rule", cov))
low = [p for p in re.findall(r"(\d+(?:\.\d+)?)\s*%", cov) if float(p) != 100]
check("no coverage figure other than 100%", not low)
check("unmeasurable gate returns to the product owner",
      "product owner" in bold("If a gate cannot be measured", cov).lower())
crow = {r.get("language", "").lower(): r for r in table(cov)}
for l in langs:
    r = crow.get(l)
    check("coverage row for %s" % l, r is not None and all(
        filled(r.get(c, "")) for c in ("line gate", "branch gate", "not measured (stated in each report)")))
    if r is None:
        continue
    row = " ".join(r.values()).lower()
    if l == "go":
        check("go: statement blocks gate", "statement block" in r.get("line gate", "").lower())
        check("go: gobco branch gate after a trial",
              "gobco" in r.get("branch gate", "").lower() and "trial" in r.get("branch gate", "").lower())
        nm = r.get("not measured (stated in each report)", "").lower()
        check("go: states select, range and zero-iteration as unmeasured",
              all(w in nm for w in ("select", "range", "zero-iteration")))
    if l == "python":
        check("python: branch measurement is on", "branch" in r.get("branch gate", "").lower())
    if l == "typescript":
        check("typescript: coverage.include is set", "coverage.include" in row)

ex = table(secs.get("coverage exclusions", ""))
check("exclusions are listed (or a 'none' row)", bool(ex))
for r in ex:
    p = r.get("path or pattern", "?")
    if p.lower() == "none":
        continue
    kind = r.get("kind", "").lower()
    check("exclusion '%s': kind is generated or other" % p[:30], kind in ("generated", "other"))
    check("exclusion '%s': has a reason" % p[:30], filled(r.get("reason", "")))
    ap = r.get("approval", "").lower()
    if kind == "other":
        check("exclusion '%s': approval is pending or dated" % p[:30],
              ap == "pending" or bool(re.search(r"approved \d{4}-\d{2}-\d{2}", ap)))
        if ap == "pending":
            warn("exclusion '%s' awaits the product owner and is not yet excluded" % p[:30])

mut = secs.get("mutation rule", "")
rule = bold("Rule", mut).lower()
check("mutation rule: caught by a test or recorded with a reason",
      "caught by a test" in rule and "recorded" in rule and "behaviour" in rule)
to = bold("Timeouts and type-checker rejections", mut).lower()
check("timeouts and rejections: individually checked, one-line reason, never automatic",
      all(w in to for w in ("individually", "one-line reason", "never automatically")))
check("no percentage mutation target", not re.search(r"\d+\s*%", mut))
mrows = {r.get("language", "").lower(): r for r in table(mut)}
for l in langs:
    r = mrows.get(l)
    check("mutation row for %s" % l, r is not None and all(
        filled(r.get(c, "")) for c in ("tool", "gate reads", "never planted (stated limit)")))

fl = secs.get("flaky tests", "")
retries = {}
for r in table(fl):
    for n in r.get("layer", "").lower().split(","):
        retries[n.strip()] = r.get("automatic retries", "").strip()
for n in ("unit", "integration", "contract"):
    check("retries: %s is 0" % n, retries.get(n) == "0")
check("retries: end-to-end is 1", retries.get("end-to-end") == "1")
check("retries: no other layer retries", all(v == "0" for k, v in retries.items() if k != "end-to-end"))
q = bold("Quarantine", fl).lower()
check("quarantine is non-blocking with a deadline", "non-blocking" in q and "deadline" in q)
check("deletion needs a record", "record" in bold("Deletion", fl).lower())
check("regression test comes before the fix", "before the fix" in bold("Regression", fl).lower())

d = table(secs.get("delegated testing", ""))
dtext = " ".join(r.get("check", "") for r in d).lower()
check("delegated security and compliance checks are listed", "security" in dtext and "compliance" in dtext)
check("every delegated check has a gate", bool(d) and all(filled(r.get("gate", "")) for r in d))
check("open questions has at least one bullet",
      bool(re.search(r"^\s*[-*] \S", secs.get("open questions", ""), re.M)))
oq_ids = set(re.findall(r"OQ-\d+", " ".join(r.get("source", "") for r in targets)))
for o in sorted(oq_ids):
    check("%s is listed under open questions" % o,
          bool(re.search(r"\b%s\b" % o, secs.get("open questions", ""))))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
