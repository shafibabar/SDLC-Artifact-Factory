#!/bin/bash
# validate-bdd-feature-file.sh — skill-owned script for skills/bdd-feature-file.
# Purpose: mechanically check a story's feature file
#          (artifacts/<product>/implement/features/US-n.feature) against its
#          acceptance criteria (ideate/acceptance-criteria/US-n.md): comment
#          header and file name; no unfilled placeholder; honest run mode; one
#          Feature with the story framing; every scenario tagged with an
#          @AC-US-n.m ID that exists in the criteria and exactly one of @happy,
#          @negative, @edge; every criterion proven by a scenario that runs; all
#          three angles; a Given, one When and a Then; Background holding only
#          Givens; filled Examples with no repeated row; no technical wording or
#          speed target in steps. Whether a scenario says what the criterion
#          agreed, and whether steps are bound and pass, stays with the agent
#          and the test runner. English keywords only.
# Usage:   validate-bdd-feature-file.sh <US-n.feature> [<criteria US-n.md>]
#          validate-bdd-feature-file.sh --product <artifacts/product> [--must US-1,US-4]
#            --product  check every criteria file has a feature file that passes
#            --must     the Must Have story IDs; each needs criteria and a file
# Output:  one FAIL/WARN line per problem, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

exec python3 - "$@" <<'PYEOF'
import glob, os, re, sys

USAGE = ("Usage: validate-bdd-feature-file.sh <US-n.feature> [<criteria US-n.md>]\n"
         "       validate-bdd-feature-file.sh --product <artifacts/product> [--must US-1,US-4]")
fails = passes = 0
prefix = ""

def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

def check(label, ok):
    global fails, passes
    if ok:
        passes += 1
    else:
        fails += 1
        print("FAIL: " + prefix + label)
    return ok

def warn(label):
    print("WARN: " + prefix + label)

def read(p):
    return open(p, encoding="utf-8-sig", errors="replace").read().replace("\r\n", "\n")

AC_ID = r"AC-US-\d+[a-z]?\.\d+"
ANGLES = ("happy", "negative", "edge")
SECTIONS = {"happy path": "happy", "error / negative scenarios": "negative", "boundary / edge cases": "edge"}
NOT_RUN = {"@skip", "@wip", "@ignore", "@quarantine", "@manual", "@pending"}
KEYWORD = re.compile(r"^(Feature|Rule|Background|Scenario Outline|Scenario Template|Scenario|Example|Examples|Scenarios):[ \t]*(.*)$")
STEP = re.compile(r"^(Given|When|Then|And|But|\*)(?:[ \t]+(.*))?$")
# Technical wording. Plain English "get", "delete", "post", "put" must pass, so
# HTTP verbs and SQL are matched in capitals and only in a technical shape.
TECH = [re.compile(r"\b(GET|POST|PUT|PATCH|DELETE)\s+(/|https?:)"),
        re.compile(r"\b(GET|POST|PUT|PATCH|DELETE)\s+request\b"),
        re.compile(r"\bhttps?://"),
        re.compile(r"(?<![\w.])/(api|v\d+)(/|\b)"),
        re.compile(r"\bSELECT\b.+\bFROM\b|\bINSERT\s+INTO\b|\bDELETE\s+FROM\b|\bUPDATE\s+\w+\s+SET\b"),
        re.compile(r"\bHTTP\s*[1-5]\d\d\b|\bstatus code\b|\bresponds? with (a )?[1-5]\d\d\b"
                   r"|\b[1-5]\d\d (OK|Created|Accepted|No Content|Bad Request|Unauthorized|Forbidden|Not Found|Conflict|Internal Server Error)\b"),
        re.compile(r"\b[a-z]+(_[a-z]+)+\s*(=|==)\s*\S|\b[a-z_]+\.[a-z_]+\s*(=|==)\s*\S"),
        re.compile(r"`[^`\n]*[_./=(][^`\n]*`"),
        re.compile(r"\b(clicks?|double-clicks?|clicked|clicking)\b(?![- ]and[- ]collect)", re.I),
        re.compile(r"\btypes?\b.{0,60}\b(in|into) the .{0,30}\b(field|box|input)\b|\bdata-testid\b|\bCSS selector\b", re.I)]
