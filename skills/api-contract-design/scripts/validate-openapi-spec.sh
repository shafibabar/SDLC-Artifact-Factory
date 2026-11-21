#!/bin/bash
# scripts/validate-openapi-spec.sh — skill-owned script for skills/api-contract-design.
# Purpose: mechanically check a service's OpenAPI 3.1 contract
#          (artifacts/<product>/design/<service>/openapi.yaml) against the
#          structural items of resources/checklist.md: version 3.1 and an info
#          block; every path versioned, kebab-case and free of verb prefixes;
#          global security (health endpoints excluded); unique operationIds;
#          every error response on the ErrorResponse schema, never a failure
#          shape in a success body; a defined Operation behind every 202;
#          capped cursor pagination on every collection GET; an
#          Idempotency-Key only on POST/PATCH; and a WARN for a tenant path
#          variable. Whether the design is right stays with the agent.
#          Needs PyYAML; without it the script says so and exits 0 (advisory).
# Usage:   validate-openapi-spec.sh <openapi.yaml>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-openapi-spec.sh <openapi.yaml>" >&2
  exit 2
fi
if [ ! -f "$1" ]; then
  echo "error: file not found: $1" >&2
  exit 2
fi

python3 - "$1" <<'PYEOF'
import re, sys

try:
    import yaml
except ImportError:
    print("WARN: PyYAML is not installed; the OpenAPI spec was not checked (pip install pyyaml)")
    sys.exit(0)

try:
    doc = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print("FAIL: the file is not valid YAML: %s" % str(e).splitlines()[0])
    print("\n1 check(s) failed")
    sys.exit(1)

fails = 0

def check(label, ok):
    global fails
    print(("PASS: " if ok else "FAIL: ") + label)
    if not ok:
        fails += 1

def warn(label):
    print("WARN: " + label)

if not isinstance(doc, dict):
    check("the document is an OpenAPI object", False)
    print("\n%d check(s) failed" % fails)
    sys.exit(1)

METHODS = ("get", "put", "post", "delete", "patch", "options", "head")
comps = doc.get("components") or {}
schemas = comps.get("schemas") or {}
cparams = comps.get("parameters") or {}
cresponses = comps.get("responses") or {}

def resolve(node, table, prefix):
    if isinstance(node, dict) and "$ref" in node:
        name = str(node["$ref"]).rsplit("/", 1)[-1]
        return table.get(name, {}) if str(node["$ref"]).startswith(prefix) else {}
    return node or {}

def is_error_ref(schema):
    if not isinstance(schema, dict):
        return False
    return "$ref" in schema and str(schema["$ref"]).endswith("ErrorResponse")

# --- header ---------------------------------------------------------------
ver = str(doc.get("openapi", ""))
check("openapi version is 3.1.x", ver.startswith("3.1"))
info = doc.get("info") or {}
check("info has title and version", bool(info.get("title")) and bool(info.get("version")))
paths = doc.get("paths") or {}
check("paths has at least one entry", len(paths) > 0)

# --- security ---------------------------------------------------------------
global_sec = doc.get("security")
check("a global security requirement is declared", bool(global_sec))
check("a security scheme is defined in components", bool(comps.get("securitySchemes")))

# --- ErrorResponse ------------------------------------------------------------
er = schemas.get("ErrorResponse")
check("components define an ErrorResponse schema", isinstance(er, dict))
if isinstance(er, dict):
    err = ((er.get("properties") or {}).get("error")) or {}
    req = err.get("required") or []
    check("ErrorResponse.error requires code and message", "code" in req and "message" in req)

HEALTH = ("/healthz", "/readyz", "/health", "/ready", "/livez")
seen_ops = {}
any_202 = False
verb_re = re.compile(r"^(get|list|create|update|delete|approve|cancel|fetch|set|add|remove|run|do|send|submit)([A-Z_-]|$)")
kebab_re = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

