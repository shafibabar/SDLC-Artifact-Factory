#!/bin/bash
# scripts/validate-proto.sh — skill-owned script for skills/grpc-contract-design.
# Purpose: mechanically check a protobuf3 contract
#          (artifacts/<product>/design/<service>/<name>.proto) against the
#          structural items of resources/checklist.md: proto3 syntax; a package
#          ending .vN; services named *Service; a distinct request and response
#          message for each method; field numbers that are positive, unique per
#          message, outside 19000-19999 and not reserved; reserved names not
#          reused; lower_snake_case field names; enums whose first value is
#          zero and named *_UNSPECIFIED. With a second argument (the baseline,
#          the same proto at the main branch) it also flags breaking changes:
#          a reused or renumbered field, a removal without reserved, a type
#          change, a removed or changed method, a changed package. A small
#          regex-based reader, not a full parser: advisory, and a real
#          breaking-change linter (Buf) still belongs in CI.
# Usage:   validate-proto.sh <file.proto> [baseline.proto]
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: validate-proto.sh <file.proto> [baseline.proto]" >&2
  exit 2
fi
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "error: file not found: $f" >&2
    exit 2
  fi
done

python3 - "$@" <<'PYEOF'
import re, sys

fails = 0

def check(label, ok):
    global fails
    print(("PASS: " if ok else "FAIL: ") + label)
    if not ok:
        fails += 1

def warn(label):
    print("WARN: " + label)

def strip_comments(t):
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    return re.sub(r"//[^\n]*", "", t)

def blocks(text, kinds):
    """Top-level 'kind Name { body }' blocks, by brace matching."""
    out, i, n = [], 0, len(text)
    pat = re.compile(r"\b(%s)\s+(\w+)\s*\{" % "|".join(kinds))
    while True:
        m = pat.search(text, i)
        if not m:
            break
        depth, j = 1, m.end()
        while j < n and depth:
            if text[j] == "{":
                depth += 1
            elif text[j] == "}":
                depth -= 1
            j += 1
        out.append((m.group(1), m.group(2), text[m.end():j - 1], m.start(), j))
        i = j
    return out

def parse_reserved(body):
    nums, names = set(), set()
    for m in re.finditer(r"\breserved\s+([^;]+);", body):
        spec = m.group(1)
        if '"' in spec:
            names |= set(re.findall(r'"([^"]+)"', spec))
        else:
            for part in spec.split(","):
                part = part.strip()
                r = re.fullmatch(r"(\d+)\s+to\s+(\d+|max)", part)
                if r:
                    hi = 536870911 if r.group(2) == "max" else int(r.group(2))
                    lo = int(r.group(1))
                    nums |= set(range(lo, min(hi, lo + 5000) + 1))
                elif part.isdigit():
                    nums.add(int(part))
    return nums, names

def parse_messages(text, prefix=""):
    """-> {qualified name: {fields: {num: (name, type)}, reserved: (nums, names), dup: [nums]}}, enums"""
    msgs, enums = {}, {}
    for kind, name, body, s, e in blocks(text, ("message", "enum")):
        q = prefix + name
        if kind == "enum":
            vals = []
            for m in re.finditer(r"^\s*(\w+)\s*=\s*(-?\d+)", body, re.M):
                vals.append((m.group(1), int(m.group(2))))
            enums[q] = vals
            continue
        inner = body
        sub_m, sub_e = parse_messages(body, q + ".")
        msgs.update(sub_m)
        enums.update(sub_e)
        # remove nested message and enum blocks before reading this message's fields
        for k2, n2, b2, s2, e2 in reversed(blocks(inner, ("message", "enum"))):
            inner = inner[:s2] + inner[e2:]
        # flatten oneofs (their members share the message's number space)
        inner = re.sub(r"\boneof\s+\w+\s*\{", "", inner)
        inner = inner.replace("}", "")
        fields, dups, seen = {}, [], set()
        fre = re.compile(r"^\s*(?:(optional|repeated)\s+)?([\w.]+(?:\s*<[^>]*>)?)\s+(\w+)\s*=\s*(\d+)\s*(?:\[[^\]]*\])?\s*;", re.M)
        for m in fre.finditer(inner):
            label, typ, fname, num = m.group(1), re.sub(r"\s+", "", m.group(2)), m.group(3), int(m.group(4))
            if typ in ("reserved", "option", "extensions", "syntax", "package", "import"):
                continue
            if num in seen:
                dups.append(num)
            seen.add(num)
            fields[num] = (fname, (label + " " if label == "repeated" else "") + typ)
        msgs[q] = {"fields": fields, "reserved": parse_reserved(inner), "dup": dups}
    return msgs, enums

def parse_services(text):
    out = {}
    for kind, name, body, s, e in blocks(text, ("service",)):
        rpcs = {}
        for m in re.finditer(r"\brpc\s+(\w+)\s*\(\s*(stream\s+)?([\w.]+)\s*\)\s*returns\s*\(\s*(stream\s+)?([\w.]+)\s*\)", body):
            rpcs[m.group(1)] = (bool(m.group(2)), m.group(3), bool(m.group(4)), m.group(5))
        out[name] = rpcs
    return out

