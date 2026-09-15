#!/bin/bash
# memory-prompt-recall.sh — UserPromptSubmit hook
# Purpose: the always-on, cheap half of OpenViking-style retrieval, run
#          once per turn: intent-analyze the prompt into a few short
#          queries (scripts/memory/intent.py, local-Ollama-or-fallback),
#          run QUICK-mode hybrid search (no tree walk, no rerank -- see
#          scripts/memory/retrieve.py's quick_search), and inject the
#          resulting abstracts as additionalContext. Deep THINKING-mode
#          drill-down stays agent-invoked (skills/memory-recall/SKILL.md),
#          matching how an OpenViking-integrated agent calls its search
#          tool itself rather than every turn paying for a full tree walk.
# Contract: JSON on stdin (UserPromptSubmit schema, includes "prompt").
#           Never blocks.
set -uo pipefail

INPUT="$(cat)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MEM="$PLUGIN_ROOT/scripts/memory"

python3 - "$INPUT" "$MEM" <<'PYEOF'
import json, os, sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    payload = {}
mem_dir = sys.argv[2]
cwd = payload.get("cwd") or "."
prompt = payload.get("prompt", "") or ""

def done(extra=None):
    print(json.dumps(extra or {"continue": True}))
    sys.exit(0)

if not prompt.strip():
    done()

os.environ["SDLC_MEMORY_REPO_ROOT"] = cwd
sys.path.insert(0, mem_dir)

try:
    import store
    from common import load_config
    from models import Embedder
    from retrieve import quick_search
    from intent import build_query_plan
    from datetime import datetime, timezone
except Exception:
    done()

try:
    conn = store.connect()
    cfg = load_config()
    embedder = Embedder()
    plan = build_query_plan(prompt)[:5]

    merged = {}
    for q in plan:
        level = None
        if q.get("context_type") == "skill":
            level = None  # skills are indexed like any other leaf; no level restriction needed
        results = quick_search(conn, embedder, cfg, q["query"], level, 4)
        for r in results:
            if r["uri"] not in merged or r["final_score"] > merged[r["uri"]]["final_score"]:
                merged[r["uri"]] = r

    top = sorted(merged.values(), key=lambda r: r["final_score"], reverse=True)[:8]
    if not top:
        done()

    now_iso = datetime.now(timezone.utc).isoformat()
    for r in top:
        store.touch(conn, r["uri"], now_iso)

    lines = [f"- {r['uri']}: {r['abstract']}" for r in top]
    text = (
        "SDLC memory -- possibly relevant context for this turn (abstracts only; call "
        f"python3 {mem_dir}/retrieve.py --mode thinking \"<refined query>\" --full to drill in):\n"
        + "\n".join(lines)
    )
    done({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": text}})
except Exception:
    done()
PYEOF