for path, item in paths.items():
    if not isinstance(item, dict):
        continue
    is_health = path in HEALTH
    segs = [s for s in path.strip("/").split("/") if s]
    if not is_health:
        check("path '%s': starts with a major version (/v1/...)" % path, bool(segs) and re.fullmatch(r"v\d+", segs[0]) is not None)
    for s in segs:
        if s.startswith("{") or re.fullmatch(r"v\d+", s):
            continue
        base = s.split(":", 1)[0]
        if base.startswith("{"):
            continue
        if base:
            check("path '%s': segment '%s' is lowercase kebab-case" % (path, base), kebab_re.match(base) is not None)
            check("path '%s': segment '%s' is a noun, not a verb endpoint" % (path, base),
                  verb_re.match(base) is None)

    last = segs[-1] if segs else ""
    is_collection = bool(segs) and not last.startswith("{") and ":" not in last and not is_health and path.rstrip("/").rsplit("/", 1)[-1] != "operations"

    for m in METHODS:
        op = item.get(m)
        if not isinstance(op, dict):
            continue
        tag = "%s %s" % (m.upper(), path)
        oid = op.get("operationId")
        check("%s: has an operationId" % tag, bool(oid))
        if oid:
            check("%s: operationId '%s' is unique" % (tag, oid), oid not in seen_ops)
            seen_ops[oid] = tag
        if "security" in op and not op["security"]:
            check("%s: security is lifted only for a health endpoint" % tag, is_health)
        resp = op.get("responses") or {}
        check("%s: documents a success response" % tag, any(str(k).startswith("2") for k in resp))
        for code, r in resp.items():
            r = resolve(r if isinstance(r, dict) else {}, cresponses, "#/components/responses")
            content = (r.get("content") or {}).get("application/json") or {}
            sch = content.get("schema") or {}
            if str(code).startswith(("4", "5")):
                check("%s %s: error uses the ErrorResponse schema" % (tag, code), is_error_ref(sch))
            if str(code).startswith("2") and isinstance(sch, dict):
                props = (sch.get("properties") or {}) if "$ref" not in sch else {}
                if "success" in props:
                    check("%s %s: no success flag in a response body (use the status code)" % (tag, code), False)
            if str(code) == "202":
                any_202 = True
                blob = str(r)
                check("%s: a 202 points to an Operation" % tag, "Operation" in blob or "operations" in blob.lower())
        # pagination on collection GETs
        if m == "get" and is_collection:
            params = [resolve(p, cparams, "#/components/parameters") for p in (op.get("parameters") or [])]
            names = {p.get("name"): p for p in params if isinstance(p, dict)}
            if "cursor" in names or "limit" in names or "page" in names or "offset" in names:
                check("%s: uses cursor and limit, not page or offset" % tag,
                      "cursor" in names and "limit" in names and "page" not in names and "offset" not in names)
                lim = names.get("limit") or {}
                if lim:
                    check("%s: limit is capped (maximum)" % tag, "maximum" in (lim.get("schema") or {}))
            else:
                warn("%s: a collection-style GET without pagination parameters; confirm it is not a growing list" % tag)
        # idempotency header placement
        if m in ("get", "put", "delete"):
            params = [resolve(p, cparams, "#/components/parameters") for p in (op.get("parameters") or [])]
            has_key = any(isinstance(p, dict) and str(p.get("name", "")).lower() == "idempotency-key" for p in params)
            check("%s: no Idempotency-Key (safe or idempotent by definition)" % tag, not has_key)

if any_202:
    op_schema = schemas.get("Operation")
    check("components define an Operation schema for the 202 responses", isinstance(op_schema, dict))
    if isinstance(op_schema, dict):
        check("Operation requires name and done", {"name", "done"} <= set(op_schema.get("required") or []))

for s in (doc.get("servers") or []):
    if isinstance(s, dict) and "tenant" in str(s.get("url", "")).lower():
        warn("a tenant path variable in servers: keep it only for a multi-tenant product")

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