def load(path):
    text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    msgs, enums = parse_messages(text)
    pk = re.search(r"^\s*package\s+([\w.]+)\s*;", text, re.M)
    return {"text": text, "msgs": msgs, "enums": enums, "services": parse_services(text),
            "package": pk.group(1) if pk else ""}

cur = load(sys.argv[1])
text = cur["text"]

# --- header --------------------------------------------------------------------
check("syntax is proto3", bool(re.search(r'^\s*syntax\s*=\s*"proto3"\s*;', text, re.M)))
check("a package is declared", bool(cur["package"]))
check("the package ends in a major version (.vN)", re.search(r"\.v\d+$", cur["package"]) is not None)

# --- services --------------------------------------------------------------------
check("at least one service is defined", len(cur["services"]) > 0)
req_use = {}
for sname, rpcs in cur["services"].items():
    check("service '%s' is named with the suffix Service" % sname, sname.endswith("Service"))
    check("service '%s' has at least one method" % sname, len(rpcs) > 0)
    for rname, (cs, req, ss, resp) in rpcs.items():
        if not req.startswith("google.protobuf."):
            req_use.setdefault(("req", req), []).append("%s.%s" % (sname, rname))
        if not resp.startswith("google.protobuf."):
            req_use.setdefault(("resp", resp), []).append("%s.%s" % (sname, rname))
        if req.startswith("google.protobuf.") or resp.startswith("google.protobuf."):
            warn("%s.%s uses a shared well-known message as request or response; give each method its own" % (sname, rname))
        if cs or ss:
            warn("%s.%s is a streaming method: confirm the data flow is a stream (unary is the default)" % (sname, rname))
for (kind, t), users in req_use.items():
    check("%s message '%s' belongs to one method (%s)" % ("request" if kind == "req" else "response", t, ", ".join(users)),
          len(users) == 1)

# --- messages ----------------------------------------------------------------------
snake = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
for q, m in cur["msgs"].items():
    rn, rnames = m["reserved"]
    for num, (fname, typ) in m["fields"].items():
        tag = "%s.%s" % (q, fname)
        check("%s: field number %d is positive and in range" % (tag, num), 1 <= num <= 536870911)
        check("%s: field number %d is outside 19000-19999" % (tag, num), not (19000 <= num <= 19999))
        check("%s: field number %d is not reserved" % (tag, num), num not in rn)
        check("%s: name is not reserved" % tag, fname not in rnames)
        check("%s: name is lower_snake_case" % tag, snake.match(fname) is not None)
        if typ.endswith("google.protobuf.Any") or typ.endswith("google.protobuf.Struct"):
            warn("%s uses a dynamic type (Any or Struct): justify it, it defeats static typing" % tag)
    check("%s: no duplicate field numbers" % q, not m["dup"])

# --- enums ---------------------------------------------------------------------------
for q, vals in cur["enums"].items():
    if not vals:
        continue
    first_name, first_num = vals[0]
    check("enum %s: the first value is zero" % q, first_num == 0)
    check("enum %s: the zero value is named *_UNSPECIFIED" % q, first_num == 0 and first_name.endswith("_UNSPECIFIED"))

# --- baseline (breaking changes) ------------------------------------------------------
if len(sys.argv) == 3:
    old = load(sys.argv[2])
    print("-- baseline: %s --" % sys.argv[2])
    check("the package is unchanged (a breaking redesign is a new .vN package)", old["package"] == cur["package"])
    for q, om in old["msgs"].items():
        if q not in cur["msgs"]:
            warn("message %s was removed: breaking if any method or field still refers to it" % q)
            continue
        nm = cur["msgs"][q]
        new_by_name = {f[0]: (n, f[1]) for n, f in nm["fields"].items()}
        nrn, nrnames = nm["reserved"]
        for num, (fname, typ) in om["fields"].items():
            tag = "%s.%s (%d)" % (q, fname, num)
            if num in nm["fields"]:
                nname, ntyp = nm["fields"][num]
                check("%s: the type is unchanged" % tag, ntyp == typ)
                if nname != fname:
                    warn("%s was renamed to %s: wire-safe, but a source and JSON break" % (tag, nname))
            else:
                if fname in new_by_name:
                    check("%s: the field keeps its number (renumbered to %d)" % (tag, new_by_name[fname][0]), False)
                else:
                    check("%s: removed, so its number is reserved" % tag, num in nrn)
                    check("%s: removed, so its name is reserved" % tag, fname in nrnames)
    for q, ov in old["enums"].items():
        if q not in cur["enums"]:
            continue
        nv = dict(cur["enums"][q])
        for vname, vnum in ov:
            if vname in nv:
                check("enum %s.%s keeps its number" % (q, vname), nv[vname] == vnum)
    for sname, orpcs in old["services"].items():
        nrpcs = cur["services"].get(sname)
        if nrpcs is None:
            check("service %s still exists" % sname, False)
            continue
        for rname, sig in orpcs.items():
            if rname not in nrpcs:
                check("method %s.%s still exists" % (sname, rname), False)
            else:
                check("method %s.%s keeps its request, response and streaming shape" % (sname, rname), nrpcs[rname] == sig)

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