TECH_WORD = re.compile(r"\bHTTP\b|\bJSON\b|\bAPI\b|\bSQL\b|\bendpoint\b|\bdatabase\b|\bbutton\b|\bURL\b", re.I)
TARGET = re.compile(r"\b(milliseconds?|p9\d|latency|uptime|response time)\b|\b\d+ ?ms\b", re.I)
VACUOUS = re.compile(r"\b(works?( correctly| as expected)?|succeeds|is successful|is processed|"
                     r"processes the request|is handled)\W*$", re.I)

def numbers(text):
    return {n.replace(",", "") for n in re.findall(r"\d+(?:[.,:]\d+)*", text)}

def load_criteria(path):
    text = re.sub(r"<!--.*?-->", "", read(path), flags=re.S)
    parts = re.split(r"^## (.+?)[ \t]*$", text, flags=re.M)
    out = {}
    for i in range(1, len(parts), 2):
        angle = SECTIONS.get(parts[i].strip().lower())
        if not angle:
            continue
        crits = re.split(r"^### (.+?)[ \t]*$", parts[i + 1], flags=re.M)
        for j in range(1, len(crits), 2):
            m = re.match(r"(%s):" % AC_ID, crits[j])
            if m:
                body = re.sub(r"^[-*] From:.*$", "", crits[j + 1], flags=re.M)
                body = re.sub(r"\b(%s|US-\d+[a-z]?|[A-Z]+-\d+(\.\d+)?|R\d+(\.E\d+)?)\b" % AC_ID, "", body)
                out[m.group(1)] = (angle, numbers(body))
    return out

def parse(lines):
    """A light Gherkin reader: blocks (feature/rule/background/scenario) with
    their tags, description, steps, tables and examples."""
    blocks, tags, comments, problems = [], [], [], []
    cur = ex = doc = rule_tags = None
    rule_tags = set()
    for n, raw in enumerate(lines, 1):
        s = raw.strip()
        if doc:
            if s.startswith(doc):
                doc = None
            continue
        if s.startswith('"""') or s.startswith("```"):
            doc = s[:3]
            continue
        if not s:
            continue
        if s.startswith("#"):
            comments.append((n, s))
            continue
        if s.startswith("@"):
            tags += re.split(r"\s+", re.sub(r"\s#.*$", "", s))
            continue
        m = KEYWORD.match(s)
        if m:
            kind, name = m.group(1), m.group(2).strip()
            if kind in ("Examples", "Scenarios"):
                if not cur or cur["kind"] != "outline":
                    problems.append("line %d: Examples outside a Scenario Outline" % n)
                    ex = None
                else:
                    ex = {"tags": set(tags), "rows": []}
                    cur["examples"].append(ex)
            else:
                k = {"Scenario": "scenario", "Example": "scenario", "Scenario Outline": "outline",
                     "Scenario Template": "outline"}.get(kind, kind.lower())
                if k == "rule":
                    rule_tags = set(tags)
                cur = {"kind": k, "name": name, "line": n, "own": set(tags), "rule": set(rule_tags),
                       "desc": [], "steps": [], "examples": []}
                ex = None
                blocks.append(cur)
            tags = []
            continue
        m = STEP.match(s)
        if m and cur and cur["kind"] in ("background", "scenario", "outline"):
            if ex is not None:
                problems.append("line %d: step after an Examples table" % n)
            cur["steps"].append([m.group(1), (m.group(2) or "").strip(), n])
            continue
        if s.startswith("|"):
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", s)[1:-1]]
            if ex is not None:
                ex["rows"].append(cells)
            elif cur and cur["steps"]:
                cur["steps"][-1].append(" ".join(cells))
            else:
                problems.append("line %d: table row with no step or Examples" % n)
            continue
        if cur and ((ex is None and not cur["steps"]) or (ex is not None and not ex["rows"])):
            cur["desc"].append(s)
            continue
        problems.append("line %d: not a Gherkin line: '%s'" % (n, s[:40]))
    return blocks, comments, problems

