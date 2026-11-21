#!/bin/bash
# scripts/validate-event-schemas.sh — skill-owned script for skills/event-schema-design.
# Purpose: mechanically check design/data/event-schemas.md against the
#          structural items of resources/schema-checklist.md: frontmatter; the
#          conventions name CloudEvents 1.0, the house extensions (D047-1) with
#          valid extension names, a format, content mode, registry, compatibility
#          and CI gate; each event's type is lower-case reverse-DNS with no
#          version suffix and a stable source; payloads hold no envelope fields;
#          optional fields carry a default; breaking changes take a new type and
#          upcasting is for stored events only; no NONE mode; no code (D047-10).
#          Whether a change really is additive stays with the agent.
# Usage:   validate-event-schemas.sh <path-to-event-schemas.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-event-schemas.sh <path-to-event-schemas.md>" >&2
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
    if not c or c in ("—", "-", "?"):
        return False
    # "[product slug]" is an unfilled placeholder; "[a.md, b.md]" is a filled YAML list.
    return not (c.startswith("[") and not re.search(r"\.md|/", c.split("]")[0]))

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is event-schema", meta.get("name") == "event-schema")

blocks, cur = [], None
for line in text.splitlines():
    h = re.match(r"^## (.+)$", line)
    if h:
        cur = {"title": h.group(1).strip(), "lines": []}
        blocks.append(cur)
    elif cur is not None:
        cur["lines"].append(line)

def subsections(lines):
    out, name = {"": []}, ""
    for l in lines:
        h = re.match(r"^### (.+)$", l)
        if h:
            name = h.group(1).strip().lower(); out[name] = []
        else:
            out[name].append(l)
    return out

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], rows[1:]) if rows else ([], [])

def fields(lines):
    return {r[0].strip("* ").lower(): r[1] for r in table(lines)[1] if len(r) >= 2}

conv_b = next((b for b in blocks if b["title"].lower() == "conventions"), None)
check("has a '## Conventions' section", conv_b is not None)
conv = fields(conv_b["lines"]) if conv_b else {}
for key in ("envelope", "extensions", "type naming", "source", "format", "content mode", "registry", "default compatibility", "ci gate"):
    check(f"conventions: '{key}' is filled in", filled(conv.get(key, "")))
env = conv.get("envelope", "").lower()
check("conventions: the envelope is CloudEvents 1.0", "cloudevents" in env and "1.0" in env)
m = re.search(r"spec-required:\s*([^;|]*)", env)
if m:
    req = {a.strip() for a in m.group(1).split(",") if a.strip()}
    check("conventions: the spec-required attributes are exactly specversion, id, source, type", req == {"specversion", "id", "source", "type"})
ext_cell = conv.get("extensions", "")
ext_names = re.findall(r"[A-Za-z][\w-]*", ext_cell.split("—")[0])
for x in ("correlationid", "causationid"):
    check(f"conventions: the '{x}' extension is declared (D047-1)", x in ext_names)
KNOWN_EXT = {"correlationid", "causationid", "tenantid", "partitionkey", "traceparent", "tracestate", "dataref"}
bad = [n for n in ext_names if re.sub(r"[-_]", "", n).lower() in KNOWN_EXT and not re.fullmatch(r"[a-z0-9]{1,20}", n)]
check("conventions: extension names use lower-case letters and digits only" + (f" ({', '.join(sorted(set(bad)))})" if bad else ""), not bad)
check("conventions: default compatibility is not NONE", not re.match(r"\s*none\b", conv.get("default compatibility", ""), re.I))

