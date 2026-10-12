#!/bin/bash
# post-artifact-created.sh — PostToolUse hook, matcher: Write
# Purpose: after a product artifact is written, record it in that product's
#          artifacts/<product>/_manifest.json (creating the manifest if it
#          doesn't exist yet), per skills/artifact-manifest.
# Contract: JSON on stdin (PostToolUse schema). This hook only records — it
#           never blocks (always exits 0).
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, os, re, subprocess, sys, datetime, pathlib

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
file_path = payload.get("tool_input", {}).get("file_path", "")
cwd = payload.get("cwd", ".")

# Keep the SDLC memory engine's index in sync with every write under
# artifacts/, research/, or skills/*/SKILL.md — ingest.py's own classifier
# silently no-ops on any other path, so this is safe to attempt unconditionally.
# Never allowed to block or fail this hook: best-effort, short timeout.
plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
if plugin_root and file_path:
    try:
        subprocess.run(
            [
                "bash",
                f"{plugin_root}/scripts/memory/run.sh",
                f"{plugin_root}/scripts/memory/ingest.py",
                file_path,
            ],
            cwd=cwd,
            timeout=30,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env={**os.environ, "SDLC_MEMORY_REPO_ROOT": cwd},
        )
    except Exception:
        pass

def done():
    print(json.dumps({"continue": True}))
    sys.exit(0)

norm = file_path.replace("\\", "/")
# Derive the manifest location from the written file's OWN path, never from
# cwd — the file may be written to an absolute path outside cwd (verified by
# live testing: cwd stayed the plugin root while a test file was written
# under /tmp, so a cwd-relative manifest path silently missed it).
m = re.search(r"^(.*artifacts)/([a-z0-9-]+)/([a-z0-9-]+)/(.+)$", norm)
if not m:
    done()  # not a product artifact path — nothing to record

artifacts_root, product, phase, rel = m.group(1), m.group(2), m.group(3), m.group(4)
# Type inference: a single-instance artifact sits directly in the phase dir
# (e.g. strategy/vision-statement.md) -> filename stem is the type. A
# multi-instance artifact lives in a named subdirectory (e.g.
# design/decisions/ADR-001-x.md, ideate/stories/US-014.md) -> the
# subdirectory name (singularized) is the type, so repeated instances share
# one sequence counter instead of each instance's filename becoming its own
# "type" (found by testing: two ADRs previously got sequence 001 each,
# never 001/002, because the per-instance filename was used as the type).
rel_parts = pathlib.Path(rel).parts
if len(rel_parts) > 1:
    subdir = rel_parts[0]
    artifact_type = subdir[:-1] if subdir.endswith("s") else subdir
else:
    artifact_type = pathlib.Path(rel).stem

manifest_path = pathlib.Path(artifacts_root) / product / "_manifest.json"
manifest_path.parent.mkdir(parents=True, exist_ok=True)

# The manifest must validate against schemas/sdlc-manifest.schema.json (#1252:
# the earlier minimal shape failed it with 39 errors). Everything an entry
# needs that the path can't tell us comes from the artifact's own frontmatter.
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def frontmatter(path):
    try:
        text = pathlib.Path(path).read_text(errors="replace")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fields = {}
    for line in text[3:end].splitlines():
        mm = re.match(r"^([A-Za-z_][\w-]*):\s*(.*?)\s*$", line)
        if mm:
            fields[mm.group(1)] = mm.group(2).strip().strip("'\"")
    return fields


def traces_to(raw):
    """{kind, ref} from a frontmatter traces_to value, or None. The kind is read
    from the reference's shape; a value that is only a placeholder is no trace."""
    ref = raw.strip().strip("[]").split(",")[0].strip().strip("'\"")
    if not ref or ref.lower() in {"none", "null", "tbd", "requirements"}:
        return None
    if re.match(r"^(D|ADR-?)\d+", ref, re.I):
        kind = "decision"
    elif re.match(r"^[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+$", ref):
        kind = "domain-event"  # PascalCase past-tense names, e.g. SensitivityLevelChanged
    else:
        kind = "requirement"
    return {"kind": kind, "ref": ref}


def fresh_manifest():
    return {
        "_meta": {
            "purpose": f"Registry of every artifact produced for product {product}: what exists, where, its status and what it traces to.",
            "how_to_use": "Maintained by the post-artifact-created hook on every artifact write. Agents change only status, superseded_by and traces_to; never add or remove entries by hand.",
            "last_updated": "",
            "updated_by": "post-artifact-created hook",
        },
        "product": product,
        "product_slug": product,
        "artifacts": [],
    }


manifest = None
if manifest_path.exists():
    try:
        manifest = json.loads(manifest_path.read_text())
    except Exception:
        manifest = None
if not isinstance(manifest, dict) or not isinstance(manifest.get("artifacts"), list):
    manifest = fresh_manifest()
else:
    # Upgrade a manifest written in the pre-#1252 minimal shape, keeping its entries.
    base = fresh_manifest()
    meta = manifest.get("_meta") if isinstance(manifest.get("_meta"), dict) else {}
    manifest = {
        "_meta": {k: meta.get(k) or base["_meta"][k] for k in base["_meta"]},
        "product": manifest.get("product") or product,
        "product_slug": manifest.get("product_slug") or product,
        "artifacts": manifest["artifacts"],
    }

now = datetime.date.today().isoformat()
fm = frontmatter(file_path)
version = fm.get("version", "")
owner = fm.get("owner", "")
trace = traces_to(fm.get("traces_to", ""))
rel_path = f"artifacts/{product}/{phase}/{rel}"
existing = next((a for a in manifest["artifacts"] if a.get("path") == rel_path), None)

entry = existing
if entry is None:
    seq = sum(1 for a in manifest["artifacts"] if a.get("type") == artifact_type) + 1
    entry = {
        "id": f"{product}-{artifact_type}-{seq:03d}",
        "type": artifact_type,
        "path": rel_path,
        "status": "draft",
        "phase": phase,
        "created": now,
    }
    manifest["artifacts"].append(entry)
# Fields the artifact itself is the source of truth for are refreshed on every
# write; status/superseded_by are left alone (an approval must not be reset).
entry["version"] = version if SEMVER.match(version) else entry.get("version") or "1.0.0"
entry["producing_agent"] = owner if SLUG.match(owner) else entry.get("producing_agent") or "unknown"
if trace:
    entry["traces_to"] = trace
entry["updated"] = now
order = ["id", "type", "path", "version", "status", "superseded_by", "phase",
         "producing_agent", "traces_to", "created", "updated"]
for i, a in enumerate(manifest["artifacts"]):
    a.setdefault("version", "1.0.0")
    a.setdefault("producing_agent", "unknown")
    a.setdefault("phase", phase)
    a.setdefault("created", a.get("updated") or now)
    a.setdefault("updated", a["created"])
    manifest["artifacts"][i] = {k: a[k] for k in order if k in a}

manifest["_meta"]["last_updated"] = now
manifest["_meta"]["updated_by"] = "post-artifact-created hook"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
done()
PYEOF