def validate(path, criteria_path):
    lines = read(path).split("\n")
    first = next((l.strip() for l in lines if l.strip()), "")
    lang = re.search(r"^[ \t]*#[ \t]*language:[ \t]*(\S+)", "\n".join(lines), re.M)
    if lang and not lang.group(1).lower().startswith("en"):
        die("error: %s uses '# language: %s'; this script reads English keywords only" % (path, lang.group(1)))
    check("no YAML frontmatter (Gherkin cannot read it; use the '# key: value' header)", first != "---")

    head = {}
    for l in lines:
        s = l.strip()
        if s and not s.startswith("#"):
            break
        m = re.match(r"#[ \t]*([a-z_-]+):[ \t]*(.*)$", s)
        if m:
            head[m.group(1)] = m.group(2).strip()
    for key in ("name", "product", "story-id", "version", "phase", "owner", "created", "summary", "run", "traces_to"):
        check("header has '# %s:'" % key, bool(head.get(key)))
    check("header name is feature-file", head.get("name") == "feature-file")
    check("header phase is implement", head.get("phase") == "implement")
    story = head.get("story-id", "")
    check("header story-id is US-n", bool(re.fullmatch(r"US-\d+[a-z]?", story)))
    check("file name is <story-id>.feature", os.path.basename(path) == story + ".feature")

    blocks, comments, problems = parse(lines)
    all_comments = "\n".join(c for _, c in comments)
    run = head.get("run", "")
    check("run is agent-run or workshop", run in ("agent-run", "workshop"))
    if run == "agent-run":
        check("agent-run file says one agent wrote it and no workshop was held",
              bool(re.search(r"\bone agent\b", all_comments, re.I))
              and bool(re.search(r"\bno (workshop|session|meeting)\b", all_comments, re.I)))
    if run == "workshop":
        check("workshop file names its participants", bool(re.search(r"Participants:[ \t]*\S", all_comments)))
    for p in problems:
        check(p, False)

    # ---- placeholders ----
    columns = set()
    for b in blocks:
        for e in b["examples"]:
            if e["rows"]:
                columns |= {c for c in e["rows"][0] if "<" not in c}
    left, in_doc = [], None
    for n, raw in enumerate(lines, 1):
        s = raw.strip()
        if in_doc:
            if s.startswith(in_doc):
                in_doc = None
            continue
        if s.startswith('"""') or s.startswith("```"):
            in_doc = s[:3]
            continue
        owner = next((b for b in reversed(blocks) if b["line"] <= n), None)
        allowed = columns if owner and owner["kind"] == "outline" and not s.startswith("#") else set()
        rest = re.sub(r"<([^<>]+)>", lambda m: "" if m.group(1) in allowed else m.group(0), s)
        hit = re.search(r"<[^<>]+>|\bTBD\b|\?\?\?", rest)
        if not hit and not s.startswith("|"):
            hit = re.search(r"\[[^\]]*[A-Za-z]{2}[^\]]* [^\]]*\]", rest)
        if hit:
            left.append("line %d '%s'" % (n, hit.group(0)[:40]))
    check("no unfilled placeholder remains%s" % ((": " + ", ".join(left[:3])) if left else ""), not left)

    features = [b for b in blocks if b["kind"] == "feature"]
    if check("exactly one Feature, before everything else",
             len(features) == 1 and blocks[0]["kind"] == "feature"):
        desc = " ".join(features[0]["desc"])
        check("Feature has As a / I want / So that",
              bool(re.search(r"\bAs an? .+\bI want\b.+\bso that\b", desc, re.I | re.S)))
    feature_tags = features[0]["own"] if features else set()
    for b in blocks:
        if re.search(r"\s#\s*(@?(happy|negative|edge)\b|@?AC-)", b["name"], re.I):
            check("line %d: no trailing comment (it becomes part of the name; use tags)" % b["line"], False)
        if b["kind"] in ("feature", "rule"):
            check("line %d: no criterion tag on Feature or Rule (tag each scenario)" % b["line"],
                  not any(t.startswith("@AC-") for t in b["own"]))
        for step in b["steps"]:
            if re.search(r"\s#\s*@?(happy|negative|edge)\s*$", step[1], re.I):
                check("line %d: no trailing comment (use tags)" % step[2], False)

    every = set(feature_tags)
    for b in blocks:
        every |= b["own"] | b["rule"]
        for e in b["examples"]:
            every |= e["tags"]
    bad = sorted(t for t in every if re.match(r"@AC\b|@AC[-_]", t, re.I) and not re.fullmatch("@" + AC_ID, t))
    check("criterion tags use only the form @AC-US-n.m%s" % ((" (%s)" % ", ".join(bad)) if bad else ""), not bad)

    background = {"": []}
    rule_name = ""
    scenarios, names = [], set()
    for b in blocks:
        if b["kind"] == "rule":
            rule_name = b["name"] or str(b["line"])
        elif b["kind"] == "background":
            background[rule_name] = b["steps"]
            check("line %d: Background holds only Given steps" % b["line"],
                  bool(b["steps"]) and all(s[0] in ("Given", "And", "But", "*") for s in b["steps"])
                  and b["steps"][0][0] in ("Given", "*"))
        elif b["kind"] in ("scenario", "outline"):
            b["bg"] = background[""] + (background.get(rule_name, []) if rule_name else [])
            scenarios.append(b)
    check("the file has at least one scenario", bool(scenarios))

    covered, angles_run = {}, set()
    for b in scenarios:
        label = "line %d '%s'" % (b["line"], b["name"][:40])
        check("%s: has a name" % label, bool(b["name"]))
        check("%s: name is unique" % label, b["name"] not in names)
        names.add(b["name"])
        keys, last, ordered = [], "", True
        for kw, text, n in (s[:3] for s in b["steps"]):
            check("line %d: step has text" % n, bool(text))
            if kw in ("Given", "When", "Then"):
                last = kw
            elif not last:
                if b["bg"]:
                    last = "Given"
                else:
                    ordered = False
            keys.append(last)
        rank = {"Given": 0, "When": 1, "Then": 2, "": 0}
        ordered = ordered and [rank[k] for k in keys] == sorted(rank[k] for k in keys)
        check("%s: steps run Given, When, Then in that order" % label, ordered)
        check("%s: has a Given (own or Background)" % label, "Given" in keys or bool(b["bg"]))
        check("%s: exactly one When (found %d; And/But after When counts)" % (label, keys.count("When")),
              keys.count("When") == 1)
        check("%s: has a Then" % label, "Then" in keys)
        for (kw, text, n, *table), key in zip(b["steps"], keys):
            if key == "Then" and VACUOUS.search(text):
                warn("line %d: '%s' may not be observable; say what the persona sees or receives" % (n, text[:50]))
        for step in b["steps"] + b["bg"]:
            text, n = " ".join([step[1]] + step[3:]), step[2]
            unquoted = re.sub(r"\"[^\"\n]*\"|\u201c[^\u201d\n]*\u201d", '""', text)
            t = next((x for x in (p.search(unquoted) for p in TECH) if x), None)
            if t:
                check("line %d: no technical wording in a step ('%s'); put it in the step definition" % (n, t.group(0)[:30]), False)
            elif TECH_WORD.search(unquoted):
                warn("line %d says '%s'; keep it only if that is the user's own language" % (n, TECH_WORD.search(unquoted).group(0)))
            if TARGET.search(unquoted):
                check("line %d: no speed or availability target in a step (cite the NFR; load tests own it)" % n, False)

        if b["kind"] == "outline":
            used = {p for s in b["steps"] for p in re.findall(r"<([^<>]+)>", " ".join([s[1]] + s[3:]))}
            check("%s: outline has an Examples table with a header and a row" % label,
                  bool(b["examples"]) and all(len(e["rows"]) > 1 for e in b["examples"]))
            seen = set()
            for e in b["examples"]:
                if not e["rows"]:
                    continue
                hdr = e["rows"][0]
                check("%s: every <placeholder> has an Examples column (missing: %s)" % (label, ", ".join(sorted(used - set(hdr)))),
                      used <= set(hdr))
                if set(hdr) - used:
                    warn("%s: Examples column(s) no step uses: %s" % (label, ", ".join(sorted(set(hdr) - used))))
                check("%s: every Examples row has a cell per column" % label, all(len(r) == len(hdr) for r in e["rows"]))
                for r in e["rows"][1:]:
                    check("%s: no repeated Examples row (%s)" % (label, " | ".join(r)), tuple(r) not in seen)
                    seen.add(tuple(r))

        cases = [e["tags"] for e in b["examples"]] if b["kind"] == "outline" and b["examples"] else [set()]
        for extra in cases:
            tags = feature_tags | b["rule"] | b["own"] | extra
            ids = sorted(t[1:] for t in b["own"] | extra if re.fullmatch("@" + AC_ID, t))
            angle = [a for a in ANGLES if "@" + a in tags]
            check("%s: tagged with the criterion it proves (@AC-US-n.m)" % label, bool(ids))
            check("%s: exactly one of @happy, @negative, @edge" % label, len(angle) == 1)
            if len(ids) > 1:
                warn("%s proves %s; one rule per scenario, so split unless one behaviour proves them all" % (label, ", ".join(ids)))
            off = sorted(tags & NOT_RUN)
            if off:
                warn("%s is tagged %s: it proves nothing and counts for no criterion" % (label, " ".join(off)))
                continue
            angles_run.update(angle)
            rows = [r for e in b["examples"] for r in e["rows"][1:]]
            text = " ".join([b["name"]] + [" ".join([s[1]] + s[3:]) for s in b["steps"] + b["bg"]]
                            + [" ".join(r) for r in rows])
            for i in ids:
                c = covered.setdefault(i, {"angles": set(), "text": ""})
                c["angles"].update(angle)
                c["text"] += " " + text
    for a in ANGLES:
        check("at least one @%s scenario that runs" % a, a in angles_run)

    if not check("the criteria file exists, so every scenario can be traced (%s)" % criteria_path,
                 os.path.isfile(criteria_path)):
        return
    check("the criteria file is this story's (%s.md)" % story, os.path.basename(criteria_path) == story + ".md")
    crit = load_criteria(criteria_path)
    check("the criteria file holds AC-US-n.m criteria", bool(crit))
    used = {t[1:] for t in every if re.fullmatch("@" + AC_ID, t)}
    unknown = sorted(used - set(crit))
    check("every tag names a criterion in the file (unknown: %s); a new case goes back to the criteria" % ", ".join(unknown),
          not unknown)
    missing = sorted(set(crit) - set(covered), key=lambda i: [int(x) for x in re.findall(r"\d+", i)])
    check("every criterion has a scenario that runs (missing: %s)" % ", ".join(missing), not missing)
    for i, (angle, nums) in crit.items():
        if i not in covered:
            continue
        if angle not in covered[i]["angles"]:
            warn("%s sits under %s in the criteria but no scenario for it is tagged @%s" % (i, angle, angle))
        lost = sorted(nums - numbers(covered[i]["text"]))
        if lost:
            warn("%s states %s, not found in its scenarios; confirm no agreed value was changed or dropped" % (i, ", ".join(lost)))