ENVELOPE_FIELDS = {"eventid", "eventtype", "occurredat", "schemaversion", "version", "specversion", "eventversion"}
IRREGULAR = {"sent", "paid", "made", "held", "won", "lost", "built", "taken", "given", "written", "run", "begun", "sold", "bought", "left", "met", "set", "put", "cut", "shut", "split", "read", "kept", "done", "drawn", "withdrawn", "chosen", "frozen", "spent", "lent", "sought", "brought"}
events = [b for b in blocks if b["title"].lower().startswith("event:")]
check("has at least one '## Event:' block", bool(events))
types = []
for b in events:
    t = b["title"].split(":", 1)[1].strip().strip("`")
    types.append(t)
    subs = subsections(b["lines"])
    f = fields(subs[""])
    check(f"{t}: type is filled in (not a placeholder)", filled(t))
    check(f"{t}: type is lower-case reverse-DNS with dot-separated, hyphenated segments", bool(re.fullmatch(r"[a-z0-9]+(\.[a-z0-9]+(-[a-z0-9]+)*){3,}", t)))
    check(f"{t}: no version suffix in the type (D047-1)", not re.search(r"([._-]v\d+$)|([._-]v\d+[._-])|v\d+$", t))
    verb = t.split(".")[-1].split("-")
    if not any(w.endswith("ed") or w in IRREGULAR for w in verb):
        warn(f"{t}: the last segment may not be a past-tense verb")
    kind = f.get("kind", "").lower()
    for key in ("domain event", "kind", "source", "subject", "dataschema", "compatibility"):
        check(f"{t}: '{key}' is filled in", filled(f.get(key, "")))
    src = f.get("source", "")
    check(f"{t}: source is stable (no deploy version)", not re.search(r"/v?\d+\.\d+|/v\d+\b", src))
    check(f"{t}: compatibility is not NONE", not re.match(r"\s*none\b", f.get("compatibility", ""), re.I))
    ds = f.get("dataschema", "")
    if filled(ds) and not re.search(r"\d", ds):
        warn(f"{t}: dataschema has no version in it (a schema change should give a different URI)")

    ph, prows = table(subs.get("payload (data)", []))
    prows = [r for r in prows if r and filled(r[0])]
    check(f"{t}: the payload table has fields", bool(prows))
    for r in prows:
        name = r[0].strip("` ")
        check(f"{t}: payload field '{name}' is not an envelope attribute", re.sub(r"[_-]", "", name).lower() not in ENVELOPE_FIELDS)
        if len(r) >= 4 and r[2].lower().startswith("no"):
            check(f"{t}: optional field '{name}' states its default for old events", filled(r[3]))
        if re.sub(r"[_-]", "", name).lower() == "tenantid":
            warn(f"{t}: tenant in the payload; the house carries it as the 'tenantid' extension")

    ch, crows = table(subs.get("change log", []))
    for r in [r for r in crows if len(r) >= 4 and filled(r[1])]:
        change, cls, action = r[1].lower(), r[2].lower(), r[3].lower()
        if re.search(r"\brenam|\bremov|\bdrop|type change|retyp|change(d|s)? (the )?unit|from .* to .*(integer|int|string)|make .* required|now required", change) and cls.startswith("additive"):
            check(f"{t}: change '{r[1][:50]}' is classed breaking, not additive", False)
        if cls.startswith("breaking"):
            if kind.startswith("stored"):
                check(f"{t}: breaking change to a stored event uses an upcaster or copy-and-replace", bool(re.search(r"upcast|copy-and-replace|copy and replace", action)))
            else:
                check(f"{t}: breaking change '{r[1][:50]}' takes a new type with dual publishing, not an in-place edit", "new type" in action and not re.search(r"\bin place\b", action))
                if "new type" in action and not re.search(r"telemetry|until|deprecat|retire", action):
                    warn(f"{t}: breaking change has no deprecation or retirement condition")
        if "upcast" in action and not kind.startswith("stored"):
            check(f"{t}: upcasting is used only for stored events, not published ones", False)

dupes = sorted({x for x in types if types.count(x) > 1})
check("no event type appears twice" + (f" ({', '.join(dupes)})" if dupes else ""), not dupes)
body = text[fm.end():] if fm else text
check("no code in the design (D047-10: code is go-event-publisher's)", not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin)\b|^\s*func \(|^\s*type \w+ struct|^\s*(public|private) class ", body, re.M))

print(f"INFO: {len(events)} event type(s)")
sys.exit(1 if fails else 0)
PYEOF
