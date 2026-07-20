#!/bin/bash
# post-artifact-created.sh — PostToolUse hook, matcher: Write
# Purpose: after a product artifact is written, record it in that product's
#          artifacts/<product>/_manifest.json (creating the manifest if it
#          doesn't exist yet), per skills/governance/artifact-manifest.
# Contract: JSON on stdin (PostToolUse schema). This hook only records — it
#           never blocks (always exits 0).
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, re, sys, datetime, pathlib

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
file_path = payload.get("tool_input", {}).get("file_path", "")

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
artifact_type = pathlib.Path(rel).stem

manifest_path = pathlib.Path(artifacts_root) / product / "_manifest.json"
manifest_path.parent.mkdir(parents=True, exist_ok=True)

if manifest_path.exists():
    try:
        manifest = json.loads(manifest_path.read_text())
    except Exception:
        manifest = {"_meta": {"product": product}, "artifacts": []}
else:
    manifest = {"_meta": {"product": product}, "artifacts": []}

now = datetime.date.today().isoformat()
existing = next((a for a in manifest["artifacts"] if a["path"] == f"artifacts/{product}/{phase}/{rel}"), None)

if existing:
    existing["updated"] = now
else:
    seq = sum(1 for a in manifest["artifacts"] if a["type"] == artifact_type) + 1
    manifest["artifacts"].append({
        "id": f"{product}-{artifact_type}-{seq:03d}",
        "type": artifact_type,
        "phase": phase,
        "path": f"artifacts/{product}/{phase}/{rel}",
        "status": "draft",
        "created": now,
        "updated": now,
    })

manifest["_meta"]["last_updated"] = now
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
done()
PYEOF