args = sys.argv[1:]
if not args:
    die(USAGE)
if args[0] == "--product":
    if len(args) not in (2, 4) or (len(args) == 4 and args[2] != "--must"):
        die(USAGE)
    root = args[1].rstrip("/")
    if not os.path.isdir(root):
        die("error: directory not found: %s" % root)
    cdir, fdir = os.path.join(root, "ideate", "acceptance-criteria"), os.path.join(root, "implement", "features")
    crits = {os.path.basename(p)[:-3] for p in glob.glob(os.path.join(cdir, "*.md"))}
    feats = {os.path.basename(p)[:-8] for p in glob.glob(os.path.join(fdir, "*.feature"))}
    check("there are acceptance criteria to prove (%s)" % cdir, bool(crits))
    if len(args) == 4:
        for s in [x.strip() for x in args[3].split(",") if x.strip()]:
            check("Must Have %s has a criteria file" % s, s in crits)
            check("Must Have %s has a feature file" % s, s in feats)
    else:
        warn("no --must list given: Must Have stories with no criteria file are not detected")
    for s in sorted(crits - feats):
        check("%s has criteria, so it needs %s/%s.feature" % (s, fdir, s), False)
    for s in sorted(feats):
        prefix = s + ".feature: "
        validate(os.path.join(fdir, s + ".feature"), os.path.join(cdir, s + ".md"))
    prefix = ""
else:
    if len(args) > 2:
        die(USAGE)
    path = args[0]
    if not os.path.isfile(path):
        die("error: file not found: %s" % path)
    if len(args) == 2 and not os.path.isfile(args[1]):
        die("error: file not found: %s" % args[1])
    here = os.path.dirname(os.path.abspath(path))
    default = os.path.normpath(os.path.join(here, "..", "..", "ideate", "acceptance-criteria",
                                            os.path.basename(path).replace(".feature", ".md")))
    validate(path, args[1] if len(args) == 2 else default)

print("%d check(s) passed, %d check(s) failed" % (passes, fails))
sys.exit(1 if fails else 0)
PYEOF
